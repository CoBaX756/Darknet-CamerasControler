# Ejemplos de API - Sistema de Detección YOLO

## Configuración Base

Reemplaza `localhost` con la IP de tu servidor si accedes desde otro equipo en la red local.

```bash
BASE_URL="http://localhost:3000"
# O desde red local:
# BASE_URL="http://192.168.1.XXX:3000"
```

## 📹 Endpoints de Cámaras

### Listar todas las cámaras
```bash
curl -X GET "${BASE_URL}/api/cameras"
```

### Obtener información de una cámara específica
```bash
curl -X GET "${BASE_URL}/api/cameras/1"
```

### Iniciar una cámara
```bash
curl -X POST "${BASE_URL}/api/cameras/1/start"
```

### Detener una cámara
```bash
curl -X POST "${BASE_URL}/api/cameras/1/stop"
```

### Actualizar configuración de una cámara
```bash
curl -X PUT "${BASE_URL}/api/cameras/1" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Oficina Principal",
    "ip": "192.168.1.124",
    "username": "admin",
    "password": "admin123",
    "path": "/Streaming/Channels/1",
    "modelId": "yolov4-tiny"
  }'
```

### Agregar nueva cámara
```bash
curl -X POST "${BASE_URL}/api/cameras" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Nueva Cámara",
    "ip": "192.168.1.200",
    "username": "admin",
    "password": "password",
    "path": "/Streaming/Channels/1",
    "modelId": "yolov4-tiny"
  }'
```

### Eliminar cámara
```bash
curl -X DELETE "${BASE_URL}/api/cameras/5"
```

## ⚙️ Configuración Avanzada

### Actualizar calidad y opciones de detección
```bash
curl -X PUT "${BASE_URL}/api/cameras/1/settings" \
  -H "Content-Type: application/json" \
  -d '{
    "quality": "high",
    "resolution": "1080p",
    "jpegQuality": 85,
    "detectionEnabled": true,
    "showBoundingBoxes": true,
    "showLabels": true,
    "showConfidence": true,
    "minConfidence": 0.5
  }'
```

### Reiniciar cámara con nueva configuración
```bash
curl -X POST "${BASE_URL}/api/cameras/1/restart"
```

## 🎯 Configuración de Detección

### Obtener configuración de detección
```bash
curl -X GET "${BASE_URL}/api/detection/config/1"
```

### Actualizar objetos a detectar
```bash
# 0=persona, 1=bicicleta, 2=coche, 3=motocicleta, etc.
curl -X POST "${BASE_URL}/api/detection/config/1" \
  -H "Content-Type: application/json" \
  -d '{
    "enabled": {
      "0": true,
      "1": false,
      "2": true,
      "3": false
    }
  }'
```

## 🤖 Modelos YOLO

### Listar modelos disponibles
```bash
curl -X GET "${BASE_URL}/api/models"
```

### Cargar modelo personalizado
```bash
curl -X POST "${BASE_URL}/api/models/upload" \
  -F "name=Mi Modelo Custom" \
  -F "files=@/ruta/a/modelo.cfg" \
  -F "files=@/ruta/a/modelo.weights" \
  -F "files=@/ruta/a/modelo.names"
```

### Eliminar modelo personalizado
```bash
curl -X DELETE "${BASE_URL}/api/models/custom_123456789"
```

## 📊 Sistema

### Estado del sistema
```bash
curl -X GET "${BASE_URL}/api/status"
```

### Detener todas las cámaras
```bash
curl -X POST "${BASE_URL}/api/stop-all"
```

## 🖥️ Acceso al Stream

Una vez iniciada una cámara, puedes acceder al stream directamente:

```
http://localhost:8080/         # Cámara 1
http://localhost:8081/         # Cámara 2
http://localhost:8082/         # Cámara 3
http://localhost:8083/         # Cámara 4
```

## 📱 Acceso desde Red Local

1. Encuentra tu IP local:
   ```bash
   # Linux/Mac
   ip addr show | grep "inet " | grep -v 127.0.0.1
   
   # Windows
   ipconfig | findstr IPv4
   ```

2. Accede desde cualquier dispositivo en la red:
   - Panel: `http://TU_IP:3000`
   - API: `http://TU_IP:3000/api/cameras`
   - Stream: `http://TU_IP:8080`

## 🔧 Ejemplos con Python

```python
import requests

BASE_URL = "http://localhost:3000"

# Listar cámaras
response = requests.get(f"{BASE_URL}/api/cameras")
cameras = response.json()
print(cameras)

# Iniciar cámara
response = requests.post(f"{BASE_URL}/api/cameras/1/start")
print(response.json())

# Actualizar configuración
config = {
    "quality": "medium",
    "detectionEnabled": True,
    "minConfidence": 0.6
}
response = requests.put(f"{BASE_URL}/api/cameras/1/settings", json=config)
print(response.json())
```

## 📝 Postman Collection

Importa el archivo `postman_collection.json` en Postman para tener todos los endpoints configurados y listos para usar.