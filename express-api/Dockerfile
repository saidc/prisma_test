# se usa la imagen oficial de Node.js como imagen base
FROM node:24-alpine

# establece el directorio de trabajo dentro del contenedor
WORKDIR /app

# Copia primero manifest para cacheo de dependencias
COPY package.json ../package-lock.json ./

# Copia prisma + config (necesarios para migraciones)
COPY prisma.config.ts ./
COPY prisma ./prisma

COPY .env ./

# Copia el resto del código de la aplicación
COPY express-api ./

COPY generated ./generated


RUN npm ci
#RUN npm install

#ENV DATABASE_URL=postgresql://postgres:prisma@localhost:5432/postgres?schema=public

EXPOSE 3000

#CMD ["sh", "-c", "npm run db:deploy && npm run dev"]
#CMD ["sh", "-c", "npm run db:bootstrap && npm run dev"]
CMD ["sh", "-c", "npm run db:deploy && if [ \"$RUN_SEED\" = \"true\" ]; then npx prisma db seed; fi && npm run dev"]
