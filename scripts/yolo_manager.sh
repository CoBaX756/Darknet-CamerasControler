#!/bin/bash

# ═══════════════════════════════════════════════════════════════════
# Sistema de Gestión de Cámaras YOLO - Script Unificado
# ═══════════════════════════════════════════════════════════════════

# Colores para mejor visualización
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Variables globales
# Resolver el enlace simbólico si existe
SCRIPT_PATH="${BASH_SOURCE[0]}"
if [ -L "$SCRIPT_PATH" ]; then
    SCRIPT_PATH="$(readlink -f "$SCRIPT_PATH")"
fi
SCRIPT_DIR="$( cd "$( dirname "$SCRIPT_PATH" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"  # Directorio principal del proyecto
PID_FILE="$PROJECT_DIR/.yolo_server.pid"
LOG_FILE="$PROJECT_DIR/yolo_server.log"
SERVER_PORT=3000
PANEL_URL="http://localhost:$SERVER_PORT/src/frontend/panel.html"

# Función para mostrar el banner
show_banner() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}     🎥  Sistema de Detección YOLO Multi-Cámara  🎥      ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Función para verificar requisitos
check_requirements() {
    local missing=0
    
    echo -e "${YELLOW}📋 Verificando requisitos...${NC}"
    
    # Node.js
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version)
        echo -e "  ${GREEN}✓${NC} Node.js instalado ($NODE_VERSION)"
    else
        echo -e "  ${RED}✗${NC} Node.js no instalado"
        missing=1
    fi
    
    # NPM
    if command -v npm &> /dev/null; then
        NPM_VERSION=$(npm --version)
        echo -e "  ${GREEN}✓${NC} NPM instalado (v$NPM_VERSION)"
    else
        echo -e "  ${RED}✗${NC} NPM no instalado"
        missing=1
    fi
    
    # CUDA/GPU
    if nvidia-smi &> /dev/null; then
        GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n1)
        echo -e "  ${GREEN}✓${NC} GPU detectada: $GPU_NAME"
    else
        echo -e "  ${YELLOW}⚠${NC} GPU NVIDIA no detectada (usará CPU)"
    fi
    
    # Darknet
    if [ -f "$PROJECT_DIR/darknet/build/darknet" ] || [ -f "$PROJECT_DIR/darknet/darknet" ] || [ -f "$PROJECT_DIR/darknet/build/src-cli/darknet" ]; then
        echo -e "  ${GREEN}✓${NC} Darknet compilado"
    else
        echo -e "  ${RED}✗${NC} Darknet no compilado"
        missing=1
    fi
    
    # Pesos YOLO
    if [ -f "$PROJECT_DIR/darknet/yolov4-tiny.weights" ]; then
        echo -e "  ${GREEN}✓${NC} Pesos YOLO encontrados"
    else
        echo -e "  ${RED}✗${NC} Pesos YOLO no encontrados"
        missing=1
    fi
    
    echo ""
    return $missing
}

# Función para instalar dependencias
install_dependencies() {
    echo -e "${YELLOW}📦 Instalando dependencias de Node.js...${NC}"
    cd "$PROJECT_DIR"
    
    if [ ! -f "package.json" ]; then
        echo -e "${RED}Error: No se encontró package.json${NC}"
        return 1
    fi
    
    npm install --silent
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Dependencias instaladas${NC}"
    else
        echo -e "${RED}✗ Error instalando dependencias${NC}"
        return 1
    fi
}

