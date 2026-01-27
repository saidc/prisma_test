#!/usr/bin/env bash
set -euo pipefail

# -----------------------------
# Configuración
# -----------------------------
# Carpeta base del "app" dentro del repo (por defecto: app)
# Puedes ejecutar así:
#   APP_DIR=app MIGRATE_MODE=auto ./scripts/setup.sh
APP_DIR="${APP_DIR:-app}"

MIGRATE_MODE="${MIGRATE_MODE:-auto}"     # auto | dev | deploy
STRICT_FILES="${STRICT_FILES:-0}"        # 1 = falla si hay archivos/carpetas inesperadas en la raíz
KEEP_INIT_DB_UP="${KEEP_INIT_DB_UP:-0}"  # 1 = no hace down del compose postgres al terminar (no recomendado)
POSTGRES_SERVICE="${POSTGRES_SERVICE:-postgres}"

# Nombre del volumen de Postgres (fallback).
# Si docker-compose.postgres.yml define un volumen external con name:, el script intentará detectarlo y usar ese.
POSTGRES_VOLUME="${POSTGRES_VOLUME:-prisma_postgres_data}"

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
log "APP_DIR=$APP_DIR"

APP_PATH="$ROOT_DIR/$APP_DIR"
PRISMA_CONFIG_PATH="$APP_PATH/prisma.config.ts"

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
req_paths=(
  "$APP_DIR/prisma/schema.prisma"
  "$APP_DIR/prisma.config.ts"
  "$APP_DIR/prisma/seed.js"
  "$APP_DIR/package.json"
  "$APP_DIR/Dockerfile"
  "$APP_DIR/src"
  "$APP_DIR/prisma"
  "docker-compose.postgres.yml"
  "docker-compose.yml"
  "scripts/setup.sh"
  ".env"
)

for p in "${req_paths[@]}"; do
  [[ -e "$p" ]] || die "Falta '$p'. Verifica que el repo fue clonado completo y que agregaste .env."
done

# Validar que .env tenga DATABASE_URL
if ! grep -qE '^[[:space:]]*DATABASE_URL=' ".env"; then
  die "Tu .env no contiene DATABASE_URL=. Prisma lo necesita para migrar/seed."
fi

# Leer DATABASE_URL desde .env (sin comillas)
DATABASE_URL_FROM_ENVFILE="$(
  grep -E '^[[:space:]]*DATABASE_URL=' .env | tail -n1 | cut -d= -f2- | tr -d '"' | tr -d "'"
)"
DATABASE_URL_FOR_CLI="$DATABASE_URL_FROM_ENVFILE"

# Si el .env usa host 'postgres', eso solo sirve dentro de Docker; en el host usamos localhost.
if echo "$DATABASE_URL_FROM_ENVFILE" | grep -q '@postgres:'; then
  warn "DATABASE_URL apunta a host 'postgres'. Eso es correcto dentro de Docker, pero en el host normalmente debe ser 'localhost'."
  warn "Haré override SOLO para Prisma CLI (host): @postgres: -> @localhost:"
  DATABASE_URL_FOR_CLI="${DATABASE_URL_FROM_ENVFILE/@postgres:/@localhost:}"
fi

export DATABASE_URL="$DATABASE_URL_FOR_CLI"
log "DATABASE_URL (CLI/host) = $DATABASE_URL"

# Control opcional de “archivos inesperados” en la raíz (sin escanear todo el árbol)
allowed_root_regex="^(${APP_DIR}|scripts|docker-compose\.yml|docker-compose\.postgres\.yml|docker-compose\.docker\.yml|\.env|README\.md|LICENSE|\.gitignore|\.gitattributes|\.git)$"
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
# Paso 1: instalar dependencias Node (dentro de APP_DIR)
# -----------------------------
log "Instalando dependencias Node en '$APP_DIR'..."
pushd "$APP_PATH" >/dev/null
if [[ -f "package-lock.json" ]]; then
  npm ci
else
  npm install
fi
popd >/dev/null

# -----------------------------
# Paso 2: asegurar volumen externo (si tu compose lo define como external)
# -----------------------------
DB_VOLUME_NAME="$POSTGRES_VOLUME"

if grep -qE 'external:[[:space:]]*true' docker-compose.postgres.yml; then
  detected_vol_name="$(
    awk '
      BEGIN{invol=0}
      /^volumes:/ {invol=1; next}
      invol && /^[^[:space:]]/ {invol=0}
      invol && $1=="name:" {print $2; exit}
    ' docker-compose.postgres.yml
  )"
  if [[ -n "${detected_vol_name:-}" ]]; then
    DB_VOLUME_NAME="$detected_vol_name"
    if ! docker volume inspect "$DB_VOLUME_NAME" >/dev/null 2>&1; then
      log "Creando volumen externo '$DB_VOLUME_NAME'..."
      docker volume create "$DB_VOLUME_NAME" >/dev/null
    else
      log "Volumen externo '$DB_VOLUME_NAME' ya existe."
    fi
  else
    warn "docker-compose.postgres.yml marca external: true pero no se detectó 'name:'. Usaré POSTGRES_VOLUME='$POSTGRES_VOLUME'."
  fi
