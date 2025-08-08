#!/bin/bash

# Script de diagnóstico para el sistema de detección

echo "═══════════════════════════════════════════════════════════"
echo "    🔍 DIAGNÓSTICO DEL SISTEMA DE DETECCIÓN YOLO"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Función para verificar
check() {
    if [ $1 -eq 0 ]; then
        echo -e "  ${GREEN}✓${NC} $2"
    else
        echo -e "  ${RED}✗${NC} $2"
    fi
}

# 1. Verificar estructura de directorios
echo "📁 Verificando estructura de directorios..."
[ -d "darknet" ] && check 0 "Directorio darknet existe" || check 1 "Directorio darknet NO existe"
[ -d "darknet/build" ] && check 0 "Directorio darknet/build existe" || check 1 "Directorio darknet/build NO existe"
[ -d "src/server" ] && check 0 "Directorio src/server existe" || check 1 "Directorio src/server NO existe"
[ -d "logs" ] && check 0 "Directorio logs existe" || check 1 "Directorio logs NO existe"
echo ""

# 2. Verificar ejecutables de Darknet
echo "🔨 Verificando ejecutables de Darknet..."
DARKNET_LOCATIONS=(
    "darknet/build/darknet"
    "darknet/darknet"
    "darknet/build/src-cli/darknet"
)

DARKNET_FOUND=0
for location in "${DARKNET_LOCATIONS[@]}"; do
    if [ -f "$location" ]; then
        check 0 "Darknet encontrado en: $location"
        # Verificar si es ejecutable
        if [ -x "$location" ]; then
            check 0 "  → Es ejecutable"
            # Probar ejecución
            echo -n "  → Probando ejecución... "
            if $location help 2>/dev/null | grep -q "usage"; then
                echo -e "${GREEN}funciona${NC}"
            else
                echo -e "${RED}NO funciona${NC}"
            fi
        else
            check 1 "  → NO es ejecutable (falta permiso)"
            echo "    Ejecuta: chmod +x $location"
        fi
        DARKNET_FOUND=1
        break
    fi
done

if [ $DARKNET_FOUND -eq 0 ]; then
    check 1 "Darknet NO encontrado en ninguna ubicación conocida"
    echo "  Buscando darknet en todo el proyecto..."
    find . -name "darknet" -type f 2>/dev/null | head -5
fi
echo ""

# 3. Verificar simple_stream_progressive
echo "📹 Verificando ejecutable de streaming..."
STREAM_EXEC="darknet/build/src-examples/simple_stream_progressive"
if [ -f "$STREAM_EXEC" ]; then
    check 0 "simple_stream_progressive encontrado"
    if [ -x "$STREAM_EXEC" ]; then
        check 0 "  → Es ejecutable"
    else
        check 1 "  → NO es ejecutable"
        echo "    Ejecuta: chmod +x $STREAM_EXEC"
    fi
else
    check 1 "simple_stream_progressive NO encontrado"
    echo "  Buscando en src-examples..."
    ls -la darknet/build/src-examples/ 2>/dev/null | grep stream | head -5
fi
echo ""

# 4. Verificar pesos del modelo
echo "🧠 Verificando modelos YOLO..."
if [ -f "darknet/yolov4-tiny.weights" ]; then
    check 0 "yolov4-tiny.weights encontrado"
    SIZE=$(du -h "darknet/yolov4-tiny.weights" | cut -f1)
    echo "    Tamaño: $SIZE"
else
    check 1 "yolov4-tiny.weights NO encontrado"
fi

if [ -f "darknet/cfg/yolov4-tiny.cfg" ]; then
    check 0 "yolov4-tiny.cfg encontrado"
else
    check 1 "yolov4-tiny.cfg NO encontrado"
fi
echo ""

# 5. Verificar archivos de configuración
echo "⚙️ Verificando archivos de configuración..."
if [ -f "darknet/cfg/coco.names" ]; then
    check 0 "coco.names encontrado"
    LINES=$(wc -l < "darknet/cfg/coco.names")
    echo "    Clases detectables: $LINES"
else
    check 1 "coco.names NO encontrado"
