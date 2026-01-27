#!/usr/bin/env bash
set -euo pipefail

# -----------------------------
# Configuración
# -----------------------------
MIGRATE_MODE="${MIGRATE_MODE:-auto}"   # auto | dev | deploy
STRICT_FILES="${STRICT_FILES:-0}"      # 1 = falla si hay archivos/carpetas inesperadas en la raíz
KEEP_INIT_DB_UP="${KEEP_INIT_DB_UP:-0}" # 1 = no hace down del compose postgres al terminar (no recomendado)
POSTGRES_SERVICE="${POSTGRES_SERVICE:-postgres}"

# -----------------------------
# Utilidades
# -----------------------------
log()  { printf "[setup] %s\n" "$*"; }
warn() { printf "[setup][WARN] %s\n" "$*" >&2; }
die()  { printf "[setup][ERROR] %s\n" "$*" >&2; exit 1; }

# Ir a la raíz del repo (asumiendo scripts/setup.sh)
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

log "ROOT_DIR=$ROOT_DIR"

# -----------------------------
# Preflight: comandos requeridos
# -----------------------------
command -v docker >/dev/null 2>&1 || die "docker no está instalado o no está en PATH."
docker compose version >/dev/null 2>&1 || die "docker compose no está disponible (plugin v2)."
command -v node >/dev/null 2>&1 || die "node no está instalado o no está en PATH."
command -v npm  >/dev/null 2>&1 || die "npm no está instalado o no está en PATH."

# -----------------------------
# Preflight: estructura mínima del repo
# -----------------------------
# Requeridos (según tu descripción)
req_paths=(
  "express-api"
  "prisma"
  "prisma/schema.prisma"
  "prisma/seed.js"
  "scripts/setup.sh"
  "docker-compose.postgres.yml"
  "docker-compose.yml"
  "prisma.config.ts"
  "Dockerfile"
  "package.json"
  ".env"
)

for p in "${req_paths[@]}"; do
  [[ -e "$p" ]] || die "Falta '$p'. Verifica que el repo fue clonado completo y que agregaste .env."
done

# Validar que .env tenga DATABASE_URL
if ! grep -qE '^[[:space:]]*DATABASE_URL=' ".env"; then
  die "Tu .env no contiene DATABASE_URL=. Prisma lo necesita para migrar/seed."
fi

# Advertencia típica: si DATABASE_URL usa host 'postgres' pero estás ejecutando en host,
# lo usual es usar localhost porque el puerto 5432 está publicado por docker compose.
DATABASE_URL="$(grep -E '^[[:space:]]*DATABASE_URL=' .env | tail -n1 | cut -d= -f2- | tr -d '"' | tr -d "'")"
if echo "$DATABASE_URL" | grep -q '@postgres:'; then
  warn "DATABASE_URL apunta a host 'postgres'. Si ejecutas este script en el host, normalmente debe ser 'localhost'."
  warn "Ejemplo recomendado (host): postgresql://postgres:prisma@localhost:5432/postgres?schema=public"
fi

# ---- Override DATABASE_URL solo para Prisma CLI cuando corremos en el HOST ----
DATABASE_URL_FROM_ENVFILE="$(grep -E '^[[:space:]]*DATABASE_URL=' .env | tail -n1 | cut -d= -f2- | tr -d '"' | tr -d "'")"
DATABASE_URL_FOR_CLI="$DATABASE_URL_FROM_ENVFILE"

# Si el .env usa host 'postgres', eso solo sirve dentro de Docker; en el host usamos localhost.
if echo "$DATABASE_URL_FROM_ENVFILE" | grep -q '@postgres:'; then
  DATABASE_URL_FOR_CLI="${DATABASE_URL_FROM_ENVFILE/@postgres:/@localhost:}"
  log "Override para Prisma CLI (host): DATABASE_URL => $DATABASE_URL_FOR_CLI"
fi

export DATABASE_URL="$DATABASE_URL_FOR_CLI"
# ---------------------------------------------------------------------------

