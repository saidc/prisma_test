# se usa la imagen oficial de Node.js como imagen base
FROM node:23-alpine

# establece el directorio de trabajo dentro del contenedor
WORKDIR /app

# copia el archivo package.json al directorio de trabajo
RUN if [ ! -f package.json ]; then npm init -y; fi

# instala las dependencias necesarias
RUN npm install express express-session http-errors
# instala dependencias adicionales
RUN npm install ejs dotenv cookie-parser bcrypt morgan pg
# instala Prisma y el cliente de Prisma
RUN npm install prisma @prisma/client

# copia el resto de los archivos de la aplicación al directorio de trabajo
COPY . .