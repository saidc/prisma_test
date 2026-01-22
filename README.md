# Node + Express + PostgreSQL + Prisma + Docker Compose (base)

Starter para **desarrollo con Docker Compose** (DB + API + Nginx).

## Requisitos
- Docker + Docker Compose (plugin)

## Estructura
```
.
├─ .env.example
├─ docker-compose.yml
├─ env/
│  └─ .active.env
├─ nginx/
│  └─ templates/
│     └─ default.conf.template
└─ app/
   ├─ Dockerfile
   ├─ package.json
   ├─ prisma/
   │  ├─ schema.prisma
   │  └─ seed.js
   └─ src/
      ├─ app.js
      └─ server.js
```

## 1) Variables de entorno (importante)
Docker Compose **NO** usa `env_file:` para interpolar variables dentro de `docker-compose.yml`.
Para evitar warnings (como los que te salieron) usa **una** opción:

- Opción A (recomendada): crea `.env` en la raíz:
  ```bash
  cp .env.example .env
  ```
- Opción B: ejecuta Compose indicando el archivo:
  ```bash
  docker compose --env-file ./env/.active.env up -d --build
  ```

## 2) Levantar servicios
```bash
# Si usas .env en la raíz
docker compose up -d --build

# O si usas env/.active.env
docker compose --env-file ./env/.active.env up -d --build
```

Logs:
```bash
docker compose logs -f app
```

API:
- vía Nginx: `http://localhost:8080/health`

## 3) Inicializar Prisma (migraciones + generate + seed)
```bash
docker compose exec app sh -lc "npx prisma migrate dev --name init"
docker compose exec app sh -lc "npx prisma generate"
docker compose exec app sh -lc "npx prisma db seed"
```

## 4) Endpoints de prueba
- `GET /health`
- `GET /users`
- `POST /users` con body `{ "email": "x@y.com", "name": "..." }`

## Nota sobre `npm ci`
Este starter usa `npm ci` **si existe** `package-lock.json`. Si no hay lockfile, el Dockerfile cae a `npm install`.
Lo recomendado es **versionar `package-lock.json`** para builds determinísticos.
