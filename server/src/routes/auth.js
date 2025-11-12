import { Router } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { z } from 'zod';
import { config } from '../config.js';
import { requireAuth, signAccessToken } from '../utils/auth.js';
import { query } from '../db.js';

const router = Router();

const credentialsSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8).max(128)
});

router.post('/register', async (req, res) => {
  try {
    const { email, password } = credentialsSchema.parse(req.body);

    const passwordHash = await bcrypt.hash(password, 10);

    try {
      const result = await query(
        `
          INSERT INTO users (email, password_hash)
          VALUES ($1, $2)
          RETURNING id, email, created_at
        `,
        [email.toLowerCase(), passwordHash]
      );

      const user = result.rows[0];
      res.status(201).json({
        id: user.id,
        email: user.email,
        createdAt: user.created_at
      });
    } catch (err) {
      if (err.code === '23505') {
        return res.status(409).json({ message: 'Email already registered' });
      }
      throw err;
    }
  } catch (err) {
    if (err instanceof z.ZodError) {
      return res.status(400).json({ message: 'Invalid input', issues: err.issues });
    }
    res.status(500).json({ message: 'Server error' });
  }
});

router.post('/login', async (req, res) => {
  try {
    const { email, password } = credentialsSchema.parse(req.body);

    const userResult = await query(
      `
        SELECT id, email, password_hash
        FROM users
        WHERE email = $1
      `,
      [email.toLowerCase()]
    );

    const user = userResult.rows[0];
    if (!user) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }

    const ok = await bcrypt.compare(password, user.password_hash);
    if (!ok) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }

    const accessToken = signAccessToken(user.id);
    const refreshToken = jwt.sign({ sub: user.id }, config.jwtRefreshSecret, { expiresIn: config.refreshTokenTtl });

    await query(
      `
        INSERT INTO refresh_tokens (token, user_id)
        VALUES ($1, $2)
        ON CONFLICT (token) DO NOTHING
      `,
      [refreshToken, user.id]
    );

    res.json({ accessToken, refreshToken });
  } catch (err) {
    if (err instanceof z.ZodError) {
      return res.status(400).json({ message: 'Invalid input', issues: err.issues });
    }
    res.status(500).json({ message: 'Server error' });
  }
});

router.post('/refresh', async (req, res) => {
  try {
    const token = req.body?.refreshToken;
    if (!token) return res.status(400).json({ message: 'Missing refreshToken' });

    const storedResult = await query(
      `
        SELECT user_id
        FROM refresh_tokens
        WHERE token = $1
      `,
      [token]
    );

    const stored = storedResult.rows[0];
    if (!stored) return res.status(401).json({ message: 'Invalid token' });

    try {
      const payload = jwt.verify(token, config.jwtRefreshSecret);
      const userId = Number(payload.sub);
      const newAccessToken = signAccessToken(userId);
      return res.json({ accessToken: newAccessToken });
    } catch (e) {
      await query('DELETE FROM refresh_tokens WHERE token = $1', [token]);
      return res.status(401).json({ message: 'Expired or invalid token' });
    }
  } catch (err) {
    res.status(500).json({ message: 'Server error' });
  }
});

router.post('/logout', async (req, res) => {
  try {
    const token = req.body?.refreshToken;
    if (!token) return res.status(400).json({ message: 'Missing refreshToken' });
    await query('DELETE FROM refresh_tokens WHERE token = $1', [token]);
    res.json({ success: true });
  } catch {
    res.json({ success: true });
  }
});

router.get('/me', requireAuth, async (req, res) => {
  const result = await query(
    `
      SELECT id, email, created_at
      FROM users
      WHERE id = $1
    `,
    [req.userId]
  );

  const user = result.rows[0];
  if (!user) {
    return res.status(404).json({ message: 'User not found' });
  }

  res.json({
    id: user.id,
    email: user.email,
    createdAt: user.created_at
  });
});

export default router;