# Función para compilar Darknet si es necesario
compile_darknet() {
    echo -e "${YELLOW}🔨 Verificando compilación de Darknet...${NC}"
    
    if [ ! -f "$PROJECT_DIR/darknet/build/darknet" ] && [ ! -f "$PROJECT_DIR/darknet/darknet" ] && [ ! -f "$PROJECT_DIR/darknet/build/src-cli/darknet" ]; then
        echo -e "${YELLOW}Compilando Darknet (esto puede tardar unos minutos)...${NC}"
        cd "$PROJECT_DIR/darknet/build"
        cmake .. > /dev/null 2>&1
        make -j$(nproc) > /dev/null 2>&1
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Darknet compilado exitosamente${NC}"
        else
            echo -e "${RED}✗ Error compilando Darknet${NC}"
            return 1
        fi
    else
        echo -e "${GREEN}✓ Darknet ya está compilado${NC}"
    fi
}

# Función para iniciar el servidor
start_server() {
    echo -e "${YELLOW}🚀 Iniciando servidor...${NC}"
    
    # Verificar si ya está corriendo
    if [ -f "$PID_FILE" ]; then
        OLD_PID=$(cat "$PID_FILE")
        if ps -p "$OLD_PID" > /dev/null 2>&1; then
            echo -e "${YELLOW}⚠ El servidor ya está en ejecución (PID: $OLD_PID)${NC}"
            return 0
        else
            rm "$PID_FILE"
        fi
    fi
    
    # Limpiar puertos si están en uso
    for port in {8080..8099}; do
        fuser -k ${port}/tcp 2>/dev/null
    done
    
    # Iniciar servidor en background
    cd "$PROJECT_DIR"
    if [ -f "src/server/api_server.js" ]; then
        nohup node src/server/api_server.js > "$LOG_FILE" 2>&1 &
    else
        echo -e "${RED}✗ No se encontró el archivo del servidor${NC}"
        return 1
    fi
    SERVER_PID=$!
    echo $SERVER_PID > "$PID_FILE"
    
    # Esperar a que el servidor inicie
    echo -n "  Esperando que el servidor inicie"
    for i in {1..10}; do
        if wget -qO- http://localhost:$SERVER_PORT/api/status > /dev/null 2>&1; then
            echo -e "\n${GREEN}✓ Servidor iniciado exitosamente (PID: $SERVER_PID)${NC}"
            return 0
        fi
        echo -n "."
        sleep 1
    done
    
    echo -e "\n${RED}✗ El servidor no pudo iniciar${NC}"
    echo -e "${YELLOW}Revisa los logs en: $LOG_FILE${NC}"
    return 1
}

# Función para detener el servidor
stop_server() {
    echo -e "${YELLOW}🛑 Deteniendo servidor...${NC}"
    
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            # Detener proceso principal
            kill -SIGTERM "$PID" 2>/dev/null
            sleep 2
            
            # Forzar si no se detuvo
            if ps -p "$PID" > /dev/null 2>&1; then
                kill -SIGKILL "$PID" 2>/dev/null
            fi
            
            echo -e "${GREEN}✓ Servidor detenido${NC}"
        else
            echo -e "${YELLOW}El servidor no estaba en ejecución${NC}"
        fi
        rm -f "$PID_FILE"
    else
        echo -e "${YELLOW}No se encontró proceso del servidor${NC}"
    fi
    
    # Limpiar procesos huérfanos de cámaras
    pkill -f "web_stream_mjpeg" 2>/dev/null
    pkill -f "multi_camera_stream" 2>/dev/null
    
    # Limpiar puertos
    echo -e "${YELLOW}Liberando puertos...${NC}"
    for port in {8080..8099} $SERVER_PORT; do
        fuser -k ${port}/tcp 2>/dev/null
    done
    
    echo -e "${GREEN}✓ Sistema detenido completamente${NC}"
}

