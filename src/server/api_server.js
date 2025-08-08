const express = require('express');
const cors = require('cors');
const { spawn, exec } = require('child_process');
const fs = require('fs').promises;
const path = require('path');
const multer = require('multer');

const app = express();
const PORT = 3000;

// Configuración
const PROJECT_ROOT = path.join(__dirname, '..', '..');
const DARKNET_DIR = path.join(PROJECT_ROOT, 'darknet');
const SIMPLE_STREAM = path.join(DARKNET_DIR, 'build', 'src-examples', 'simple_stream_progressive');
const LOG_DIR = path.join(PROJECT_ROOT, 'logs');
const CONFIG_FILE = path.join(PROJECT_ROOT, 'config', 'detection_config.json');
const CAMERAS_CONFIG_FILE = path.join(PROJECT_ROOT, 'config', 'cameras_config.json');
const MODELS_CONFIG_FILE = path.join(PROJECT_ROOT, 'config', 'models_config.json');

// Estado de las cámaras
let cameraProcesses = new Map();
let detectionConfigs = new Map();
let modelsConfig = { models: [], customModels: [] };

// Configuración de multer para carga de archivos
const storage = multer.diskStorage({
    destination: async function (req, file, cb) {
        const uploadDir = path.join(DARKNET_DIR, 'custom_models');
        // Crear directorio si no existe
        await fs.mkdir(uploadDir, { recursive: true });
        cb(null, uploadDir);
    },
    filename: function (req, file, cb) {
        // Mantener el nombre original del archivo
        cb(null, file.originalname);
    }
});

const upload = multer({ 
    storage: storage,
    limits: {
        fileSize: 500 * 1024 * 1024 // Límite de 500MB para archivos .weights
    },
    fileFilter: function (req, file, cb) {
        // Aceptar solo archivos .cfg, .weights y .names
        const ext = path.extname(file.originalname).toLowerCase();
        if (ext === '.cfg' || ext === '.weights' || ext === '.names') {
            cb(null, true);
        } else {
            cb(new Error('Solo se permiten archivos .cfg, .weights y .names'));
        }
    }
});

// Middleware
app.use(cors());
app.use(express.json());
// Servir archivos estáticos desde múltiples directorios
app.use('/src/frontend', express.static(path.join(PROJECT_ROOT, 'src', 'frontend')));
app.use('/config', express.static(path.join(PROJECT_ROOT, 'config')));
app.use(express.static(PROJECT_ROOT));

// Redirección de la raíz al panel
app.get('/', (req, res) => {
    res.redirect('/src/frontend/panel.html');
});

// Redirecciones para compatibilidad con URLs antiguas
app.get('/stream_viewer.html', (req, res) => {
    const queryString = req.originalUrl.split('?')[1] || '';
    res.redirect('/src/frontend/stream_viewer.html' + (queryString ? '?' + queryString : ''));
});
app.get('/panel.html', (req, res) => {
    res.redirect('/src/frontend/panel.html');
});

// Configuración de cámaras (ahora es un let para poder modificarla)
let cameras = [
    {
        id: 1,
        name: 'Cámara Principal',
        ip: '192.168.1.124',
        port: 8080,
        rtsp_port: 554,
        username: 'admin',
        password: 'Radimer01',
        path: '/Streaming/Channels/1'
    },
    {
        id: 2,
        name: 'Exterior',
        ip: '192.168.1.126',
        port: 8081,
        rtsp_port: 554,
        username: 'admin',
        password: 'Radimer01',
        path: '/Streaming/Channels/1'
    },
    {
        id: 3,
        name: 'ofi',
        ip: '192.168.1.123',
        port: 8082,
        rtsp_port: 554,
        username: 'admin',
        password: 'Radimer01',
        path: '/Streaming/Channels/1'
    }
];

// ID para nuevas cámaras
let nextCameraId = 4;

