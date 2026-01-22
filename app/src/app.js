require("dotenv").config();

const express = require("express");
require("express-async-errors");
const cors = require("cors");
const helmet = require("helmet");
const pinoHttp = require("pino-http");
const { z } = require("zod");
const { PrismaClient } = require("@prisma/client");

const prisma = new PrismaClient();
const app = express();

app.use(pinoHttp());
app.use(helmet());
app.use(cors());
app.use(express.json({ limit: "1mb" }));

app.get("/health", (req, res) => {
  res.json({ ok: true, ts: new Date().toISOString() });
});

app.get("/users", async (req, res) => {
  const users = await prisma.user.findMany({ orderBy: { createdAt: "desc" } });
  res.json(users);
});

app.post("/users", async (req, res) => {
  const schema = z.object({
    email: z.string().email(),
    name: z.string().min(1).optional()
  });

  const data = schema.parse(req.body);
  const user = await prisma.user.create({ data });
  res.status(201).json(user);
});

// Manejo de errores
app.use((err, req, res, next) => {
  req.log?.error({ err }, "Unhandled error");
  const status = err?.statusCode || 500;
  res.status(status).json({
    error: true,
    message: status === 500 ? "Internal Server Error" : err.message
  });
});

module.exports = { app, prisma };
