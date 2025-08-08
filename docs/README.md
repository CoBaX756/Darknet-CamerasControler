# Sistema de Detección YOLO Multi-Cámara

Sistema dinámico de gestión de múltiples cámaras RTSP con detección de objetos en tiempo real usando YOLO y streaming web MJPEG.

## Características Principales

- **Gestión dinámica** de múltiples cámaras RTSP (hasta 20 cámaras)
- **Detección en tiempo real** con YOLOv4-tiny y modelos personalizados
- **Panel web interactivo** para configuración y monitoreo
- **API REST completa** para integración externa
- **Streaming MJPEG** optimizado para web
- **Aceleración GPU** con CUDA para máximo rendimiento
- **Configuración sin reinicio** - agregar/quitar cámaras dinámicamente

## Requisitos del Sistema

- **Sistema Operativo:** Ubuntu 20.04+ o distribución compatible
- **Node.js:** v14+ y NPM
- **GPU:** NVIDIA con CUDA (opcional pero recomendado)
- **Dependencias:** OpenCV 4.x, Darknet compilado
- **Red:** Acceso a cámaras RTSP en la red local
- **Hardware:** Mínimo 4GB RAM, 8GB recomendado

## Arquitectura del Sistema

### Componentes Principales

| Componente | Archivo | Descripción |
|------------|---------|-------------|
| **API Server** | `api_server.js` | Servidor Node.js con Express para API REST |
| **Panel Web** | `panel.html` | Interfaz de gestión de cámaras y configuración |
| **Stream Viewer** | `stream_viewer.html` | Visualizador de múltiples streams simultáneos |
| **Darknet Engine** | `darknet/` | Framework YOLO para detección de objetos |
| **Scripts de Gestión** | `scripts/` | Automatización completa del sistema |

### Puertos del Sistema

| Puerto | Servicio | Descripción |
|--------|----------|-------------|
| **3000** | API REST + Panel | Control principal y configuración |
| **8080-8099** | Streams de cámaras | Asignación automática por cámara |

## Instalación

### 1. Preparar el entorno Node.js

```bash
cd /home/xabi/Documentos/Deteccion
npm install
```

### 2. Compilar Darknet

```bash
# Compilar con optimizaciones para streaming progresivo
./compile_progressive.sh
```

### 3. Verificar requisitos del sistema

```bash
# Verificar CUDA (opcional)
nvidia-smi

# Verificar OpenCV
pkg-config --modversion opencv4

# Verificar Node.js
node --version
npm --version
```

## Uso del Sistema

### Inicio Rápido

```bash
# Opción 1: Inicio automático completo
./start_system.sh

# Opción 2: Gestor avanzado con verificaciones
cd scripts/
./yolo_manager.sh start

# Opción 3: Solo servidor API (desarrollo)
node api_server.js
```

### Panel de Control Web

1. **Acceder al panel:** `http://localhost:3000/panel.html`
2. **Agregar cámaras:** Usar el formulario en el panel
3. **Configurar detección:** Seleccionar modelos y ajustar parámetros
4. **Monitorear streams:** Ver múltiples cámaras simultáneamente

### Gestión Avanzada con Scripts

```bash
# Menú interactivo con todas las opciones
./scripts/yolo_manager.sh menu

# Ver estado completo del sistema  
./scripts/yolo_manager.sh status

# Monitorear logs en tiempo real
./scripts/yolo_manager.sh logs

# Parar todo el sistema limpiamente
./scripts/yolo_manager.sh stop

# Reiniciar sistema (útil tras cambios)
./scripts/yolo_manager.sh restart
```

## API REST

### Endpoints Principales

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| `GET` | `/api/cameras` | Listar todas las cámaras |
| `POST` | `/api/cameras` | Agregar nueva cámara |
| `PUT` | `/api/cameras/:id` | Actualizar configuración de cámara |
| `DELETE` | `/api/cameras/:id` | Eliminar cámara |
| `GET` | `/api/models` | Listar modelos YOLO disponibles |
| `POST` | `/api/models/upload` | Subir modelo personalizado |

### Ejemplo de uso con curl

```bash
# Agregar nueva cámara
curl -X POST http://localhost:3000/api/cameras \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Cámara Principal",
    "ip": "192.168.1.100", 
    "username": "admin",
    "password": "password123",
    "path": "/Streaming/Channels/1"
  }'

# Ver estado de cámaras
curl http://localhost:3000/api/cameras
```

## Configuración

### Archivos de Configuración

| Archivo | Ubicación | Propósito |
|---------|-----------|-----------|
| `cameras_config.json` | Raíz | Configuración de cámaras RTSP |
| `models_config.json` | Raíz | Modelos YOLO disponibles |
| `detection_config.json` | Raíz | Parámetros de detección |
| `package.json` | Raíz | Dependencias Node.js |

### Configuración Típica de Cámara

```json
{
  "id": 1,
  "name": "Oficina Principal",
  "ip": "192.168.1.124",
  "port": 8080,
  "rtsp_port": 554,
  "username": "admin", 
  "password": "tu_password",
  "path": "/Streaming/Channels/1",
  "modelId": "yolov4-tiny",
  "settings": {
    "detectionEnabled": true,
    "showBoundingBoxes": true,
    "minConfidence": 0.5,
    "resolution": "1080p"
  }
}
```

