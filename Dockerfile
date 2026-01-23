FROM node:22-alpine

# Commonly needed by Node + crypto/TLS libs in Alpine environments
RUN apk add --no-cache openssl

WORKDIR /usr/src/app

COPY package.json ./
RUN npm install

COPY . .

EXPOSE 3000

# Run migrations (deploy) + generate, then start API
CMD ["sh", "-lc", "npm run db:deploy && npm run start"]
