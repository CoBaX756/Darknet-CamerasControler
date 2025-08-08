# Sistema de Detección Multi-Cámara con YOLO

Sistema completo de detección de objetos en tiempo real con soporte para múltiples cámaras RTSP usando YOLOv4-tiny y Darknet.

## Características

- 🎯 Detección de objetos en tiempo real con YOLOv4-tiny
- 📹 Gestión dinámica de múltiples cámaras RTSP
- 🔌 API REST para control de cámaras
- 🖥️ Interfaz web para visualización de streams
- 📝 Sistema de logs detallado
- ⚙️ Configuración flexible mediante archivos JSON

## Estructura del Proyecto

```
Deteccion/
├── src/                    # Código fuente
│   ├── server/            # Servidor API Node.js
│   │   └── api_server.js
│   └── frontend/          # Interfaz web
│       ├── panel.html
│       └── stream_viewer.html
├── config/                # Archivos de configuración
│   ├── cameras_config.json
│   ├── models_config.json
│   └── detection_config.json
├── darknet/               # Framework YOLO
├── models/                # Modelos de detección
├── logs/                  # Archivos de log
├── scripts/               # Scripts de utilidad
└── docs/                  # Documentación completa
    └── README.md
```

## Requisitos del Sistema

- Ubuntu 20.04+ / Debian 10+ / macOS 11+ / Windows 10+
- Node.js 14.0 o superior
- Python 3.8 o superior
- CMake 3.18 o superior
- GCC/G++ 9.0 o superior (Linux/Mac) o Visual Studio 2019+ (Windows)
- OpenCV 4.0+ (opcional, para visualización)
- CUDA 11.0+ (opcional, para aceleración GPU NVIDIA)

## Instalación Rápida

### Opción 1: Script Automático (Recomendado)

```bash
# Clonar el repositorio
git clone https://github.com/tu-usuario/deteccion-yolo.git
cd deteccion-yolo

# Ejecutar script de instalación
chmod +x install.sh
./install.sh
```

### Opción 2: Instalación Manual

1. **Instalar dependencias del sistema:**
   ```bash
   # Ubuntu/Debian
   sudo apt-get update
   sudo apt-get install -y build-essential cmake git pkg-config
   sudo apt-get install -y libopencv-dev python3-opencv
   sudo apt-get install -y nodejs npm
   
   # macOS
   brew install cmake opencv node
   ```

2. **Instalar dependencias de Node.js:**
   ```bash
   npm install
   ```

3. **Instalar dependencias de Python:**
   ```bash
   pip3 install -r requirements.txt
   ```

4. **Compilar Darknet:**
   ```bash
   cd darknet
   mkdir build && cd build
   cmake ..
   make -j$(nproc)
   cd ../..
   ```

5. **Descargar modelo YOLOv4-tiny (si no está incluido):**
   ```bash
   # El archivo yolov4-tiny.weights ya está incluido
   # Si necesitas descargarlo nuevamente:
   # wget https://github.com/AlexeyAB/darknet/releases/download/darknet_yolo_v4_pre/yolov4-tiny.weights -O darknet/yolov4-tiny.weights
   ```

## Uso

### Iniciar el sistema

```bash
# Iniciar servidor API
node src/server/api_server.js

# O usar el script de inicio
./scripts/start.sh
```

### Acceder a la interfaz web

Abrir en el navegador:
- Panel de control: `http://localhost:3000/src/frontend/panel.html` o `http://localhost:3000`
- Visor de streams: `http://localhost:3000/src/frontend/stream_viewer.html`

### Detener el sistema

```bash
./scripts/stop.sh
```

## Configuración

### Configurar cámaras RTSP

Editar `config/cameras_config.json`:

```json
{
  "cameras": [
    {
      "id": "camera_1",
      "name": "Cámara Principal",
      "rtsp_url": "rtsp://usuario:password@192.168.1.100:554/stream",
      "enabled": true
    }
  ]
}
```

### Ajustar parámetros de detección

Editar `config/detection_config.json`:

```json
{
  "confidence_threshold": 0.5,
  "nms_threshold": 0.4,
  "input_width": 416,
  "input_height": 416
}
```

## API REST

### Endpoints principales

- `GET /api/cameras` - Listar todas las cámaras
- `POST /api/cameras/start/:id` - Iniciar detección en cámara
- `POST /api/cameras/stop/:id` - Detener detección en cámara
- `GET /api/detections/:id` - Obtener detecciones de una cámara

Ver [docs/API_EXAMPLES.md](docs/API_EXAMPLES.md) para más detalles.

## Solución de Problemas

### Error: "darknet: command not found"

```bash
cd darknet
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
cd ../..
```

### Error: "Cannot find module 'express'"

```bash
npm install
```

### Error con OpenCV en Python

```bash
# Ubuntu/Debian
sudo apt-get install python3-opencv

# O con pip
pip3 install opencv-python
```

## Documentación Completa

Ver [docs/README.md](docs/README.md) para información detallada sobre:
- Configuración avanzada
- Personalización de modelos
- Integración con otros sistemas
- Optimización de rendimiento

## Contribuir

Las contribuciones son bienvenidas. Por favor:

1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

## Licencia

MIT License - ver el archivo [LICENSE](LICENSE) para más detalles.

## Soporte

Si encuentras algún problema o tienes preguntas:
- Abre un issue en GitHub
- Consulta la [documentación completa](docs/README.md)
- Revisa los [ejemplos de la API](docs/API_EXAMPLES.md)