// Actualizar configuración avanzada de cámara
app.put('/api/cameras/:id/settings', async (req, res) => {
    try {
        const cameraId = parseInt(req.params.id);
        const settings = req.body;
        
        // Buscar la cámara
        const cameraIndex = cameras.findIndex(c => c.id === cameraId);
        if (cameraIndex === -1) {
            return res.status(404).json({ error: 'Cámara no encontrada' });
        }
        
        // Actualizar configuración
        cameras[cameraIndex].settings = {
            ...cameras[cameraIndex].settings,
            ...settings
        };
        
        await saveCamerasConfig();
        
        res.json({ status: 'ok', settings: cameras[cameraIndex].settings });
    } catch (error) {
        console.error('Error actualizando configuración:', error);
        res.status(500).json({ error: error.message });
    }
});

// Reiniciar cámara con nueva configuración
app.post('/api/cameras/:id/restart', async (req, res) => {
    try {
        const cameraId = parseInt(req.params.id);
        
        // Detener si está en ejecución
        if (cameraProcesses.has(cameraId)) {
            await stopCamera(cameraId);
            await new Promise(resolve => setTimeout(resolve, 1000)); // Esperar un segundo
        }
        
        // Iniciar con nueva configuración
        await startCamera(cameraId);
        
        res.json({ status: 'ok' });
    } catch (error) {
        console.error('Error reiniciando cámara:', error);
        res.status(500).json({ error: error.message });
    }
});

// Construir URL RTSP
function buildRtspUrl(camera) {
    return `rtsp://${camera.username}:${camera.password}@${camera.ip}:${camera.rtsp_port}${camera.path}`;
}

// Iniciar una cámara
async function startCamera(cameraId) {
    const camera = cameras.find(c => c.id === cameraId);
    if (!camera) {
        throw new Error('Cámara no encontrada');
    }
    
    // Si ya está ejecutándose, no hacer nada
    if (cameraProcesses.has(cameraId)) {
        return { status: 'already_running', camera };
    }
    
    const rtspUrl = buildRtspUrl(camera);
    const detectionConfig = detectionConfigs.get(cameraId) || {};
    
    // Crear archivo temporal con la configuración de detección
    const configFile = path.join(LOG_DIR, `camera_${cameraId}_config.json`);
    await fs.writeFile(configFile, JSON.stringify(detectionConfig));
    
    // Crear archivo con configuración avanzada
    const settingsFile = path.join(LOG_DIR, `camera_${cameraId}_settings.json`);
    const settings = camera.settings || {
        quality: 'medium',
        resolution: '720p',
        jpegQuality: 75,
        detectionEnabled: true,
        showBoundingBoxes: true,
        showLabels: true,
        showConfidence: true,
        minConfidence: 0.5
    };
    await fs.writeFile(settingsFile, JSON.stringify(settings));
    
    // Obtener modelo seleccionado o usar el por defecto
    let selectedModel = null;
    if (camera.modelId) {
        selectedModel = [...modelsConfig.models, ...modelsConfig.customModels].find(m => m.id === camera.modelId);
    }
    if (!selectedModel) {
        selectedModel = modelsConfig.models[0]; // Usar el modelo por defecto
    }
    
    // Construir argumentos incluyendo el modelo
    const args = [
        camera.port.toString(), 
        rtspUrl, 
        camera.name.replace(/\s+/g, '_'), 
        configFile,
        selectedModel.config,
        selectedModel.weights,
        selectedModel.names || 'cfg/coco.names'
    ];
    
    try {
        // Verificar que el ejecutable existe y es ejecutable
        try {
            await fs.access(SIMPLE_STREAM, fs.constants.X_OK);
        } catch (err) {
            console.error(`ERROR: No se puede ejecutar ${SIMPLE_STREAM}`);
            console.error(`  Verifica que el archivo existe y tiene permisos de ejecución`);
            return { status: 'error', error: `Ejecutable no encontrado o sin permisos: ${SIMPLE_STREAM}`, camera };
        }
        
        console.log(`Iniciando cámara ${cameraId} con comando:`);
        console.log(`  ${SIMPLE_STREAM} ${args.join(' ')}`);
        
        const proc = spawn(SIMPLE_STREAM, args, {
            cwd: DARKNET_DIR,
            env: { ...process.env, LD_LIBRARY_PATH: '/usr/local/cuda/lib64' }
        });
        
        // Guardar logs
        const logFile = path.join(LOG_DIR, `camera_${cameraId}.log`);
        const logStream = await fs.open(logFile, 'w');
        
        proc.stdout.on('data', (data) => {
            logStream.write(data);
            console.log(`[Camera ${cameraId}]: ${data.toString().trim()}`);
        });
        
        proc.stderr.on('data', (data) => {
            logStream.write(data);
            console.error(`[Camera ${cameraId} ERROR]: ${data.toString().trim()}`);
        });
        
        proc.on('error', (error) => {
            console.error(`Error iniciando cámara ${cameraId}:`, error);
            logStream.write(`Error: ${error.message}\n`);
        });
        
        proc.on('exit', (code) => {
            console.log(`Cámara ${cameraId} terminó con código: ${code}`);
            logStream.close();
            cameraProcesses.delete(cameraId);
        });
        
        cameraProcesses.set(cameraId, proc);
        
        // Esperar un momento para ver si inicia correctamente
        await new Promise(resolve => setTimeout(resolve, 2000));
        
        if (proc.exitCode === null) {
            return { status: 'started', camera };
        } else {
            console.error(`Cámara ${cameraId} falló al iniciar. Código de salida: ${proc.exitCode}`);
            return { status: 'failed', camera, exitCode: proc.exitCode };
        }
    } catch (error) {
        console.error(`Error crítico iniciando cámara ${cameraId}:`, error);
        return { status: 'error', error: error.message, camera };
    }
}

