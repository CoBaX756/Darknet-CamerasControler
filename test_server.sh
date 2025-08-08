#!/bin/bash

# Script de prueba para el servidor

echo "Verificando puerto 3000..."
if lsof -Pi :3000 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "ERROR: El puerto 3000 ya está en uso"
    echo "Matando proceso en puerto 3000..."
    fuser -k 3000/tcp
fi

echo "Iniciando servidor API..."
cd /home/xabi/Documentos/Deteccion
node src/server/api_server.js