## Modelos YOLO

### Modelos Incluidos

- **YOLOv4-tiny**: Modelo base, rápido y eficiente
- **Modelos personalizados**: En `darknet/custom_models/`

### Agregar Modelo Personalizado

1. **Via Panel Web:**
   - Subir archivos `.weights`, `.cfg`, `.names`
   - Configurar automáticamente

2. **Via CLI:**
   ```bash
   cp modelo.weights darknet/custom_models/
   cp modelo.cfg darknet/custom_models/
   cp modelo.names darknet/custom_models/
   ```

## Solución de Problemas

### Problemas Comunes

#### 1. El sistema no inicia

```bash
# Verificar requisitos completos
./scripts/yolo_manager.sh menu
# Seleccionar opción: "Verificar requisitos del sistema"

# Ver logs detallados
tail -f yolo_server.log
```

#### 2. Cámara no conecta

```bash
# Probar conexión RTSP directamente
ffplay "rtsp://usuario:password@ip:554/path"

# Verificar conectividad de red
ping ip_camara
```

#### 3. Puerto ya en uso

```bash
# Limpiar todos los puertos automáticamente
./scripts/yolo_manager.sh stop
./scripts/yolo_manager.sh start
```

#### 4. Problemas de rendimiento

- **GPU:** Verificar que CUDA esté disponible
- **RAM:** Reducir número de cámaras simultáneas
- **Red:** Verificar ancho de banda disponible
- **Modelo:** Usar YOLOv4-tiny para mayor velocidad

### Logs y Depuración

```bash
# Logs del sistema principal
tail -f yolo_server.log

# Logs específicos de cámara
tail -f logs/camera_1.log

# Logs del servidor web
tail -f logs/server.log

# Ver todos los procesos del sistema
./scripts/yolo_manager.sh status
```

## Estructura de Archivos

```
/home/xabi/Documentos/Deteccion/
├── api_server.js                    # Servidor principal Node.js
├── package.json                     # Dependencias NPM
├── cameras_config.json              # Configuración de cámaras
├── models_config.json               # Modelos disponibles
├── detection_config.json            # Configuración de detección
├── panel.html                       # Panel de control web
├── stream_viewer.html               # Visualizador de streams
├── simple_stream_progressive.cpp    # Código C++ de streaming
├── compile_progressive.sh           # Script de compilación
├── start_system.sh                  # Inicio rápido del sistema
├── stop_system.sh                   # Parada del sistema
├── scripts/                         # Scripts de gestión
│   ├── yolo_manager.sh             # Gestor principal
│   ├── start.sh                    # Inicio automático
│   ├── stop.sh                     # Parada automática
│   └── README.md                   # Documentación de scripts
├── logs/                           # Logs del sistema
│   ├── camera_*.log                # Logs por cámara
│   └── server.log                  # Log del servidor
├── darknet/                        # Framework YOLO
│   ├── build/                      # Binarios compilados
│   ├── custom_models/              # Modelos personalizados
│   ├── cfg/                        # Configuraciones YOLO
│   └── yolov4-tiny.weights         # Modelo principal
└── .gitignore                      # Archivos ignorados por Git
```

## Performance y Optimización

### Configuraciones Recomendadas

| Escenario | Cámaras | Resolución | Modelo | FPS Esperado |
|-----------|---------|------------|---------|--------------|
| **Básico** | 1-2 | 720p | YOLOv4-tiny | 20-30 FPS |
| **Intermedio** | 3-5 | 1080p | YOLOv4-tiny | 15-25 FPS |
| **Avanzado** | 6-10 | 1080p | Personalizado | 10-20 FPS |
| **Máximo** | 11-20 | Variable | Optimizado | 5-15 FPS |

### Optimizaciones

- **GPU CUDA**: Acelera detección hasta 5x
- **Resolución adaptativa**: Automática según carga
- **Streaming progresivo**: Reduce latencia
- **Multiproceso**: Un proceso por cámara

## Integración y Desarrollo

### Agregar Nuevas Funcionalidades

1. **API REST**: Extender rutas en `api_server.js`
2. **Frontend**: Modificar `panel.html` 
3. **C++ Backend**: Editar `simple_stream_progressive.cpp`
4. **Scripts**: Añadir comandos en `scripts/yolo_manager.sh`

### Variables de Entorno

```bash
# Puerto del servidor (default: 3000)
export SERVER_PORT=3000

# Rango de puertos para cámaras
export CAMERA_PORT_START=8080
export CAMERA_PORT_END=8099

# Directorio de Darknet
export DARKNET_DIR=./darknet

# Habilitar logs verbosos
export DEBUG=true
```

## Soporte

### Información del Sistema

```bash
# Información completa para soporte
./scripts/yolo_manager.sh menu
# Opción: "Información del sistema"
```

### Contacto

Para problemas o mejoras:

1. **Logs**: Siempre incluir logs relevantes
2. **Configuración**: Compartir archivos de config (sin passwords)
3. **Sistema**: Especificar OS, GPU, versiones
4. **Reproducción**: Pasos detallados del problema

---

**Proyecto:** Sistema de Detección YOLO Multi-Cámara  
**Versión:** 1.0.0  
**Última actualización:** Agosto 2024  
**Licencia:** Privada - Uso interno