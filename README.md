# Node + Express + PostgreSQL + Prisma + Docker Compose (base)

Este starter está pensado para **desarrollo local con Docker Compose** y listo para evolucionar a producción.

## Requisitos
- Docker + Docker Compose (plugin)
- (Opcional) Node.js local si quieres ejecutar comandos sin entrar al contenedor

## Estructura
```
.
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

## 1) Configurar variables de entorno
Copia y ajusta el archivo:

- `env/.active.env` (ya viene un ejemplo)

> **Nota Prisma 7+:** `migrate dev` ya no ejecuta `generate` ni `seed` automáticamente; se ejecutan explícitamente con los comandos indicados abajo. (ver docs oficiales del CLI)  

## 2) Levantar servicios (DB + API)
```bash
docker compose up -d --build
```

Ver logs:
```bash
docker compose logs -f app
```

La API quedará en: `http://localhost:8080` (por Nginx) o `http://localhost:3000` si expones el puerto del app.

## 3) Inicializar Prisma (migraciones + generate + seed)
Ejecuta dentro del servicio `app`:

```bash
# 3.1 crear/aplicar migración inicial (DEV)
docker compose exec app sh -lc "npx prisma migrate dev --name init"

# 3.2 generar Prisma Client (DEV/PROD)
docker compose exec app sh -lc "npx prisma generate"

# 3.3 seed (opcional)
docker compose exec app sh -lc "npx prisma db seed"
```

### Reset completo (DEV)
```bash
docker compose exec app sh -lc "npx prisma migrate reset"
```

## 4) Endpoints de prueba
- `GET /health`  -> healthcheck simple
- `GET /users`   -> lista usuarios
- `POST /users`  -> crea usuario `{ "email": "...", "name": "..." }`

## 5) Parar y limpiar
```bash
docker compose down
```

Borrar volumen de DB (⚠️ elimina datos):
```bash
docker compose down -v
```

## Producción (idea rápida)
- Construir con target `prod`
- Usar `prisma migrate deploy` en el arranque (o job aparte)
- Configurar TLS/Certbot en Nginx según tu infraestructura