# Control opcional de “archivos inesperados” en la raíz (sin escanear todo el árbol)
allowed_root_regex='^(express-api|prisma|scripts|docker-compose\.yml|docker-compose\.postgres\.yml|docker-compose\.docker\.yml|prisma\.config\.ts|Dockerfile|package\.json|package-lock\.json|generated|node_modules|\.env|README\.md|LICENSE|\.gitignore|\.gitattributes|\.git)$'
unexpected=()
while IFS= read -r item; do
  if ! [[ "$item" =~ $allowed_root_regex ]]; then
    unexpected+=("$item")
  fi
done < <(find . -maxdepth 1 -mindepth 1 -printf '%f\n' | sort)

if ((${#unexpected[@]} > 0)); then
  msg="Elementos inesperados en la raíz: ${unexpected[*]}"
  if [[ "$STRICT_FILES" == "1" ]]; then
    die "$msg"
  else
    warn "$msg"
  fi
fi

# -----------------------------
# Paso 1: instalar dependencias Node
# -----------------------------
log "Instalando dependencias Node..."
if [[ -f "package-lock.json" ]]; then
  npm ci
else
  npm install
fi

# -----------------------------
# Paso 2: asegurar volumen externo (si tu compose lo define como external)
# -----------------------------
# Si docker-compose.postgres.yml tiene external: true y un name:, intentamos crear el volumen si no existe.
if grep -qE 'external:[[:space:]]*true' docker-compose.postgres.yml; then
  vol_name="$(
    awk '
      BEGIN{invol=0}
      /^volumes:/ {invol=1; next}
      invol && /^[^[:space:]]/ {invol=0}
      invol && $1=="name:" {print $2; exit}
    ' docker-compose.postgres.yml
  )"
  if [[ -n "${vol_name:-}" ]]; then
    if ! docker volume inspect "$vol_name" >/dev/null 2>&1; then
      log "Creando volumen externo '$vol_name'..."
      docker volume create "$vol_name" >/dev/null
    else
      log "Volumen externo '$vol_name' ya existe."
    fi
  else
    warn "docker-compose.postgres.yml marca external: true pero no se detectó 'name:'."
  fi
fi

# -----------------------------
# Paso 3: bajar stacks previos (sin volúmenes)
# -----------------------------
log "Bajando stacks previos (sin borrar volúmenes)..."
docker compose -f docker-compose.yml down --remove-orphans >/dev/null 2>&1 || true
docker compose -f docker-compose.postgres.yml down --remove-orphans >/dev/null 2>&1 || true

# -----------------------------
# Paso 4: levantar Postgres (init)
# -----------------------------
log "Levantando Postgres (init) con docker-compose.postgres.yml..."
docker compose -f docker-compose.postgres.yml up -d "$POSTGRES_SERVICE"

DB_CID="$(docker compose -f docker-compose.postgres.yml ps -q "$POSTGRES_SERVICE")"
[[ -n "$DB_CID" ]] || die "No se pudo obtener container id del servicio '$POSTGRES_SERVICE'."

log "Esperando a que Postgres esté listo (pg_isready dentro del contenedor)..."
ready=0
for i in {1..60}; do
  if docker exec "$DB_CID" pg_isready -U postgres -d postgres >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 2
done

if [[ "$ready" != "1" ]]; then
  docker logs --tail 200 "$DB_CID" || true
  die "Postgres no quedó listo a tiempo. Revisa logs arriba (y tu healthcheck/credenciales)."
fi

# -----------------------------
# Paso 5: migración (auto/dev/deploy)
# -----------------------------
has_migrations=0
if [[ -d "prisma/migrations" ]] && find "prisma/migrations" -mindepth 1 -maxdepth 1 -type d | grep -q .; then
  has_migrations=1
fi

log "Estrategia de migración: MIGRATE_MODE=$MIGRATE_MODE, has_migrations=$has_migrations"

case "$MIGRATE_MODE" in
  auto)
    # ---------------------------------------------------------
    # RESET TOTAL (si o si en auto): reconstruir todo desde cero
    # ---------------------------------------------------------

    # baja cualquier stack
    docker compose -f docker-compose.postgres.yml down --remove-orphans || true
    docker compose -f docker-compose.yml down --remove-orphans || true

    # borra el volumen externo (tu DB persistida)
    docker volume rm prisma_postgres_data || true

    # crea el volumen de nuevo (si tu setup lo crea, esto es opcional)
    docker volume create prisma_postgres_data >/dev/null 2>&1 || true

    # Re-levantar Postgres (init) después del reset y esperar readiness
    log "Levantando Postgres (init) tras reset total..."
    docker compose -f docker-compose.postgres.yml up -d "$POSTGRES_SERVICE"

    DB_CID="$(docker compose -f docker-compose.postgres.yml ps -q "$POSTGRES_SERVICE")"
    [[ -n "$DB_CID" ]] || die "No se pudo obtener container id del servicio '$POSTGRES_SERVICE' tras reset."

    log "Esperando a que Postgres esté listo (pg_isready) tras reset..."
    ready=0
    for i in {1..60}; do
      if docker exec "$DB_CID" pg_isready -U postgres -d postgres >/dev/null 2>&1; then
        ready=1
        break
      fi
      sleep 2
    done

    if [[ "$ready" != "1" ]]; then
      docker logs --tail 200 "$DB_CID" || true
      die "Postgres no quedó listo a tiempo tras reset. Revisa logs arriba (y tu healthcheck/credenciales)."
    fi

    if [[ "$has_migrations" == "1" ]]; then
      log "Aplicando migraciones existentes: npx prisma migrate deploy"
      npx prisma migrate deploy
    else
      log "Creando y aplicando migración inicial: npx prisma migrate dev --name init"
      npx prisma migrate dev --name init
    fi
    ;;
  dev)
    log "Forzando migrate dev (no recomendado para producción): npx prisma migrate dev --name init"
    npx prisma migrate dev --name init
    ;;
  deploy)
    log "Forzando migrate deploy (recomendado para producción): npx prisma migrate deploy"
    npx prisma migrate deploy
    ;;
  *)
    die "MIGRATE_MODE inválido: $MIGRATE_MODE (usa auto|dev|deploy)"
    ;;
