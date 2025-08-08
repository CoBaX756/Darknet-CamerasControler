#!/bin/bash

# Script para solucionar problemas de ejecución de Darknet

echo "═══════════════════════════════════════════════════════════"
echo "    🔧 SOLUCIONANDO PROBLEMAS DE DARKNET"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 1. Verificar el error específico de Darknet
echo "🔍 Verificando el error específico de Darknet..."
echo "Ejecutando: darknet/build/src-cli/darknet help"
echo "----------------------------------------"
darknet/build/src-cli/darknet help 2>&1 | head -20
echo "----------------------------------------"
echo ""

# 2. Verificar dependencias de bibliotecas
echo "📚 Verificando dependencias de bibliotecas..."
echo "Ejecutando ldd en darknet..."
echo "----------------------------------------"
ldd darknet/build/src-cli/darknet 2>&1 | grep "not found" && {
    echo -e "${RED}❌ Faltan bibliotecas compartidas${NC}"
    echo ""
    echo "Intentando solucionar..."
    
    # Verificar si libdarknet.so existe
    if [ -f "darknet/build/src-lib/libdarknet.so" ]; then
        echo "Encontrada libdarknet.so, configurando LD_LIBRARY_PATH..."
        export LD_LIBRARY_PATH="$PWD/darknet/build/src-lib:$LD_LIBRARY_PATH"
        
        # Crear script wrapper
        cat > run_darknet.sh << 'EOF'
#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export LD_LIBRARY_PATH="$SCRIPT_DIR/darknet/build/src-lib:$LD_LIBRARY_PATH"
"$SCRIPT_DIR/darknet/build/src-cli/darknet" "$@"
EOF
        chmod +x run_darknet.sh
        echo -e "${GREEN}✓ Creado script wrapper run_darknet.sh${NC}"
        echo "  Usa ./run_darknet.sh en lugar de darknet directamente"
    fi
} || {
    echo -e "${GREEN}✓ Todas las bibliotecas están presentes${NC}"
}
echo ""

# 3. Verificar configuración de CUDA
echo "🎮 Verificando CUDA (opcional)..."
if nvidia-smi &> /dev/null; then
    echo -e "${GREEN}✓ GPU NVIDIA detectada${NC}"
    nvidia-smi --query-gpu=name,driver_version --format=csv,noheader
else
    echo -e "${YELLOW}⚠ GPU NVIDIA no detectada (usará CPU)${NC}"
fi
echo ""

# 4. Verificar versión de OpenCV
echo "📷 Verificando versión de OpenCV..."
pkg-config --modversion opencv4 2>/dev/null || pkg-config --modversion opencv 2>/dev/null || echo "OpenCV no detectado con pkg-config"
echo ""

# 5. Probar con LD_LIBRARY_PATH configurado
echo "🧪 Probando ejecución con bibliotecas configuradas..."
export LD_LIBRARY_PATH="$PWD/darknet/build/src-lib:$LD_LIBRARY_PATH"
if darknet/build/src-cli/darknet help 2>/dev/null | grep -q "usage"; then
    echo -e "${GREEN}✅ Darknet funciona correctamente con LD_LIBRARY_PATH configurado${NC}"
    echo ""
    echo "Solución permanente:"
    echo "1. Añade esta línea a tu ~/.bashrc:"
    echo "   export LD_LIBRARY_PATH=\"$PWD/darknet/build/src-lib:\$LD_LIBRARY_PATH\""
    echo ""
    echo "2. O usa el script wrapper run_darknet.sh creado"
else
    echo -e "${RED}❌ Darknet sigue sin funcionar${NC}"
    echo ""
    echo "Intentando recompilar..."
    read -p "¿Quieres recompilar Darknet? (s/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        cd darknet
        rm -rf build
        mkdir build
        cd build
        cmake .. -DCMAKE_BUILD_TYPE=Release -DENABLE_OPENCV=ON -DBUILD_SHARED_LIBS=ON
        make -j$(nproc)
        cd ../..
        echo -e "${GREEN}✓ Recompilación completada${NC}"
    fi
fi
echo ""

# 6. Actualizar start.sh para incluir LD_LIBRARY_PATH
echo "🔧 Actualizando start.sh..."
if ! grep -q "LD_LIBRARY_PATH" start.sh; then
    sed -i '5a\
# Configurar bibliotecas de Darknet\
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"\
export LD_LIBRARY_PATH="$SCRIPT_DIR/darknet/build/src-lib:$LD_LIBRARY_PATH"' start.sh
    echo -e "${GREEN}✓ start.sh actualizado con LD_LIBRARY_PATH${NC}"
else
    echo "start.sh ya incluye LD_LIBRARY_PATH"
fi
echo ""

echo "═══════════════════════════════════════════════════════════"
echo "                    📊 RESUMEN"
echo "═══════════════════════════════════════════════════════════"

# Verificar si todo funciona ahora
export LD_LIBRARY_PATH="$PWD/darknet/build/src-lib:$LD_LIBRARY_PATH"
if darknet/build/src-cli/darknet help 2>/dev/null | grep -q "usage"; then
    echo -e "${GREEN}✅ Darknet está funcionando correctamente${NC}"
    echo ""
    echo "Ahora puedes ejecutar:"
    echo "  ./start.sh"
else
    echo -e "${RED}❌ Aún hay problemas con Darknet${NC}"
    echo "Por favor, ejecuta:"
    echo "  ./install.sh"
    echo "O contacta con soporte técnico"
fi

echo "═══════════════════════════════════════════════════════════"