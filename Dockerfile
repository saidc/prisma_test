FROM node:22-alpine

RUN apk add --no-cache openssl

WORKDIR /usr/src/app

COPY package.json ./
RUN npm install

COPY . .

EXPOSE 3000

CMD ["sh", "-c", "npm run db:deploy && npm run start"]