esac

# -----------------------------
# Paso 6: generate
# -----------------------------
log "Generando cliente Prisma: npx prisma generate"
npx prisma generate

# -----------------------------
# Paso 7: seed
# -----------------------------
# Prisma recomienda configurar el seed en package.json para que prisma db seed sepa qué ejecutar.
# Verifica y da fallback si hace falta.
if grep -qE '"seed"[[:space:]]*:' package.json; then
  log "Ejecutando seed: npx prisma db seed"
  npx prisma db seed
else
  warn "No se detectó configuración de seed en package.json (sección prisma.seed)."
  warn "Fallback: ejecutando node prisma/seed.js (ajusta package.json según docs para producción)."
  node prisma/seed.js
fi

# -----------------------------
# Paso 8: verificación de migración/tablas
# -----------------------------
log "Verificando estado de migraciones: npx prisma migrate status"
npx prisma migrate status || true

log "Listando tablas en Postgres (psql dentro del contenedor)..."
docker exec -e PGPASSWORD="prisma" "$DB_CID" psql -U postgres -d postgres -c "\dt" || true

# -----------------------------
# Paso 9: bajar init DB (sin volumen) y levantar stack final
# -----------------------------
if [[ "$KEEP_INIT_DB_UP" != "1" ]]; then
  log "Bajando stack temporal (sin borrar volúmenes)..."
  docker compose -f docker-compose.postgres.yml down --remove-orphans
else
  warn "KEEP_INIT_DB_UP=1: dejando Postgres init arriba. (Ojo con conflictos de container_name si levantas el stack final)."
fi

log "Levantando stack final con docker-compose.yml..."
docker compose -f docker-compose.yml up -d --build

log "Listo. Revisa estado:"
log "  docker compose -f docker-compose.yml ps"
log "  docker compose -f docker-compose.yml logs -f --tail 200"