# Función para mostrar el estado
show_status() {
    echo -e "${CYAN}📊 Estado del Sistema${NC}"
    echo -e "${CYAN}═══════════════════════════════════${NC}"
    
    # Estado del servidor
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            echo -e "  Servidor: ${GREEN}● Activo${NC} (PID: $PID)"
            
            # Obtener información de la API
            if STATUS=$(wget -qO- http://localhost:$SERVER_PORT/api/status 2>/dev/null); then
                TOTAL=$(echo "$STATUS" | grep -o '"totalCameras":[0-9]*' | cut -d: -f2)
                ACTIVE=$(echo "$STATUS" | grep -o '"activeCameras":[0-9]*' | cut -d: -f2)
                RUNNING=$(echo "$STATUS" | grep -o '"runningProcesses":[0-9]*' | cut -d: -f2)
                
                echo -e "  Cámaras totales: ${WHITE}$TOTAL${NC}"
                echo -e "  Cámaras activas: ${WHITE}$ACTIVE${NC}"
                echo -e "  Procesos ejecutándose: ${WHITE}$RUNNING${NC}"
            fi
        else
            echo -e "  Servidor: ${RED}● Detenido${NC}"
        fi
    else
        echo -e "  Servidor: ${RED}● Detenido${NC}"
    fi
    
    echo ""
    
    # Puertos en uso
    echo -e "${CYAN}🔌 Puertos en uso:${NC}"
    for port in $SERVER_PORT {8080..8099}; do
        if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
            if [ $port -eq $SERVER_PORT ]; then
                echo -e "  Puerto $port: ${GREEN}Panel de control${NC}"
            else
                CAMERA_ID=$((port - 8079))
                echo -e "  Puerto $port: ${GREEN}Cámara #$CAMERA_ID${NC}"
            fi
        fi
    done
    
    echo ""
}

# Función para ver logs
show_logs() {
    echo -e "${CYAN}📄 Logs del servidor (últimas 20 líneas)${NC}"
    echo -e "${CYAN}═══════════════════════════════════${NC}"
    
    if [ -f "$LOG_FILE" ]; then
        tail -n 20 "$LOG_FILE"
    else
        echo -e "${YELLOW}No hay logs disponibles${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}Para ver logs en tiempo real: tail -f $LOG_FILE${NC}"
}

# Función para abrir el panel
open_panel() {
    echo -e "${YELLOW}🌐 Abriendo panel de control...${NC}"
    
    # Verificar que el servidor esté corriendo
    if ! wget -qO- http://localhost:$SERVER_PORT/api/status > /dev/null 2>&1; then
        echo -e "${RED}El servidor no está activo. Iniciando...${NC}"
        start_server
        if [ $? -ne 0 ]; then
            return 1
        fi
    fi
    
    # Intentar abrir con diferentes comandos
    if command -v xdg-open > /dev/null; then
        xdg-open "$PANEL_URL" 2>/dev/null
    elif command -v open > /dev/null; then
        open "$PANEL_URL" 2>/dev/null
    elif command -v firefox > /dev/null; then
        firefox "$PANEL_URL" 2>/dev/null &
    elif command -v chromium-browser > /dev/null; then
        chromium-browser "$PANEL_URL" 2>/dev/null &
    elif command -v google-chrome > /dev/null; then
        google-chrome "$PANEL_URL" 2>/dev/null &
    else
        echo -e "${YELLOW}No se pudo abrir el navegador automáticamente${NC}"
    fi
    
    echo -e "${GREEN}✓ Panel disponible en: ${WHITE}$PANEL_URL${NC}"
}

# Función principal con menú
main_menu() {
    while true; do
        show_banner
        echo -e "${WHITE}Selecciona una opción:${NC}"
        echo ""
        echo -e "  ${CYAN}1)${NC} 🚀 Iniciar sistema completo"
        echo -e "  ${CYAN}2)${NC} 🛑 Detener sistema"
        echo -e "  ${CYAN}3)${NC} 🔄 Reiniciar sistema"
        echo -e "  ${CYAN}4)${NC} 📊 Ver estado"
        echo -e "  ${CYAN}5)${NC} 📄 Ver logs"
        echo -e "  ${CYAN}6)${NC} 🌐 Abrir panel de control"
        echo -e "  ${CYAN}7)${NC} 🔧 Verificar requisitos"
        echo -e "  ${CYAN}8)${NC} 📦 Instalar/Actualizar dependencias"
        echo -e "  ${CYAN}9)${NC} ❌ Salir"
        echo ""
        echo -n -e "${WHITE}Opción: ${NC}"
        read option
        
        echo ""
        
        case $option in
            1)
                check_requirements
                if [ $? -ne 0 ]; then
                    echo -e "${RED}Faltan requisitos. ¿Intentar instalar? (s/n)${NC}"
                    read -r response
                    if [[ "$response" =~ ^[Ss]$ ]]; then
                        install_dependencies
                        compile_darknet
                    else
                        continue
                    fi
                fi
                start_server
                if [ $? -eq 0 ]; then
                    sleep 2
                    open_panel
                fi
                ;;
            2)
                stop_server
                ;;
            3)
                stop_server
                sleep 2
                start_server
                if [ $? -eq 0 ]; then
                    sleep 2
                    open_panel
                fi
                ;;
            4)
                show_status
                ;;
            5)
                show_logs
                ;;
            6)
                open_panel
                ;;
            7)
                check_requirements
                ;;
            8)
                install_dependencies
                compile_darknet
                ;;
            9)
                echo -e "${GREEN}¡Hasta luego!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Opción inválida${NC}"
                ;;
        esac
        
        echo ""
        echo -e "${YELLOW}Presiona Enter para continuar...${NC}"
        read
    done
}

