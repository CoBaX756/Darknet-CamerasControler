#!/bin/bash

# Script de inicio del sistema de detección

echo "Iniciando Sistema de Detección YOLO..."

# Verificar y liberar puerto 3000 si está en uso
if lsof -Pi :3000 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "Puerto 3000 en uso. Liberando..."
    fuser -k 3000/tcp 2>/dev/null
    sleep 1
fi

node src/server/api_server.js