// Detener una cámara
async function stopCamera(cameraId) {
    const proc = cameraProcesses.get(cameraId);
    if (proc) {
        proc.kill('SIGTERM');
        await new Promise(resolve => setTimeout(resolve, 1000));
        if (!proc.killed) {
            proc.kill('SIGKILL');
        }
        cameraProcesses.delete(cameraId);
        return { status: 'stopped' };
    }
    return { status: 'not_running' };
}

// API Endpoints

// Obtener estado de todas las cámaras
app.get('/api/cameras', (req, res) => {
    const camerasWithStatus = cameras.map(cam => ({
        ...cam,
        running: cameraProcesses.has(cam.id),
        streamUrl: `http://localhost:${cam.port}/`
    }));
    res.json(camerasWithStatus);
});

// Iniciar todas las cámaras
app.post('/api/cameras/start-all', async (req, res) => {
    const results = [];
    for (const camera of cameras) {
        const result = await startCamera(camera.id);
        results.push(result);
        // Pequeña pausa entre cámaras
        await new Promise(resolve => setTimeout(resolve, 1000));
    }
    res.json({ status: 'ok', results });
});

// Detener todas las cámaras
app.post('/api/cameras/stop-all', async (req, res) => {
    const results = [];
    for (const camera of cameras) {
        const result = await stopCamera(camera.id);
        results.push({ ...result, cameraId: camera.id });
    }
    res.json({ status: 'ok', results });
});

// Iniciar una cámara específica
app.post('/api/cameras/:id/start', async (req, res) => {
    const cameraId = parseInt(req.params.id);
    const result = await startCamera(cameraId);
    res.json(result);
});

// Detener una cámara específica
app.post('/api/cameras/:id/stop', async (req, res) => {
    const cameraId = parseInt(req.params.id);
    const result = await stopCamera(cameraId);
    res.json(result);
});

