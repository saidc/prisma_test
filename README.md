# prisma-docker-basic (Prisma 7 + Docker + Express + Postgres)

Proyecto base para levantar una API Express con Prisma ORM y PostgreSQL en Docker Compose,
incluyendo Prisma Studio y un CRUD de `User`.

## Requisitos
- Docker + Docker Compose v2
- Python 3 (solo si quieres usar `manage.py`)

## Arranque rápido


1) primer comando 

npx prisma migrate dev --name init --schema=./prisma/schema.prisma


```bash
cp .env.example .env
docker compose up -d --build
docker compose logs -f api
```

Health:
- http://localhost:3000/health

Prisma Studio:
- http://localhost:5555

## CRUD de User (cURL)

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

## Bajar
```bash
docker compose down
```

Borrar datos (volumen):
```bash
docker compose down -v
```

## Notas Prisma 7
- En Prisma 7.3, `datasource.url` ya **no** se define en `schema.prisma`.
- La URL de conexión se define en `prisma.config.ts` (datasource.url).
