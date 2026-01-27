
# prisma-docker-basic (Prisma 7 + Docker + Express + Postgres)

Proyecto base para levantar una API en **Node.js/Express** conectada a **PostgreSQL** usando **Prisma ORM** y **Docker Compose**.

Este repo está pensado para:
- Clonar el proyecto
- Crear un `.env` manualmente
- Ejecutar un **bootstrap automatizado** (migraciones + generate + seed)
- Levantar el stack final (API + DB) sin perder la persistencia de la base de datos

---

## 1) Stack y arquitectura

### Componentes
- **PostgreSQL 15** en Docker
- **Express API** en Docker (build con `Dockerfile`)
- **Prisma ORM**:
  - `prisma/schema.prisma` (modelo)
  - `prisma/migrations/*` (historial de migraciones)
  - `prisma/seed.js` (datos iniciales)
  - `prisma.config.ts` (config Prisma 7: datasource url aquí, no en schema)
  - `generated/prisma` (Prisma Client generado)

### Dos Docker Compose (por diseño)
Este repo usa **dos** compose para separar el bootstrap:

1) `docker-compose.postgres.yml`
   - Levanta **solo la base de datos** para poder correr Prisma desde el host (migraciones/seed).

2) `docker-compose.yml`
   - Levanta el **stack final**: Postgres + Express API.
   - Reutiliza el **mismo volumen** de Postgres, por lo que **no se pierde el contenido**.

> Idea clave: el “init compose” crea/actualiza la DB; luego el “final compose” vuelve a levantarla con la API usando el mismo volumen.

---

## 2) Requisitos del sistema

### Requerido (para ejecutar `scripts/setup.sh`)
- Docker + Docker Compose v2
- Node.js + npm (porque el script ejecuta `npx prisma ...` en el host)
- Bash

### Opcional
- `psql` en el host (para depurar manualmente)
- Linux/macOS recomendado (en Windows usar WSL2)

---

## 3) Estructura esperada del repo

Al clonar, el repo debe contener como mínimo (y **solo** esto en la raíz; el script puede advertir si ve extras):

- `express-api/` (código de la API)
- `prisma/` (schema + seed + migrations)
- `scripts/setup.sh`
- `docker-compose.postgres.yml`
- `docker-compose.yml`
- `prisma.config.ts`
- `Dockerfile`
- `package.json`
- `.env` (se crea manualmente)
- (generados por el proceso)
  - `generated/prisma/`
  - `package-lock.json` (si no existe, se crea)
  - `node_modules/` (si instalas dependencias en host)

---

## 4) Configuración: archivo .env

Debes crear `.env` en la raíz.

### DATABASE_URL: regla práctica
- **Dentro de Docker** (API corriendo como contenedor): normalmente se usa host `postgres`
- **En el host** (cuando corres Prisma CLI desde tu máquina): normalmente se usa `localhost`

Ejemplo recomendado para Docker (API contenedor):
```env
DATABASE_URL="postgresql://postgres:prisma@postgres:5432/postgres?schema=public"
````

Ejemplo recomendado para Host (Prisma CLI desde tu máquina):

```env
DATABASE_URL="postgresql://postgres:prisma@localhost:5432/postgres?schema=public"
```

✅ Importante: `scripts/setup.sh` hace un **override automático** para Prisma CLI cuando detecta `@postgres:` y lo cambia a `@localhost:` (solo para los comandos Prisma ejecutados en host).
Así puedes dejar el `.env` con `postgres` para la API, y aún así correr migraciones/seed desde host sin romper nada.

---

## 5) Puertos expuestos

* API: `http://localhost:3000`
* Postgres: `localhost:5432`

---

## 6) Ejecución recomendada

### 6.1 Bootstrap completo (primer uso)

> Este es el flujo típico “recién clonado + .env creado”.

1. Dar permisos:

```bash
chmod +x scripts/setup.sh
```

2. Ejecutar (modo recomendado):

```bash
MIGRATE_MODE=auto ./scripts/setup.sh
```

Este proceso normalmente realiza:

* Preflight (verifica estructura mínima + `.env` con `DATABASE_URL`)
* Instala dependencias (`npm ci` o `npm install`)
* Levanta Postgres con `docker-compose.postgres.yml`
* Ejecuta Prisma:

  * Migraciones (auto: `migrate dev` si no hay migrations, o `migrate deploy` si ya existen)
  * `prisma generate`
  * `prisma db seed`
  * Verificación (`prisma migrate status` + listado de tablas vía `psql` en el contenedor)
* Baja el stack temporal de init DB
* Levanta el stack final con `docker-compose.yml` (API + DB)

Al final revisa:

