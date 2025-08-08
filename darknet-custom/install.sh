#!/bin/bash

# Script para instalar las personalizaciones en Darknet

set -e

echo "Instalando personalizaciones en Darknet..."

# Verificar que darknet existe
if [ ! -d "../darknet" ]; then
    echo "Error: La carpeta darknet no existe. Ejecuta primero install.sh"
    exit 1
fi

# Crear directorios si no existen
mkdir -p ../darknet/custom_models

# Copiar modelos personalizados
echo "Copiando modelos personalizados..."
cp models/* ../darknet/custom_models/

# Copiar ejemplos
echo "Copiando ejemplos personalizados..."
cp examples/*.cpp ../darknet/src-examples/
cp examples/*.h ../darknet/src-examples/
cp examples/web_stream_mjpeg ../darknet/src-examples/

echo "✓ Personalizaciones instaladas exitosamente"
echo ""
echo "Ahora necesitas recompilar Darknet:"
echo "  cd ../darknet/build"
echo "  make clean && make -j\$(nproc)"