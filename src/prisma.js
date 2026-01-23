const { Pool } = require('pg');
const { PrismaPg } = require('@prisma/adapter-pg');

// Prisma 7: el cliente puede generarse como "paquete" en la carpeta output
// o como subpath ".../client" dependiendo de la versión/configuración.
// Para evitar errores por mismatch de ruta, resolvemos ambas.
function safeRequire(path) {
  try {
    return require(path);
  } catch (e) {
    const isMissing =
      e &&
      e.code === 'MODULE_NOT_FOUND' &&
      typeof e.message === 'string' &&
      e.message.includes(path);

    if (isMissing) return null;
    throw e;
  }
}

const prismaPkg =
  safeRequire('../generated/prisma_client/client') ||
  safeRequire('../generated/prisma_client');

if (!prismaPkg || typeof prismaPkg.PrismaClient !== 'function') {
  throw new Error(
    "PrismaClient no encontrado. Verifica la salida de `npx prisma generate` y la ruta importada en src/prisma.js."
  );
}

const { PrismaClient } = prismaPkg;

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

module.exports = { prisma, pool };