fi
echo ""

# 6. Verificar Node.js y dependencias
echo "📦 Verificando Node.js..."
if command -v node &> /dev/null; then
    NODE_VER=$(node --version)
    check 0 "Node.js instalado: $NODE_VER"
else
    check 1 "Node.js NO instalado"
fi

if [ -f "package.json" ]; then
    check 0 "package.json existe"
    if [ -d "node_modules" ]; then
        check 0 "node_modules existe"
        COUNT=$(ls node_modules | wc -l)
        echo "    Módulos instalados: $COUNT"
    else
        check 1 "node_modules NO existe - ejecuta: npm install"
    fi
else
    check 1 "package.json NO existe"
fi
echo ""

# 7. Verificar permisos
echo "🔐 Verificando permisos..."
if [ -w "logs" ]; then
    check 0 "Directorio logs escribible"
else
    check 1 "Directorio logs NO escribible"
fi

if [ -w "config" ]; then
    check 0 "Directorio config escribible"
else
    check 1 "Directorio config NO escribible"
fi
echo ""

# 8. Verificar bibliotecas del sistema
echo "📚 Verificando bibliotecas del sistema..."
if ldconfig -p | grep -q libopencv; then
    check 0 "OpenCV instalado"
else
    check 1 "OpenCV NO encontrado - instala: sudo apt-get install libopencv-dev"
fi

if ldconfig -p | grep -q libpthread; then
    check 0 "pthread instalado"
else
    check 1 "pthread NO encontrado"
fi
echo ""

# 9. Probar compilación simple
echo "🔧 Probando compilación de Darknet..."
if [ -d "darknet" ] && [ ! -f "darknet/build/darknet" ] && [ ! -f "darknet/build/src-cli/darknet" ]; then
    echo "  Darknet no está compilado. ¿Intentar compilar ahora? (s/n)"
    read -r response
    if [[ "$response" =~ ^[Ss]$ ]]; then
        cd darknet
        if [ ! -d "build" ]; then
            mkdir build
        fi
        cd build
        cmake .. && make -j$(nproc)
        cd ../..
    fi
fi
echo ""

# 10. Resumen
echo "═══════════════════════════════════════════════════════════"
echo "                    📊 RESUMEN"
echo "═══════════════════════════════════════════════════════════"

# Contar problemas
PROBLEMS=0

if [ ! -f "darknet/build/src-cli/darknet" ] && [ ! -f "darknet/build/darknet" ]; then
    echo -e "${RED}⚠ PROBLEMA CRÍTICO:${NC} Darknet no está compilado"
    echo "  Solución: cd darknet/build && cmake .. && make -j$(nproc)"
    PROBLEMS=$((PROBLEMS + 1))
fi

if [ ! -f "darknet/build/src-examples/simple_stream_progressive" ]; then
    echo -e "${RED}⚠ PROBLEMA CRÍTICO:${NC} simple_stream_progressive no existe"
    echo "  Solución: Recompilar darknet completamente"
    PROBLEMS=$((PROBLEMS + 1))
fi

if [ ! -f "darknet/yolov4-tiny.weights" ]; then
    echo -e "${RED}⚠ PROBLEMA:${NC} Falta el modelo yolov4-tiny.weights"
    echo "  Solución: Descargar desde el repositorio o ejecutar install.sh"
    PROBLEMS=$((PROBLEMS + 1))
fi

if [ ! -d "node_modules" ]; then
    echo -e "${YELLOW}⚠ ADVERTENCIA:${NC} Dependencias de Node.js no instaladas"
    echo "  Solución: npm install"
    PROBLEMS=$((PROBLEMS + 1))
fi

if [ $PROBLEMS -eq 0 ]; then
    echo -e "${GREEN}✅ El sistema parece estar correctamente configurado${NC}"
    echo ""
    echo "Para iniciar el sistema ejecuta:"
    echo "  ./start.sh"
else
    echo ""
    echo -e "${RED}Se encontraron $PROBLEMS problemas que necesitan atención${NC}"
fi

echo "═══════════════════════════════════════════════════════════"