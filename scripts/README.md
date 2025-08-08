# 📹 Sistema de Detección YOLO Multi-Cámara - Scripts

## 📁 Estructura de Scripts

Este directorio contiene todos los scripts necesarios para gestionar el sistema de detección YOLO con múltiples cámaras RTSP.

### Scripts Principales

| Script | Descripción | Uso |
|--------|-------------|-----|
| `yolo_manager.sh` | Script principal de gestión | Controla todo el sistema |
| `start.sh` | Inicio rápido | Arranca el sistema completo |
| `stop.sh` | Parada rápida | Detiene todo el sistema |
| `.yolo_config` | Archivo de configuración | Parámetros del sistema |

## 🚀 Uso Rápido

### Desde el directorio principal del proyecto:

```bash
# Iniciar el sistema completo
./start.sh

# Detener el sistema
./stop.sh

# Ver estado
./yolo_manager.sh status

# Menú interactivo
./yolo_manager.sh menu
```

## 📋 Comandos del Gestor Principal

El script `yolo_manager.sh` ofrece los siguientes comandos:

```bash
# Iniciar sistema con verificación de requisitos
./yolo_manager.sh start

# Detener todos los servicios
./yolo_manager.sh stop

# Reiniciar el sistema
./yolo_manager.sh restart

# Ver estado actual
./yolo_manager.sh status

# Ver logs del servidor
./yolo_manager.sh logs

# Abrir panel de control en navegador
./yolo_manager.sh panel

# Menú interactivo con todas las opciones
./yolo_manager.sh menu
```

## 🎯 Características del Sistema

### Gestión Automática
- ✅ Verificación de requisitos (Node.js, GPU, Darknet)
- ✅ Instalación automática de dependencias
- ✅ Compilación de Darknet si es necesario
- ✅ Limpieza de puertos automática
- ✅ Gestión de procesos con PID tracking

### Panel Web Dinámico
- ✅ Agregar/eliminar cámaras sin reiniciar
- ✅ Vista previa de múltiples streams
- ✅ Detección YOLO en tiempo real
- ✅ API REST completa

### Puertos Utilizados
- **3000**: Panel de control web y API
- **8080-8099**: Streams de cámaras (una por puerto)

## 📝 Configuración

El archivo `.yolo_config` contiene:

```bash
# Puerto del servidor web
SERVER_PORT=3000

# Rango de puertos para cámaras
CAMERA_PORT_START=8080
CAMERA_PORT_END=8099

# Rutas de Darknet
DARKNET_DIR="darknet"
WEIGHTS_FILE="yolov4-tiny.weights"

# Opciones
AUTO_OPEN_BROWSER=true
MAX_CAMERAS=20
```

## 🔧 Solución de Problemas

### El sistema no inicia
```bash
# Verificar requisitos
./yolo_manager.sh menu
# Seleccionar opción 7 (Verificar requisitos)

# Ver logs detallados
tail -f ../yolo_server.log
```

### Puerto en uso
```bash
# Limpiar todos los puertos
./yolo_manager.sh stop
./yolo_manager.sh start
```

### Cámara no conecta
- Verificar IP y credenciales en el panel web
- Probar URL RTSP con: `ffplay rtsp://user:pass@ip:port/path`

## 📊 Archivos Generados

| Archivo | Ubicación | Descripción |
|---------|-----------|-------------|
| `.yolo_server.pid` | Raíz del proyecto | PID del servidor |
| `yolo_server.log` | Raíz del proyecto | Logs del sistema |
| `cameras.json` | Raíz del proyecto | Configuración de cámaras |

## 🌐 URLs del Sistema

Una vez iniciado:
- **Panel de Control**: http://localhost:3000/camera_panel_v2.html
- **API REST**: http://localhost:3000/api/
- **Stream Cámara 1**: http://localhost:8080/
- **Stream Cámara 2**: http://localhost:8081/
- (y así sucesivamente...)

## 💡 Tips de Uso

1. **Inicio rápido**: Usa `./start.sh` desde cualquier lugar
2. **Monitoreo**: Mantén abierto `tail -f yolo_server.log` en otra terminal
3. **Múltiples cámaras**: El panel web permite agregar hasta 20 cámaras dinámicamente
4. **Backup**: Exporta la configuración desde el panel web regularmente

## 🛠️ Requisitos del Sistema

- Ubuntu 20.04+ o similar
- Node.js 14+ y NPM
- NVIDIA GPU con CUDA (opcional pero recomendado)
- OpenCV 4.x
- Darknet compilado
- Conexión de red a las cámaras RTSP

## 📞 Soporte

Si encuentras problemas:
1. Revisa los logs: `tail -f yolo_server.log`
2. Verifica el estado: `./yolo_manager.sh status`
3. Usa el menú interactivo: `./yolo_manager.sh menu`

---
*Sistema desarrollado para gestión dinámica de múltiples cámaras RTSP con detección de objetos usando YOLO*