// Verificar conectividad de una cámara
app.get('/api/cameras/:id/check', async (req, res) => {
    const cameraId = parseInt(req.params.id);
    const camera = cameras.find(c => c.id === cameraId);
    
    if (!camera) {
        return res.status(404).json({ error: 'Cámara no encontrada' });
    }
    
    // Verificar conectividad con ping
    const { exec } = require('child_process');
    const pingCommand = process.platform === 'win32' 
        ? `ping -n 1 -w 1000 ${camera.ip}` 
        : `ping -c 1 -W 1 ${camera.ip}`;
    
    exec(pingCommand, (error, stdout, stderr) => {
        const isReachable = !error;
        res.json({
            cameraId,
            ip: camera.ip,
            reachable: isReachable,
            message: isReachable ? 'Cámara accesible' : 'Cámara no accesible'
        });
    });
});

// Obtener configuración de detección para una cámara
app.get('/api/cameras/:id/detection-config', (req, res) => {
    const cameraId = parseInt(req.params.id);
    const config = detectionConfigs.get(cameraId) || {};
    res.json(config);
});

// Actualizar configuración de detección para una cámara
app.post('/api/cameras/:id/detection-config', async (req, res) => {
    try {
        const cameraId = parseInt(req.params.id);
        const config = req.body;
        
        console.log(`Actualizando configuración para cámara ${cameraId}:`, config);
        
        detectionConfigs.set(cameraId, config);
        
        // También actualizar el modelId en el objeto camera si viene en la configuración
        if (config.modelId) {
            const camera = cameras.find(c => c.id === cameraId);
            if (camera) {
                camera.modelId = config.modelId;
                // Guardar cambios en cameras
                await saveCamerasConfig();
            }
        }
        
        // Guardar configuración en archivo
        await saveDetectionConfigs();
        
        let wasRestarted = false;
        
        // Si la cámara está en ejecución, reiniciarla para aplicar cambios
        if (cameraProcesses.has(cameraId)) {
            console.log(`Reiniciando cámara ${cameraId} para aplicar nueva configuración...`);
            await stopCamera(cameraId);
            await new Promise(resolve => setTimeout(resolve, 1000)); // Esperar un momento
            await startCamera(cameraId);
            wasRestarted = true;
        }
        
        res.json({ status: 'ok', cameraId, config, restarted: wasRestarted });
    } catch (error) {
        console.error('Error actualizando configuración:', error);
        res.status(500).json({ status: 'error', error: error.message });
    }
});

// Función para encontrar un puerto disponible
function findAvailablePort() {
    const usedPorts = new Set(cameras.map(c => c.port));
    let port = 8080;
    while (usedPorts.has(port)) {
        port++;
    }
    return port;
}

// Añadir nueva cámara
app.post('/api/cameras', async (req, res) => {
    try {
        const newCamera = req.body;
        
        // Validar datos requeridos
        if (!newCamera.name || !newCamera.ip || !newCamera.password) {
            return res.status(400).json({ error: 'Faltan datos requeridos' });
        }
        
        // Asignar ID y valores por defecto
        newCamera.id = nextCameraId++;
        newCamera.port = findAvailablePort(); // Asignar puerto automáticamente
        newCamera.rtsp_port = newCamera.rtsp_port || 554;
        
        // Añadir a la lista
        cameras.push(newCamera);
        
        // Guardar configuración
        await saveCamerasConfig();
        
        res.json({ status: 'ok', camera: newCamera });
    } catch (error) {
        console.error('Error añadiendo cámara:', error);
        res.status(500).json({ error: error.message });
    }
});

