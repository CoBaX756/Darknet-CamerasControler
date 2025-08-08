#!/bin/bash

# Script de instalación automática para el Sistema de Detección Multi-Cámara con YOLO
# Detecta el sistema operativo e instala todas las dependencias necesarias

set -e  # Salir si hay algún error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Función para imprimir mensajes con color
print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Detectar sistema operativo
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/debian_version ]; then
            OS="debian"
        elif [ -f /etc/redhat-release ]; then
            OS="redhat"
        else
            OS="linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        OS="windows"
    else
        OS="unknown"
    fi
    print_message "Sistema operativo detectado: $OS"
}

# Instalar dependencias del sistema para Debian/Ubuntu
install_debian_deps() {
    print_message "Instalando dependencias del sistema para Debian/Ubuntu..."
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
}

# Instalar dependencias del sistema para macOS
install_macos_deps() {
    print_message "Instalando dependencias del sistema para macOS..."
    
    # Verificar si Homebrew está instalado
    if ! command -v brew &> /dev/null; then
        print_warning "Homebrew no está instalado. Instalando Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    
    brew update
    brew install cmake opencv node ffmpeg wget
}

# Instalar dependencias del sistema para RedHat/CentOS
install_redhat_deps() {
    print_message "Instalando dependencias del sistema para RedHat/CentOS..."
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
}

# Instalar dependencias de Node.js
install_node_deps() {
    print_message "Instalando dependencias de Node.js..."
    if [ -f "package.json" ]; then
        npm install
    else
        print_error "No se encontró package.json"
        exit 1
    fi
}

# Instalar dependencias de Python
install_python_deps() {
    print_message "Instalando dependencias de Python..."
    if [ -f "requirements.txt" ]; then
        pip3 install --user -r requirements.txt
    else
        print_warning "No se encontró requirements.txt, saltando instalación de dependencias Python"
    fi
}

# Compilar Darknet
compile_darknet() {
    print_message "Compilando Darknet..."
    
    if [ ! -d "darknet" ]; then
        print_error "Directorio darknet no encontrado"
        exit 1
    fi
    
    cd darknet
    
    # Limpiar builds anteriores
    if [ -d "build" ]; then
        print_message "Limpiando build anterior..."
        rm -rf build
    fi
    
    # Crear directorio de build y compilar
    mkdir build
    cd build
    
    print_message "Configurando CMake..."
    cmake .. -DCMAKE_BUILD_TYPE=Release
    
    print_message "Compilando... (esto puede tomar varios minutos)"
    if [[ "$OS" == "macos" ]]; then
        make -j$(sysctl -n hw.ncpu)
    else
        make -j$(nproc)
    fi
    
    cd ../..
    print_message "Darknet compilado exitosamente"
}

# Verificar modelo YOLO
check_yolo_model() {
    print_message "Verificando modelo YOLO..."
    
    if [ ! -f "darknet/yolov4-tiny.weights" ]; then
        print_warning "Modelo yolov4-tiny.weights no encontrado. Descargando..."
        wget https://github.com/AlexeyAB/darknet/releases/download/darknet_yolo_v4_pre/yolov4-tiny.weights \
             -O darknet/yolov4-tiny.weights
        print_message "Modelo descargado exitosamente"
    else
        print_message "Modelo yolov4-tiny.weights encontrado"
    fi
}

# Crear directorios necesarios
create_directories() {
    print_message "Creando directorios necesarios..."
    
    [ ! -d "logs" ] && mkdir -p logs
    [ ! -d "models" ] && mkdir -p models
    [ ! -d "web_stream" ] && mkdir -p web_stream
    
    print_message "Directorios creados"
}

# Configurar permisos de scripts
setup_permissions() {
    print_message "Configurando permisos de scripts..."
    
    if [ -d "scripts" ]; then
        chmod +x scripts/*.sh
    fi
    
    if [ -f "start.sh" ]; then
        chmod +x start.sh
    fi
    
    chmod +x install.sh
    
    print_message "Permisos configurados"
}

# Verificar instalación
verify_installation() {
    print_message "Verificando instalación..."
    
    # Verificar Node.js
    if command -v node &> /dev/null; then
        print_message "Node.js instalado: $(node --version)"
    else
        print_error "Node.js no está instalado correctamente"
        exit 1
    fi
    
    # Verificar Python
    if command -v python3 &> /dev/null; then
        print_message "Python instalado: $(python3 --version)"
    else
        print_error "Python3 no está instalado correctamente"
        exit 1
    fi
    
    # Verificar CMake
    if command -v cmake &> /dev/null; then
        print_message "CMake instalado: $(cmake --version | head -n 1)"
    else
        print_error "CMake no está instalado correctamente"
        exit 1
    fi
    
    # Verificar Darknet
    if [ -f "darknet/build/darknet" ] || [ -f "darknet/darknet" ]; then
        print_message "Darknet compilado correctamente"
    else
        print_error "Darknet no se compiló correctamente"
        exit 1
    fi
    
    print_message "Verificación completada exitosamente"
}

# Función principal
main() {
    echo "========================================"
    echo "  Instalación del Sistema de Detección  "
    echo "       Multi-Cámara con YOLO           "
    echo "========================================"
    echo
    
    # Detectar OS
    detect_os
    
    # Instalar dependencias según el OS
    case $OS in
        debian)
            install_debian_deps
            ;;
        macos)
            install_macos_deps
            ;;
        redhat)
            install_redhat_deps
            ;;
        *)
            print_error "Sistema operativo no soportado: $OS"
            print_message "Por favor, instala las dependencias manualmente"
            exit 1
            ;;
    esac
    
    # Instalar dependencias de lenguajes
    install_node_deps
    install_python_deps
    
    # Compilar Darknet
    compile_darknet
    
    # Verificar modelo
    check_yolo_model
    
    # Crear directorios
    create_directories
    
    # Configurar permisos
    setup_permissions
    
    # Verificar instalación
    verify_installation
    
    # Instalar personalizaciones si existen
    if [ -d "darknet-custom" ]; then
        print_message "Instalando personalizaciones de Darknet..."
        cd darknet-custom
        ./install.sh
        cd ..
    fi
    
    echo
    echo "========================================"
    print_message "¡Instalación completada exitosamente!"
    echo "========================================"
    echo
    print_message "Para iniciar el sistema, ejecuta:"
    echo "  node src/server/api_server.js"
    echo
    print_message "O usa el script de inicio:"
    echo "  ./scripts/start.sh"
    echo
    print_message "Accede al panel de control en:"
    echo "  http://localhost:3000/src/frontend/panel.html"
    echo
}

# Ejecutar función principal
main