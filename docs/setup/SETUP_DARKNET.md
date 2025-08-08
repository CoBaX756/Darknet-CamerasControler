# Configuración de Darknet

Darknet es el framework de detección de objetos que utiliza este proyecto. Debido a su tamaño y naturaleza como proyecto independiente, **no está incluido en este repositorio**.

## Instalación de Darknet

### Opción 1: Clonar el repositorio de Hank.ai (Recomendado)

```bash
# Desde el directorio raíz del proyecto
git clone https://github.com/hank-ai/darknet.git darknet
cd darknet

# Compilar Darknet
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
cd ../..
```

### Opción 2: Usar como submódulo de Git

```bash
# Desde el directorio raíz del proyecto
git submodule add https://github.com/hank-ai/darknet.git darknet
git submodule update --init --recursive

# Compilar Darknet
cd darknet
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
cd ../..
```

### Opción 3: Descargar release precompilado

Para Windows o si prefieres no compilar:

1. Visita: https://github.com/AlexeyAB/darknet/releases
2. Descarga el release apropiado para tu sistema
3. Extrae los archivos en el directorio `darknet/`

## Descargar el modelo YOLOv4-tiny

```bash
# Descargar el modelo de pesos
wget https://github.com/AlexeyAB/darknet/releases/download/darknet_yolo_v4_pre/yolov4-tiny.weights \
     -O darknet/yolov4-tiny.weights
```

## Configuración con GPU (Opcional)

### NVIDIA CUDA

Para habilitar aceleración GPU con NVIDIA:

```bash
cd darknet
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release \
         -DENABLE_CUDA=ON \
         -DENABLE_CUDNN=ON
make -j$(nproc)
```

Requisitos:
- CUDA 11.0+
- cuDNN 8.0+
- Driver NVIDIA 450.0+

### AMD ROCm

Para GPUs AMD:

```bash
cd darknet
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release \
         -DENABLE_ZED_CAMERA=OFF \
         -DENABLE_VCPKG_INTEGRATION=OFF
make -j$(nproc)
```

## Verificación

Para verificar que Darknet está correctamente instalado:

```bash
# Verificar que el ejecutable existe
ls darknet/build/darknet || ls darknet/darknet

# Probar detección en una imagen de ejemplo
cd darknet
./darknet detect cfg/yolov4-tiny.cfg yolov4-tiny.weights data/dog.jpg
```

## Estructura esperada

Después de la instalación, deberías tener:

```
Deteccion/
├── darknet/
│   ├── build/
│   │   └── darknet (ejecutable)
│   ├── cfg/
│   │   └── yolov4-tiny.cfg
│   ├── data/
│   └── yolov4-tiny.weights
├── src/
├── config/
└── ...
```

## Solución de problemas

### Error: "CMake 3.18 or higher is required"

```bash
# Ubuntu/Debian
sudo apt-get remove cmake
sudo snap install cmake --classic

# macOS
brew upgrade cmake
```

### Error de compilación con OpenCV

```bash
# Instalar OpenCV development files
sudo apt-get install libopencv-dev

# O compilar sin OpenCV
cmake .. -DENABLE_OPENCV=OFF
```

### Error: "CUDA not found"

Si no tienes GPU NVIDIA, compila sin CUDA:

```bash
cmake .. -DENABLE_CUDA=OFF -DENABLE_CUDNN=OFF
```

## Licencia de Darknet

Darknet (fork de Hank.ai) está licenciado bajo Apache License 2.0. Esto significa que:
- Puedes usar, modificar y distribuir el código
- Debes incluir el aviso de copyright y la licencia Apache 2.0
- Debes documentar cualquier cambio significativo que hagas
- Es compatible con la licencia MIT de este proyecto

## Más información

- Repositorio Hank.ai Darknet: https://github.com/hank-ai/darknet
- Repositorio original AlexeyAB: https://github.com/AlexeyAB/darknet
- Documentación Hank.ai: https://darknetcv.ai/
- Modelos pre-entrenados: https://github.com/AlexeyAB/darknet/releases