// Actualizar cámara
app.put('/api/cameras/:id', async (req, res) => {
    try {
        const cameraId = parseInt(req.params.id);
        const updates = req.body;
        
        // Buscar la cámara
        const cameraIndex = cameras.findIndex(c => c.id === cameraId);
        if (cameraIndex === -1) {
            return res.status(404).json({ error: 'Cámara no encontrada' });
        }
        
        // Si la cámara está en ejecución, detenerla
        const wasRunning = cameraProcesses.has(cameraId);
        if (wasRunning) {
            await stopCamera(cameraId);
        }
        
        // Actualizar datos (manteniendo el puerto actual)
        const currentCamera = cameras[cameraIndex];
        cameras[cameraIndex] = {
            ...currentCamera,
            name: updates.name || currentCamera.name,
            ip: updates.ip || currentCamera.ip,
            username: updates.username || currentCamera.username,
            password: updates.password || currentCamera.password, // Solo actualizar si se proporciona
            path: updates.path || currentCamera.path,
            modelId: updates.modelId !== undefined ? updates.modelId : currentCamera.modelId,
            port: currentCamera.port, // Mantener el puerto asignado
            rtsp_port: currentCamera.rtsp_port
        };
        
        // Si se actualizó el modelId, también actualizarlo en detectionConfigs
        if (updates.modelId !== undefined) {
            const detectionConfig = detectionConfigs.get(cameraId) || {};
            detectionConfig.modelId = updates.modelId;
            detectionConfigs.set(cameraId, detectionConfig);
            await saveDetectionConfigs();
        }
        
        // Guardar configuración
        await saveCamerasConfig();
        
        // Si estaba en ejecución, reiniciarla con la nueva configuración
        if (wasRunning) {
            await new Promise(resolve => setTimeout(resolve, 1000));
            await startCamera(cameraId);
        }
        
        res.json({ status: 'ok', camera: cameras[cameraIndex] });
    } catch (error) {
        console.error('Error actualizando cámara:', error);
        res.status(500).json({ error: error.message });
    }
});

// Borrar cámara
app.delete('/api/cameras/:id', async (req, res) => {
    try {
        const cameraId = parseInt(req.params.id);
        
        // Detener la cámara si está en ejecución
        if (cameraProcesses.has(cameraId)) {
            await stopCamera(cameraId);
        }
        
        // Eliminar de la lista
        const index = cameras.findIndex(c => c.id === cameraId);
        if (index === -1) {
            return res.status(404).json({ error: 'Cámara no encontrada' });
        }
        
        cameras.splice(index, 1);
        
        // Eliminar configuración de detección
        detectionConfigs.delete(cameraId);
        
        // Guardar configuración
        await saveCamerasConfig();
        await saveDetectionConfigs();
        
        res.json({ status: 'ok' });
    } catch (error) {
        console.error('Error borrando cámara:', error);
        res.status(500).json({ error: error.message });
    }
});

// Verificar estado del sistema
app.get('/api/status', (req, res) => {
    res.json({
        totalCameras: cameras.length,
        runningCameras: cameraProcesses.size,
        cameras: cameras.map(c => ({
            id: c.id,
            name: c.name,
            running: cameraProcesses.has(c.id)
        }))
    });
});

// Obtener modelos disponibles
app.get('/api/models', (req, res) => {
    res.json({
        models: [...modelsConfig.models, ...modelsConfig.customModels]
    });
});

// Obtener nombres (labels) de un modelo específico
app.get('/api/models/:id/names', async (req, res) => {
    try {
        const modelId = req.params.id;
        
        // Buscar el modelo
        const model = [...modelsConfig.models, ...modelsConfig.customModels].find(m => m.id === modelId);
        if (!model) {
            return res.status(404).json({ error: 'Modelo no encontrado' });
        }
        
        // Leer archivo de nombres
        const namesPath = path.join(DARKNET_DIR, model.names);
        const namesContent = await fs.readFile(namesPath, 'utf8');
        const names = namesContent.split('\n').filter(line => line.trim() !== '');
        
        res.json({
            modelId,
            names,
            count: names.length
        });
    } catch (error) {
        console.error('Error leyendo nombres del modelo:', error);
        res.status(500).json({ error: error.message });
    }
});

