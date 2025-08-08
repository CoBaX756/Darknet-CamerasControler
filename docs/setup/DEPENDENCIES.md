# Dependencias del Sistema

## Dependencias Principales

### Sistema Operativo
- **Linux**: Ubuntu 20.04+, Debian 10+, CentOS 8+
- **macOS**: 11.0 Big Sur o superior
- **Windows**: Windows 10+ con WSL2 (recomendado)

### Lenguajes y Runtimes
- **Node.js**: v14.0.0 o superior
- **Python**: 3.8 o superior
- **C/C++**: GCC 9.0+ / Clang 10+ / MSVC 2019+

### Herramientas de Compilación
- **CMake**: 3.18 o superior
- **Make**: GNU Make 4.0+
- **pkg-config**: 0.29+

## Dependencias de Node.js

Las siguientes dependencias se instalan automáticamente con `npm install`:

- **express**: ^4.21.2 - Framework web
- **body-parser**: ^1.20.3 - Parser de body para requests
- **cors**: ^2.8.5 - Manejo de CORS
- **ws**: ^8.18.3 - WebSocket para streaming
- **fluent-ffmpeg**: ^2.1.2 - Procesamiento de video
- **multer**: ^2.0.2 - Manejo de uploads
- **node-rtsp-stream**: ^0.0.9 - Streaming RTSP
- **child_process**: ^1.0.2 - Ejecución de procesos

## Dependencias de Python

Las siguientes dependencias se instalan con `pip install -r requirements.txt`:

- **opencv-python**: >=4.5.0 - Procesamiento de imágenes
- **numpy**: >=1.19.0 - Computación numérica
- **scikit-image**: >=0.18.0 - Algoritmos de procesamiento de imágenes

## Dependencias del Sistema

### Ubuntu/Debian
```bash
sudo apt-get update
sudo apt-get install -y \
    build-essential \
    cmake \
    git \
    pkg-config \
    libopencv-dev \
    python3-opencv \
    python3-pip \
    nodejs \
    npm \
    ffmpeg \
    wget \
    curl
```

### macOS
```bash
# Requiere Homebrew
brew install cmake opencv node ffmpeg wget
```

### CentOS/RHEL/Fedora
```bash
sudo yum groupinstall -y "Development Tools"
sudo yum install -y \
    cmake \
    git \
    opencv-devel \
    python3-pip \
    nodejs \
    npm \
    ffmpeg \
    wget \
    curl
```

## Dependencias Opcionales

### Para Aceleración GPU

#### NVIDIA CUDA (opcional)
- CUDA Toolkit 11.0 o superior
- cuDNN 8.0 o superior
- Driver NVIDIA 450.0 o superior

```bash
# Verificar CUDA
nvcc --version
nvidia-smi
```

#### AMD ROCm (opcional)
- ROCm 4.0 o superior
- Compatible con GPU AMD Radeon VII, MI50, MI60

### Para Desarrollo

- **Git**: Control de versiones
- **Docker**: Contenerización (opcional)
- **Visual Studio Code**: IDE recomendado

## Verificación de Dependencias

Ejecuta el siguiente script para verificar todas las dependencias:

```bash
#!/bin/bash

echo "Verificando dependencias..."

# Node.js
if command -v node &> /dev/null; then
    echo "✓ Node.js: $(node --version)"
else
    echo "✗ Node.js no instalado"
fi

# Python
if command -v python3 &> /dev/null; then
    echo "✓ Python: $(python3 --version)"
else
    echo "✗ Python3 no instalado"
fi

# CMake
if command -v cmake &> /dev/null; then
    echo "✓ CMake: $(cmake --version | head -n 1)"
else
    echo "✗ CMake no instalado"
fi

# OpenCV Python
python3 -c "import cv2; print(f'✓ OpenCV Python: {cv2.__version__}')" 2>/dev/null || echo "✗ OpenCV Python no instalado"

# FFmpeg
if command -v ffmpeg &> /dev/null; then
    echo "✓ FFmpeg: $(ffmpeg -version | head -n 1)"
else
    echo "✗ FFmpeg no instalado"
fi

# CUDA (opcional)
if command -v nvcc &> /dev/null; then
    echo "✓ CUDA: $(nvcc --version | grep release)"
else
    echo "ℹ CUDA no instalado (opcional)"
fi
```

## Solución de Problemas Comunes

### Error: "cmake: command not found"
```bash
# Ubuntu/Debian
sudo apt-get install cmake

# macOS
brew install cmake

# CentOS/RHEL
sudo yum install cmake
```

### Error: "ImportError: No module named cv2"
```bash
# Opción 1: Usar gestor de paquetes
sudo apt-get install python3-opencv

# Opción 2: Usar pip
pip3 install opencv-python
```

### Error: "node: command not found"
```bash
# Ubuntu/Debian
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs

# macOS
brew install node
```

### Error de compilación de Darknet
```bash
# Asegurarse de tener todas las dependencias
sudo apt-get install build-essential git pkg-config

# Limpiar y recompilar
cd darknet
rm -rf build
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
```

## Notas Adicionales

- El sistema ha sido probado principalmente en Ubuntu 20.04 y macOS Big Sur
- Para Windows, se recomienda usar WSL2 con Ubuntu
- La aceleración GPU es opcional pero mejora significativamente el rendimiento
- Asegúrate de tener al menos 4GB de RAM disponible para compilar Darknet