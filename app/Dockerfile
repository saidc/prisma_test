# syntax=docker/dockerfile:1

FROM node:24-alpine AS base
WORKDIR /app
# Paquetes útiles para algunas dependencias nativas (si las llegas a usar)
RUN apk add --no-cache libc6-compat

# ---- deps ----
FROM base AS deps
COPY package*.json ./
RUN npm ci

# ---- dev ----
FROM base AS dev
ENV NODE_ENV=development
COPY --from=deps /app/node_modules ./node_modules
COPY . .
EXPOSE 3000
CMD ["npm", "run", "dev"]

# ---- prod ----
FROM base AS prod
ENV NODE_ENV=production
COPY --from=deps /app/node_modules ./node_modules
COPY . .
# Prisma Client se genera en build (puedes moverlo a pipeline CI/CD)
RUN npx prisma generate
EXPOSE 3000
CMD ["npm", "start"]