// Añadir modelo personalizado
app.post('/api/models', async (req, res) => {
    try {
        const newModel = req.body;
        
        // Validar datos requeridos
        if (!newModel.name || !newModel.config || !newModel.weights) {
            return res.status(400).json({ error: 'Faltan datos requeridos' });
        }
        
        // Generar ID único
        newModel.id = `custom_${Date.now()}`;
        newModel.description = newModel.description || 'Modelo personalizado';
        newModel.type = newModel.type || 'custom';
        
        // Añadir a modelos personalizados
        modelsConfig.customModels.push(newModel);
        
        // Guardar configuración
        await saveModelsConfig();
        
        res.json({ status: 'ok', model: newModel });
    } catch (error) {
        console.error('Error añadiendo modelo:', error);
        res.status(500).json({ error: error.message });
    }
});

// Eliminar modelo personalizado
app.delete('/api/models/:id', async (req, res) => {
    try {
        const modelId = req.params.id;
        
        // Solo se pueden eliminar modelos personalizados
        if (!modelId.startsWith('custom_')) {
            return res.status(400).json({ error: 'Solo se pueden eliminar modelos personalizados' });
        }
        
        // Eliminar de la lista
        const index = modelsConfig.customModels.findIndex(m => m.id === modelId);
        if (index === -1) {
            return res.status(404).json({ error: 'Modelo no encontrado' });
        }
        
        // Obtener información del modelo para eliminar archivos
        const model = modelsConfig.customModels[index];
        
        // Eliminar archivos si existen
        try {
            if (model.config && model.config.startsWith('custom_models/')) {
                await fs.unlink(path.join(DARKNET_DIR, model.config));
            }
            if (model.weights && model.weights.startsWith('custom_models/')) {
                await fs.unlink(path.join(DARKNET_DIR, model.weights));
            }
            if (model.names && model.names.startsWith('custom_models/')) {
                await fs.unlink(path.join(DARKNET_DIR, model.names));
            }
        } catch (err) {
            console.log('Error eliminando archivos:', err);
        }
        
        modelsConfig.customModels.splice(index, 1);
        
        // Actualizar cámaras que usen este modelo
        for (const camera of cameras) {
            if (camera.modelId === modelId) {
                delete camera.modelId;
            }
        }
        
        // Guardar configuraciones
        await saveModelsConfig();
        await saveCamerasConfig();
        
        res.json({ status: 'ok' });
    } catch (error) {
        console.error('Error eliminando modelo:', error);
        res.status(500).json({ error: error.message });
    }
});

// Subir archivos de modelo
app.post('/api/models/upload', upload.fields([
    { name: 'configFile', maxCount: 1 },
    { name: 'weightsFile', maxCount: 1 },
    { name: 'namesFile', maxCount: 1 }
]), async (req, res) => {
    try {
        const files = req.files;
        const modelData = JSON.parse(req.body.modelData);
        
        if (!files.configFile || !files.weightsFile) {
            return res.status(400).json({ error: 'Se requieren archivos .cfg y .weights' });
        }
        
        // Calcular número de clases automáticamente
        let classCount = 80; // Por defecto si usa coco.names
        
        if (files.namesFile) {
            // Leer el archivo .names para contar las clases
            const namesPath = path.join(DARKNET_DIR, `custom_models/${files.namesFile[0].filename}`);
            try {
                const namesContent = await fs.readFile(namesPath, 'utf8');
                const lines = namesContent.split('\n').filter(line => line.trim() !== '');
                classCount = lines.length;
            } catch (err) {
                console.log('Error contando clases, usando valor por defecto:', err);
            }
        }
        
        // Crear el modelo con las rutas de los archivos subidos
        const newModel = {
            id: `custom_${Date.now()}`,
            name: modelData.name,
            description: modelData.description || 'Modelo personalizado',
            config: `custom_models/${files.configFile[0].filename}`,
            weights: `custom_models/${files.weightsFile[0].filename}`,
            names: files.namesFile ? `custom_models/${files.namesFile[0].filename}` : 'cfg/coco.names',
            type: 'custom',
            classes: classCount
        };
        
        // Añadir a modelos personalizados
        modelsConfig.customModels.push(newModel);
        
        // Guardar configuración
        await saveModelsConfig();
        
        res.json({ status: 'ok', model: newModel });
    } catch (error) {
        console.error('Error subiendo modelo:', error);
        res.status(500).json({ error: error.message });
    }
});

