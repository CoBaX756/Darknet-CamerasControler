# Gestión de Versiones y Compatibilidad

## Problema

Las actualizaciones futuras de Darknet podrían romper la compatibilidad con nuestras personalizaciones o cambiar APIs que usamos.

## Solución Implementada

### 1. Versión Fija de Darknet

El proyecto usa por defecto la versión **v3.0.53** de Darknet, que ha sido probada y verificada como compatible con todas nuestras personalizaciones.

### 2. Archivo de Configuración `.env`

El proyecto incluye un archivo `.env.example` que especifica:

```bash
# Versión de Darknet (tag, branch o commit)
DARKNET_VERSION="v3.0.53"

# Repositorio de Darknet (puedes usar tu propio fork)
DARKNET_REPO="https://github.com/hank-ai/darknet.git"

# URL del modelo
YOLO_WEIGHTS_URL="https://github.com/AlexeyAB/darknet/releases/download/darknet_yolo_v4_pre/yolov4-tiny.weights"

# Opciones de compilación
ENABLE_CUDA="OFF"
ENABLE_OPENCV="ON"
```

### 3. Cómo Cambiar la Versión

#### Usar la última versión (master)
```bash
# Editar .env
DARKNET_VERSION="master"
```
⚠️ **Advertencia:** Puede romper compatibilidad

#### Usar una versión específica
```bash
# Listar versiones disponibles
git ls-remote --tags https://github.com/hank-ai/darknet.git

# Editar .env con la versión deseada
DARKNET_VERSION="v3.0.50"
```

#### Usar un commit específico
```bash
# Editar .env con el hash del commit
DARKNET_VERSION="abc123def456"
```

### 4. Crear tu Propio Fork

Para máximo control:

1. **Fork el repositorio de Darknet**
   ```bash
   # En GitHub, hacer fork de https://github.com/hank-ai/darknet
   ```

2. **Actualizar .env**
   ```bash
   DARKNET_REPO="https://github.com/TU-USUARIO/darknet.git"
   DARKNET_VERSION="tu-branch-estable"
   ```

3. **Aplicar tus cambios directamente en el fork**
   - Puedes integrar las personalizaciones directamente
   - Mantener tu propia versión estable

### 5. Versiones Probadas

| Versión Darknet | Estado | Notas |
|-----------------|--------|-------|
| v3.0.53 | ✅ Estable | Versión por defecto, totalmente compatible |
| v3.0.52 | ✅ Compatible | Probada, funciona correctamente |
| v3.0.51 | ✅ Compatible | Probada, funciona correctamente |
| v3.0.50 | ⚠️ No probada | Debería funcionar |
| master | ⚠️ Variable | Puede funcionar o no según cambios recientes |

### 6. Qué Hacer si una Actualización Rompe Compatibilidad

1. **Volver a la versión estable**
   ```bash
   cd darknet
   git checkout v3.0.53
   cd ..
   rm -rf darknet/build
   ./install.sh
   ```

2. **Reportar el problema**
   - Abrir un issue en este repositorio
   - Especificar la versión que causa problemas

3. **Actualizar personalizaciones**
   - Revisar cambios en Darknet
   - Actualizar archivos en `darknet-custom/`
   - Probar y validar

### 7. Mejores Prácticas

1. **Siempre usa versiones específicas en producción**
   - Nunca uses `master` en producción
   - Documenta la versión que usas

2. **Prueba actualizaciones en desarrollo primero**
   ```bash
   # Entorno de desarrollo
   DARKNET_VERSION="nueva-version"
   ./install.sh
   # Probar todo
   ```

3. **Mantén un registro de cambios**
   - Documenta qué versiones funcionan
   - Anota cualquier ajuste necesario

4. **Considera mantener tu propio fork**
   - Mayor control sobre actualizaciones
   - Puedes integrar personalizaciones
   - Evitas sorpresas por cambios externos

### 8. Automatización de Pruebas

Para proyectos críticos, considera:

```bash
#!/bin/bash
# test_darknet_version.sh

VERSIONS=("v3.0.53" "v3.0.52" "v3.0.51")

for VERSION in "${VERSIONS[@]}"; do
    echo "Probando versión $VERSION"
    
    # Limpiar
    rm -rf darknet
    
    # Instalar versión específica
    DARKNET_VERSION=$VERSION ./install.sh
    
    # Ejecutar pruebas
    # ... tus pruebas aquí ...
    
    echo "Versión $VERSION: OK"
done
```

## Conclusión

Esta estrategia garantiza:
- ✅ **Estabilidad**: Versión fija conocida que funciona
- ✅ **Flexibilidad**: Fácil cambiar versiones si necesario
- ✅ **Transparencia**: Claro qué versión se usa
- ✅ **Recuperación**: Fácil volver a versión estable
- ✅ **Futuro**: Preparado para gestionar actualizaciones