require("dotenv").config();

const express = require("express");
const { PrismaClient } = require("./generated/prisma_client/client");
const { PrismaPg } = require("@prisma/adapter-pg");

function requireEnv(name) {
  const v = process.env[name];
  if (!v) {
    throw new Error(`Missing required env var: ${name}`);
  }
  return v;
}

const adapter = new PrismaPg({
  connectionString: requireEnv("DATABASE_URL"),
});

const prisma = new PrismaClient({ adapter });

const app = express();
app.use(express.json());

app.get("/health", async (_req, res) => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    res.json({ ok: true });
  } catch (err) {
    res.status(500).json({ ok: false, error: String(err) });
  }
});

// List users
app.get("/users", async (_req, res) => {
  const users = await prisma.user.findMany({ orderBy: { id: "asc" } });
  res.json(users);
});

// Create user
app.post("/users", async (req, res) => {
  const { email, name } = req.body || {};
  if (!email || typeof email !== "string") {
    return res.status(400).json({ error: "email is required (string)" });
  }
  try {
    const user = await prisma.user.create({
      data: { email, name: typeof name === "string" ? name : null },
    });
    res.status(201).json(user);
  } catch (err) {
    res.status(400).json({ error: String(err) });
  }
});

// Get user by id
app.get("/users/:id", async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isFinite(id)) return res.status(400).json({ error: "id must be a number" });

  const user = await prisma.user.findUnique({ where: { id } });
  if (!user) return res.status(404).json({ error: "not found" });
  res.json(user);
});

// Update user
app.put("/users/:id", async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isFinite(id)) return res.status(400).json({ error: "id must be a number" });

  const { email, name } = req.body || {};
  const data = {};
  if (email !== undefined) {
    if (!email || typeof email !== "string") return res.status(400).json({ error: "email must be a non-empty string" });
    data.email = email;
  }
  if (name !== undefined) {
    if (name === null) data.name = null;
    else if (typeof name === "string") data.name = name;
    else return res.status(400).json({ error: "name must be string or null" });
  }

  try {
    const user = await prisma.user.update({ where: { id }, data });
    res.json(user);
  } catch (err) {
    res.status(400).json({ error: String(err) });
  }
});

// Delete user
app.delete("/users/:id", async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isFinite(id)) return res.status(400).json({ error: "id must be a number" });

  try {
    await prisma.user.delete({ where: { id } });
    res.status(204).send();
  } catch (err) {
    res.status(400).json({ error: String(err) });
  }
});

const PORT = Number(process.env.PORT || 3000);

const server = app.listen(PORT, () => {
  console.log(`API listening on http://localhost:${PORT}`);
});

async function shutdown(signal) {
  console.log(`\nReceived ${signal}. Shutting down...`);
  server.close(() => console.log("HTTP server closed."));
  await prisma.$disconnect();
  process.exit(0);
}

process.on("SIGINT", () => shutdown("SIGINT"));
process.on("SIGTERM", () => shutdown("SIGTERM"));
