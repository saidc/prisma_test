# se usa la imagen oficial de Node.js como imagen base
FROM node:24-alpine

# establece el directorio de trabajo dentro del contenedor
WORKDIR /app

COPY express-api .
# COPY package*.json ./

RUN npm install

# copia el archivo package.json al directorio de trabajo
#RUN if [ ! -f package.json ]; then npm init -y; fi

# instala las dependencias necesarias
#RUN npm install express express-session http-errors
# instala dependencias adicionales
#RUN npm install ejs dotenv cookie-parser bcrypt morgan pg
# instala Prisma y el cliente de Prisma
#RUN npm install prisma @prisma/client

ENV DATABASE_URL=postgres://usuario:minafro123@postgresdb:5432/bd_minafro
# expone el puerto 3000 para que pueda ser accedido desde fuera del contenedor
EXPOSE 3000

# comando para iniciar la aplicación
CMD ["npm", "run", "dev"]
#CMD ["node", "index.js"]
#CMD ["node", "app/index.js"]  

