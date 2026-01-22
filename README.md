# Prisma + Docker (Node/Express + PostgreSQL)

Proyecto base para:
- API Node.js/Express
- Prisma ORM
- PostgreSQL
- Docker Compose (API + DB + Prisma Studio)

Incluye CRUD completo de `User` y una migración inicial (ver `prisma/migrations`). Al levantar el stack, el contenedor ejecuta:

- `prisma migrate deploy`
- `prisma generate`
- `node index.js`

## Requisitos
- Docker + Docker Compose
- Puertos libres: 3000 (API), 5432 (Postgres), 5555 (Studio)

## 1) Variables de entorno
```bash
cp .env.example .env
```

## 2) Levantar
```bash
python3 manage.py up --build
```

## 3) Probar CRUD

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

## 4) Prisma Studio
```bash
python3 manage.py studio
```

Abrir: `http://localhost:5555`

## 5) Bajar / limpiar
Bajar:
```bash
python3 manage.py down
```

Bajar y borrar datos:
```bash
python3 manage.py down --volumes
```

Reset total:
```bash
python3 manage.py nuke
```