else
  log "No se detectó volumen external en docker-compose.postgres.yml. Usaré POSTGRES_VOLUME='$POSTGRES_VOLUME' como nombre para reset en modo auto."
fi

# -----------------------------
# Paso 3: bajar stacks previos (sin volúmenes)
# -----------------------------
log "Bajando stacks previos (sin borrar volúmenes)..."
docker compose -f docker-compose.yml down --remove-orphans >/dev/null 2>&1 || true
docker compose -f docker-compose.postgres.yml down --remove-orphans >/dev/null 2>&1 || true

# -----------------------------
# Utilidad: esperar Postgres
# -----------------------------
wait_for_postgres() {
  local compose_file="$1"
  local service="$2"

  local cid
  cid="$(docker compose -f "$compose_file" ps -q "$service")"
  [[ -n "$cid" ]] || die "No se pudo obtener container id del servicio '$service' (compose: $compose_file)."

  log "Esperando a que Postgres esté listo (pg_isready dentro del contenedor)..."
  local ready=0
  for i in {1..60}; do
    if docker exec "$cid" pg_isready -U postgres -d postgres >/dev/null 2>&1; then
      ready=1
      break
    fi
    sleep 2
  done

  if [[ "$ready" != "1" ]]; then
    docker logs --tail 200 "$cid" || true
    die "Postgres no quedó listo a tiempo. Revisa logs arriba (y tu healthcheck/credenciales)."
  fi

  printf "%s" "$cid"
}

# -----------------------------
# Paso 4: levantar Postgres (init)
# -----------------------------
log "Levantando Postgres (init) con docker-compose.postgres.yml..."
docker compose -f docker-compose.postgres.yml up -d "$POSTGRES_SERVICE"
DB_CID="$(wait_for_postgres docker-compose.postgres.yml "$POSTGRES_SERVICE")"

# -----------------------------
# Paso 5: migración (auto/dev/deploy)
# -----------------------------
has_migrations=0
if [[ -d "$APP_PATH/prisma/migrations" ]] && find "$APP_PATH/prisma/migrations" -mindepth 1 -maxdepth 1 -type d | grep -q .; then
  has_migrations=1
fi

log "Estrategia de migración: MIGRATE_MODE=$MIGRATE_MODE, has_migrations=$has_migrations"
log "Usando Prisma config: $PRISMA_CONFIG_PATH"

run_prisma() {
  # Ejecuta Prisma usando las dependencias instaladas en APP_DIR
  pushd "$APP_PATH" >/dev/null
  npx prisma "$@" --config "$PRISMA_CONFIG_PATH"
  popd >/dev/null
}

case "$MIGRATE_MODE" in
  auto)
    # ---------------------------------------------------------
    # RESET TOTAL (si o si en auto): reconstruir todo desde cero
    # ---------------------------------------------------------
    log "MIGRATE_MODE=auto => reset total de stacks + volumen DB '$DB_VOLUME_NAME'."

    # baja cualquier stack
    docker compose -f docker-compose.postgres.yml down --remove-orphans || true
    docker compose -f docker-compose.yml down --remove-orphans || true

    # borra el volumen externo (tu DB persistida)
    docker volume rm "$DB_VOLUME_NAME" || true

    # crea el volumen de nuevo (si tu setup lo crea, esto es opcional)
    docker volume create "$DB_VOLUME_NAME" >/dev/null 2>&1 || true

    # Re-levantar Postgres (init) después del reset y esperar readiness
    log "Levantando Postgres (init) tras reset total..."
    docker compose -f docker-compose.postgres.yml up -d "$POSTGRES_SERVICE"
    DB_CID="$(wait_for_postgres docker-compose.postgres.yml "$POSTGRES_SERVICE")"

    if [[ "$has_migrations" == "1" ]]; then
      log "Aplicando migraciones existentes: prisma migrate deploy"
      run_prisma migrate deploy
    else
      log "Creando y aplicando migración inicial: prisma migrate dev --name init"
      run_prisma migrate dev --name init
    fi
    ;;
  dev)
    log "Forzando migrate dev (no recomendado para producción): prisma migrate dev --name init"
    run_prisma migrate dev --name init
    ;;
  deploy)
    log "Forzando migrate deploy (recomendado para producción): prisma migrate deploy"
    run_prisma migrate deploy
    ;;
  *)
    die "MIGRATE_MODE inválido: $MIGRATE_MODE (usa auto|dev|deploy)"
    ;;
esac

# -----------------------------
# Paso 6: generate
# -----------------------------
log "Generando cliente Prisma: prisma generate"
run_prisma generate

# -----------------------------
# Paso 7: seed
# -----------------------------
pushd "$APP_PATH" >/dev/null
if grep -qE '"seed"[[:space:]]*:' package.json; then
  log "Ejecutando seed: prisma db seed"
  npx prisma db seed --config "$PRISMA_CONFIG_PATH"
else
  warn "No se detectó configuración de seed en package.json (sección prisma.seed)."
  warn "Fallback: ejecutando node prisma/seed.js (ajusta package.json según docs para producción)."
  node prisma/seed.js
fi
popd >/dev/null

# -----------------------------
# Paso 8: verificación de migración/tablas
# -----------------------------
log "Verificando estado de migraciones: prisma migrate status"
run_prisma migrate status || true

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
