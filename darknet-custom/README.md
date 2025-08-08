# Personalizaciones de Darknet

Este directorio contiene las personalizaciones y añadidos al framework Darknet original.

## Estructura

```
darknet-custom/
├── models/              # Modelos personalizados
│   ├── people-r-people.cfg
│   ├── people-r-people.names
│   └── people-r-people.weights
├── examples/            # Ejemplos de código personalizados
│   ├── camera_config.h
│   ├── simple_stream.cpp
│   ├── simple_stream_progressive.cpp
│   └── web_stream_mjpeg
└── configs/            # Configuraciones modificadas
```

## Uso

Estos archivos deben copiarse a la carpeta `darknet/` después de descargar y compilar Darknet:

```bash
# Después de instalar Darknet
cp -r darknet-custom/models/* darknet/custom_models/
cp darknet-custom/examples/* darknet/src-examples/
```

## Modelos Personalizados

### people-r-people
- Modelo especializado para detección de personas
- Optimizado para cámaras de seguridad
- Configuración personalizada para mejor rendimiento

## Ejemplos de Streaming

### simple_stream.cpp
Implementación básica de streaming RTSP con YOLO.

### simple_stream_progressive.cpp
Versión mejorada con procesamiento progresivo de frames.

### web_stream_mjpeg
Servidor de streaming MJPEG para visualización web.