// Actualizar modelo existente
app.put('/api/models/:id', upload.fields([
    { name: 'configFile', maxCount: 1 },
    { name: 'weightsFile', maxCount: 1 },
    { name: 'namesFile', maxCount: 1 }
]), async (req, res) => {
    try {
        const modelId = req.params.id;
        const files = req.files;
        const modelData = JSON.parse(req.body.modelData);
        
        // Solo se pueden editar modelos personalizados
        if (!modelId.startsWith('custom_')) {
            return res.status(400).json({ error: 'Solo se pueden editar modelos personalizados' });
        }
        
        // Buscar el modelo
        const modelIndex = modelsConfig.customModels.findIndex(m => m.id === modelId);
        if (modelIndex === -1) {
            return res.status(404).json({ error: 'Modelo no encontrado' });
        }
        
        const currentModel = modelsConfig.customModels[modelIndex];
        
        // Preparar el modelo actualizado
        const updatedModel = {
            ...currentModel,
            name: modelData.name || currentModel.name,
            description: modelData.description || currentModel.description
        };
        
        // Si se suben nuevos archivos, eliminar los antiguos y actualizar rutas
        if (files.configFile) {
            // Eliminar archivo antiguo si existe
            try {
                await fs.unlink(path.join(DARKNET_DIR, currentModel.config));
            } catch (err) {}
            updatedModel.config = `custom_models/${files.configFile[0].filename}`;
        }
        
        if (files.weightsFile) {
            // Eliminar archivo antiguo si existe
            try {
                await fs.unlink(path.join(DARKNET_DIR, currentModel.weights));
            } catch (err) {}
            updatedModel.weights = `custom_models/${files.weightsFile[0].filename}`;
        }
        
        if (files.namesFile) {
            // Eliminar archivo antiguo si existe y no es el de COCO
            if (currentModel.names.startsWith('custom_models/')) {
                try {
                    await fs.unlink(path.join(DARKNET_DIR, currentModel.names));
                } catch (err) {}
            }
            updatedModel.names = `custom_models/${files.namesFile[0].filename}`;
            
            // Recalcular número de clases
            const namesPath = path.join(DARKNET_DIR, updatedModel.names);
            try {
                const namesContent = await fs.readFile(namesPath, 'utf8');
                const lines = namesContent.split('\n').filter(line => line.trim() !== '');
                updatedModel.classes = lines.length;
            } catch (err) {
                console.log('Error contando clases:', err);
            }
        }
        
        // Actualizar el modelo
        modelsConfig.customModels[modelIndex] = updatedModel;
        
        // Guardar configuración
        await saveModelsConfig();
        
        res.json({ status: 'ok', model: updatedModel });
    } catch (error) {
        console.error('Error actualizando modelo:', error);
        res.status(500).json({ error: error.message });
    }
});

// Cargar configuración de detecciones desde archivo
async function loadDetectionConfigs() {
    try {
        const data = await fs.readFile(CONFIG_FILE, 'utf8');
        const configs = JSON.parse(data);
        for (const [cameraId, config] of Object.entries(configs)) {
            detectionConfigs.set(parseInt(cameraId), config);
        }
    } catch (error) {
        // Si no existe el archivo, usar configuración vacía
        console.log('No se encontró archivo de configuración de detecciones');
    }
}

// Guardar configuración de detecciones en archivo
async function saveDetectionConfigs() {
    const configs = {};
    for (const [cameraId, config] of detectionConfigs) {
        configs[cameraId] = config;
    }
    await fs.writeFile(CONFIG_FILE, JSON.stringify(configs, null, 2));
}

