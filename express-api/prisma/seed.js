/**
 * Prisma Seed Script – Full (Schema-Aligned, bcrypt)
 * --------------------------------------------------
 * Seeds:
 *  - Users
 *
 * Run:
 *   npx prisma db seed
 */
import "dotenv/config";
import { PrismaClient } from "@prisma/client";
import { PrismaPg } from "@prisma/adapter-pg";
import bcrypt from "bcryptjs";

// --------------------------------------------------
// Environment validation
// --------------------------------------------------
if (!process.env.DATABASE_URL) {
  throw new Error("❌ DATABASE_URL is not defined");
}

// --------------------------------------------------
// Prisma Client (adapter required for Prisma v7)
// --------------------------------------------------
const adapter = new PrismaPg({
  connectionString: process.env.DATABASE_URL,
});

const prisma = new PrismaClient({ adapter });

// --------------------------------------------------
// Password hashing helper (bcrypt)
// --------------------------------------------------
const SALT_ROUNDS = 10;

async function hashPassword(password) {
  return bcrypt.hash(password, SALT_ROUNDS);
}

async function main() {
  console.log("🌱 Starting database seed...\n");

  // ===================== USERS =====================
  console.log("👥 Seeding users...");

  const alice = await prisma.user.upsert({
    where: { email: "alice@example.com" },
    update: {},
    create: {
      username: "alice",
      email: "alice@example.com",
      passwordHash: await hashPassword("password123"),
      displayName: "Alice Smith",
      status: "active",
    },
  });

  const bob = await prisma.user.upsert({
    where: { email: "bob@example.com" },
    update: {},
    create: {
      username: "bob",
      email: "bob@example.com",
      passwordHash: await hashPassword("password123"),
      displayName: "Bob Johnson",
      status: "active",
    },
  });

  const charlie = await prisma.user.upsert({
    where: { email: "charlie@example.com" },
    update: {},
    create: {
      username: "charlie",
      email: "charlie@example.com",
      passwordHash: await hashPassword("password123"),
      displayName: "Charlie Brown",
      status: "active",
    },
  });

  const diana = await prisma.user.upsert({
    where: { email: "diana@example.com" },
    update: {},
    create: {
      username: "diana",
      email: "diana@example.com",
      passwordHash: await hashPassword("password123"),
      displayName: "Diana Prince",
      status: "active",
    },
  });

  console.log("  ✅ Users created\n");

  // ===================== SUMMARY =====================
  const stats = {
    users: await prisma.user.count()
  };

  console.log("📊 Database Summary:");
  console.log(stats);

  console.log("\n🌱 Seed completed successfully");
}


// --------------------------------------------------
// Execute
// --------------------------------------------------
main()
  .catch((error) => {
    console.error("❌ Seeding failed");
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
    console.log("🔌 Prisma disconnected");
  });