```bash
docker compose -f docker-compose.yml ps
docker compose -f docker-compose.yml logs -f --tail 200
```

---

### 6.2 Arranque normal (después del bootstrap)

Si ya hiciste bootstrap y solo quieres levantar:

```bash
docker compose -f docker-compose.yml up -d --build
docker compose -f docker-compose.yml logs -f --tail 200
```

---

### 6.3 Apagar servicios

```bash
docker compose -f docker-compose.yml down --remove-orphans
```

---

## 7) Modos de migración (MIGRATE_MODE)

El script soporta:

* `MIGRATE_MODE=auto`

  * Si existen migraciones en `prisma/migrations`: aplica `npx prisma migrate deploy`
  * Si NO existen: crea la inicial con `npx prisma migrate dev --name init`

* `MIGRATE_MODE=deploy` (recomendado para “producción”)

  * Solo aplica migraciones existentes (`migrate deploy`)
  * No debe generar migraciones nuevas

* `MIGRATE_MODE=dev`

  * Fuerza `migrate dev` (no recomendado para producción)

Ejemplos:

```bash
MIGRATE_MODE=auto   ./scripts/setup.sh
MIGRATE_MODE=deploy ./scripts/setup.sh
MIGRATE_MODE=dev    ./scripts/setup.sh
```

---

## 8) “Hard reset” (reconstruir TODO de cero)

Útil si:

* Tuviste un error de inicialización
* Hay drift de Prisma (“database schema is not in sync…”)
* Quedaron volúmenes/estados viejos y quieres reconstruir

⚠️ Esto borra la base de datos persistida (DATA LOSS).

```bash
# baja cualquier stack
docker compose -f docker-compose.postgres.yml down --remove-orphans || true
docker compose -f docker-compose.yml down --remove-orphans || true

# borra el volumen externo (tu DB persistida)
docker volume rm prisma_postgres_data

# crea el volumen de nuevo (si tu setup lo crea, esto es opcional)
docker volume create prisma_postgres_data

# ejecuta bootstrap de nuevo
MIGRATE_MODE=auto ./scripts/setup.sh
```

> Nota: si tu volumen NO se llama `prisma_postgres_data` (depende de tu compose), ajusta el nombre del volumen al que realmente estés usando.

---

## 9) Endpoints (API)

### Health

* `GET /health`

  * [http://localhost:3000/health](http://localhost:3000/health)

### CRUD básico de User (ejemplos cURL)

Crear:

```bash
curl -X POST http://localhost:3000/users \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","name":"Test User"}'
```

Listar:

```bash
curl http://localhost:3000/users
```

Actualizar:

```bash
curl -X PUT http://localhost:3000/users/1 \
  -H "Content-Type: application/json" \
  -d '{"name":"Nuevo Nombre"}'
```

Eliminar:

```bash
curl -X DELETE http://localhost:3000/users/1
```

---

## 10) Prisma Studio (opcional)

Si quieres abrir Prisma Studio desde el host (con DB arriba):

```bash
npx prisma studio --port 5555
```

Luego abre:

* [http://localhost:5555](http://localhost:5555)

---

## 11) Troubleshooting

### 11.1 P1001: Can't reach database server

Casi siempre es por `DATABASE_URL` apuntando a un host incorrecto para el contexto:

* Host: usa `localhost`
* Docker: usa `postgres` (nombre del servicio)

El script intenta corregir esto para Prisma CLI cuando corre en host.

### 11.2 Drift detected / migraciones aplicadas pero faltan localmente

Si ves:

* “migration(s) are applied to the database but missing from the local migrations directory”
* “We need to reset the public schema…”

Solución recomendada:

* Si estás en desarrollo y puedes perder datos: **Hard reset** (sección 8) y vuelve a correr `MIGRATE_MODE=auto`.

### 11.3 Problemas de red Docker (labels / external network)

Si Docker se queja de redes existentes con labels incorrectos (ej. `prisma-network`):

* Baja stacks (`docker compose down`)
* Elimina la red conflictiva si existe
* Evita “name:” o “external:” inconsistentes entre ambos compose (ambos deben coincidir)

---

## 12) Notas Prisma 7

* En Prisma 7.x, `datasource.url` ya no se define en `schema.prisma`.
* La URL de conexión se define en `prisma.config.ts`.

---

## 13) Comandos rápidos

Logs:

```bash
docker compose -f docker-compose.yml logs -f --tail 200
```

Estado:

```bash
docker compose -f docker-compose.yml ps
```

Conexión rápida a DB (si tienes el contenedor arriba):

```bash
docker exec -e PGPASSWORD="prisma" -it postgres psql -U postgres -d postgres
```