// Cargar configuración de cámaras desde archivo
async function loadCamerasConfig() {
    try {
        const data = await fs.readFile(CAMERAS_CONFIG_FILE, 'utf8');
        const config = JSON.parse(data);
        cameras = config.cameras || cameras;
        nextCameraId = config.nextCameraId || nextCameraId;
        console.log(`Configuración de cámaras cargada: ${cameras.length} cámaras`);
    } catch (error) {
        // Si no existe el archivo, usar configuración por defecto
        console.log('Usando configuración de cámaras por defecto');
    }
}

// Guardar configuración de cámaras en archivo
async function saveCamerasConfig() {
    const config = {
        cameras,
        nextCameraId
    };
    await fs.writeFile(CAMERAS_CONFIG_FILE, JSON.stringify(config, null, 2));
}

// Cargar configuración de modelos desde archivo
async function loadModelsConfig() {
    try {
        const data = await fs.readFile(MODELS_CONFIG_FILE, 'utf8');
        modelsConfig = JSON.parse(data);
        console.log(`Configuración de modelos cargada: ${modelsConfig.models.length} modelos predefinidos, ${modelsConfig.customModels.length} modelos personalizados`);
    } catch (error) {
        // Si no existe el archivo, usar configuración por defecto
        console.log('Usando configuración de modelos por defecto');
        modelsConfig = {
            models: [
                {
                    id: "yolov4-tiny",
                    name: "YOLOv4-tiny (Por defecto)",
                    description: "Modelo ligero, rápido para detección general",
                    config: "cfg/yolov4-tiny.cfg",
                    weights: "yolov4-tiny.weights",
                    names: "cfg/coco.names",
                    type: "coco",
                    classes: 80
                }
            ],
            customModels: []
        };
    }
}

// Guardar configuración de modelos en archivo
async function saveModelsConfig() {
    await fs.writeFile(MODELS_CONFIG_FILE, JSON.stringify(modelsConfig, null, 2));
}

// Iniciar servidor
async function startServer() {
    // Crear directorio de logs si no existe
    await fs.mkdir(LOG_DIR, { recursive: true });
    
    // Cargar configuraciones
    await loadCamerasConfig();
    await loadDetectionConfigs();
    await loadModelsConfig();
    
    // Escuchar en todas las interfaces (0.0.0.0) para acceso desde red local
    app.listen(PORT, '0.0.0.0', () => {
        const os = require('os');
        const networkInterfaces = os.networkInterfaces();
        const addresses = [];
        
        // Obtener todas las IPs de la máquina
        for (let interfaceName in networkInterfaces) {
            const interface = networkInterfaces[interfaceName];
            for (let i = 0; i < interface.length; i++) {
                const address = interface[i];
                if (address.family === 'IPv4' && !address.internal) {
                    addresses.push(address.address);
                }
            }
        }
        
        console.log('\n===========================================');
        console.log('   Sistema de Detección YOLO - INICIADO');
        console.log('===========================================');
        console.log(`\n✓ Servidor API ejecutándose en puerto ${PORT}`);
        console.log('\nAcceso local:');
        console.log(`  http://localhost:${PORT}`);
        console.log(`  http://127.0.0.1:${PORT}`);
        
        if (addresses.length > 0) {
            console.log('\nAcceso desde red local:');
            addresses.forEach(ip => {
                console.log(`  http://${ip}:${PORT}`);
            });
        }
        
        console.log('\n===========================================\n');
    });
}

// Limpiar al salir
process.on('SIGINT', async () => {
    console.log('\nDeteniendo servidor...');
    
    // Detener todas las cámaras
    for (const [id, proc] of cameraProcesses) {
        proc.kill('SIGTERM');
    }
    
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    for (const [id, proc] of cameraProcesses) {
        if (!proc.killed) {
            proc.kill('SIGKILL');
        }
    }
    
    process.exit(0);
});

// Iniciar
startServer().catch(console.error);