# Función de inicio rápido (sin menú)
quick_start() {
    show_banner
    check_requirements
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}Instalando componentes faltantes...${NC}"
        install_dependencies
        compile_darknet
    fi
    
    start_server
    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
        echo -e "${GREEN}✓ Sistema iniciado exitosamente${NC}"
        echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
        echo ""
        echo -e "  ${CYAN}Panel de control:${NC} ${WHITE}$PANEL_URL${NC}"
        echo -e "  ${CYAN}API REST:${NC} ${WHITE}http://localhost:$SERVER_PORT/api/${NC}"
        echo -e "  ${CYAN}Logs:${NC} ${WHITE}tail -f $LOG_FILE${NC}"
        echo -e "  ${CYAN}Detener:${NC} ${WHITE}$0 stop${NC}"
        echo ""
        
        # Abrir panel automáticamente
        sleep 2
        open_panel
    fi
}

# Procesamiento de argumentos de línea de comandos
case "${1:-}" in
    start)
        quick_start
        ;;
    stop)
        show_banner
        stop_server
        ;;
    restart)
        show_banner
        stop_server
        sleep 2
        quick_start
        ;;
    status)
        show_banner
        show_status
        ;;
    logs)
        show_banner
        show_logs
        ;;
    panel)
        show_banner
        open_panel
        ;;
    menu)
        main_menu
        ;;
    *)
        # Si no hay argumentos, mostrar uso rápido y menú
        if [ -z "${1:-}" ]; then
            show_banner
            echo -e "${WHITE}Uso rápido:${NC}"
            echo -e "  ${CYAN}$0 start${NC}   - Iniciar sistema"
            echo -e "  ${CYAN}$0 stop${NC}    - Detener sistema"
            echo -e "  ${CYAN}$0 restart${NC} - Reiniciar sistema"
            echo -e "  ${CYAN}$0 status${NC}  - Ver estado"
            echo -e "  ${CYAN}$0 logs${NC}    - Ver logs"
            echo -e "  ${CYAN}$0 panel${NC}   - Abrir panel"
            echo -e "  ${CYAN}$0 menu${NC}    - Menú interactivo"
            echo ""
            echo -e "${YELLOW}Presiona Enter para abrir el menú o Ctrl+C para salir${NC}"
            read
            main_menu
        else
            echo -e "${RED}Comando desconocido: $1${NC}"
            echo -e "Usa: $0 {start|stop|restart|status|logs|panel|menu}"
            exit 1
        fi
        ;;
esac