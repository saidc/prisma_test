# se usa la imagen oficial de Node.js como imagen base
FROM node:24-alpine

# establece el directorio de trabajo dentro del contenedor
WORKDIR /app

COPY express-api .

COPY package.json package-lock.json ./

RUN npm ci
#RUN npm install

#ENV DATABASE_URL=postgresql://postgres:prisma@localhost:5432/postgres?schema=public

EXPOSE 3000

CMD ["sh", "-c", "npm run db:deploy && npm run dev"]
#CMD ["npm", "run", "dev"]
