#!/bin/bash

# Script de inicio del sistema de detección

echo "Iniciando Sistema de Detección YOLO..."

# Configurar bibliotecas de Darknet
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export LD_LIBRARY_PATH="$SCRIPT_DIR/darknet/build/src-lib:$LD_LIBRARY_PATH"

# Verificar y liberar puerto 3000 si está en uso
if lsof -Pi :3000 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "Puerto 3000 en uso. Liberando..."
    fuser -k 3000/tcp 2>/dev/null
    sleep 1
fi

node src/server/api_server.js