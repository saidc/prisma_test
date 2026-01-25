#!/bin/bash

# 1. Verificar y borrar carpeta 'generated'
if [ -d "generated" ]; then
    echo "Eliminando carpeta 'generated' existente..."
    sudo rm -rf generated
fi

# 2. Verificar carpeta 'prisma' y archivo 'prisma.config.ts'
if [ -d "prisma" ] && [ -f "prisma.config.ts" ]; then
    echo "Carpeta prisma y configuración encontradas."
    
    # 2.2 Verificar y borrar 'prisma/migrations'
    if [ -d "prisma/migrations" ]; then
        echo "Eliminando migraciones antiguas..."
        sudo rm -rf prisma/migrations
    fi
else
    echo "Error: No se encontró la carpeta 'prisma' o el archivo 'prisma.config.ts'."
    echo "Por favor, clone el proyecto de nuevo de GitHub."
    exit 1
fi

# 3. Verificar package.json y ejecutar npm install
if [ -f "package.json" ]; then
    echo "Instalando dependencias de Node..."
    npm install
else
    echo "Archivo package.json no encontrado. Saltando instalación."
fi

# 4. Verificar docker-compose.postgres.yml y gestionar contenedores
if [ -f "docker-compose.postgres.yml" ]; then
    # 4.1 Inicializar prisma
    echo "Inicializando Prisma..."
    npx prisma init --output ../generated/prisma

    # 4.2 Limpiar instancias previas de Docker
    # Verifica si hay contenedores, volúmenes o huérfanos activos
    if [ $(docker compose ps -a -q | wc -l) -gt 0 ]; then
        echo "Limpiando contenedores y volúmenes existentes..."
        docker compose down -v --remove-orphans
    fi

    # 4.3 Levantar base de datos
    echo "Levantando base de datos Postgres..."
    docker compose -f docker-compose.postgres.yml up -d
    
    # Espera un momento para asegurar que el motor de la DB esté listo
    sleep 5
fi

# 5. Ejecutar migración de Prisma
echo "Ejecutando migración inicial..."
npx prisma migrate dev --name init

# 6. Generar cliente de Prisma
echo "Generando cliente Prisma..."
npx prisma generate

# 7. Detener servicios de base de datos temporales
echo "Deteniendo servicios temporales..."
docker compose -f docker-compose.postgres.yml down --remove-orphans

# 8. Verificar docker-compose.yml y levantar servicios finales
if [ -f "docker-compose.yml" ]; then
    echo "Levantando infraestructura final con Build..."
    docker compose -f docker-compose.yml up --build -d
else
    echo "Aviso: docker-compose.yml no encontrado para la fase final."
fi

echo "Proceso finalizado exitosamente."
