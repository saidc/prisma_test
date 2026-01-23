const express = require('express');
const prisma = require('./prisma');

const app = express();
app.use(express.json());

app.get('/health', (_req, res) => res.json({ ok: true }));

// List users
app.get('/users', async (_req, res) => {
  const users = await prisma.user.findMany({ orderBy: { id: 'asc' } });
  res.json(users);
});

// Create user
app.post('/users', async (req, res) => {
  const { email, name } = req.body || {};
  if (!email) return res.status(400).json({ error: 'email is required' });

  try {
    const user = await prisma.user.create({ data: { email, name } });
    res.status(201).json(user);
  } catch (err) {
    // Unique constraint on email
    if (err && err.code === 'P2002') {
      return res.status(409).json({ error: 'email already exists' });
    }
    console.error(err);
    res.status(500).json({ error: 'internal error' });
  }
});

// Get user by id
app.get('/users/:id', async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isFinite(id)) return res.status(400).json({ error: 'invalid id' });

  const user = await prisma.user.findUnique({ where: { id } });
  if (!user) return res.status(404).json({ error: 'not found' });
  res.json(user);
});

// Update user
app.put('/users/:id', async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isFinite(id)) return res.status(400).json({ error: 'invalid id' });

  const { email, name } = req.body || {};
  try {
    const user = await prisma.user.update({
      where: { id },
      data: { ...(email ? { email } : {}), ...(name !== undefined ? { name } : {}) }
    });
    res.json(user);
  } catch (err) {
    if (err && err.code === 'P2025') {
      return res.status(404).json({ error: 'not found' });
    }
    if (err && err.code === 'P2002') {
      return res.status(409).json({ error: 'email already exists' });
    }
    console.error(err);
    res.status(500).json({ error: 'internal error' });
  }
});

// Delete user
app.delete('/users/:id', async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isFinite(id)) return res.status(400).json({ error: 'invalid id' });

  try {
    await prisma.user.delete({ where: { id } });
    res.status(204).send();
  } catch (err) {
    if (err && err.code === 'P2025') {
      return res.status(404).json({ error: 'not found' });
    }
    console.error(err);
    res.status(500).json({ error: 'internal error' });
  }
});

const port = Number(process.env.PORT || 3000);
const host = process.env.HOST || '0.0.0.0';

app.listen(port, host, () => {
  console.log(`API listening on http://${host}:${port}`);
});
