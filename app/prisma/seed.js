/**
 * Seed básico de ejemplo.
 * Ejecuta: npx prisma db seed
 */
const { PrismaClient } = require("@prisma/client");

const prisma = new PrismaClient();

async function main() {
  const email = "admin@example.com";
  const existing = await prisma.user.findUnique({ where: { email } });

  if (!existing) {
    await prisma.user.create({
      data: { email, name: "Admin" }
    });
    console.log("✅ Seed: usuario admin creado:", email);
  } else {
    console.log("ℹ️ Seed: usuario admin ya existía:", email);
  }
}

main()
  .catch((e) => {
    console.error("❌ Seed error:", e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
