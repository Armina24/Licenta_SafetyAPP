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

const forgotPasswordSchema = z.object({
  email: z.string().email(),
  channel: z.enum(['email', 'sms']),
});

router.post('/forgot-password', async (req, res) => {
  try {
    const { email, channel } = forgotPasswordSchema.parse(req.body);

    const userResult = await query(
      `SELECT id FROM users WHERE email = $1`,
      [email.toLowerCase()]
    );
    const user = userResult.rows[0];

    if (!user) {

      return res.json({ message: 'Dacă adresa există, codul a fost trimis.' });
    }

    let phoneNumber = null;
    if (channel === 'sms') {
      const profileResult = await query(
        `SELECT phone_number FROM user_profiles WHERE user_id = $1`,
        [user.id]
      );
      phoneNumber = profileResult.rows[0]?.phone_number;
      if (!phoneNumber) {
        return res.status(422).json({
          message: 'Nu există un număr de telefon asociat contului. Alege email.',
        });
      }
    }

    await query(
      `UPDATE password_reset_tokens SET used = TRUE WHERE user_id = $1 AND used = FALSE`,
      [user.id]
    );

    const code = String(Math.floor(100000 + Math.random() * 900000));
    const codeHash = await bcrypt.hash(code, 10);
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000);

    await query(
      `INSERT INTO password_reset_tokens (user_id, code_hash, channel, expires_at)
       VALUES ($1, $2, $3, $4)`,
      [user.id, codeHash, channel, expiresAt]
    );

    if (channel === 'email') {
      const { sendPasswordResetEmail } = await import('../utils/mailer.js');
      await sendPasswordResetEmail(email.toLowerCase(), code);
    } else {
      const { sendPasswordResetSms } = await import('../utils/sms.js');
      await sendPasswordResetSms(phoneNumber, code);
    }

    res.json({ message: 'Dacă adresa există, codul a fost trimis.' });
  } catch (err) {
    if (err instanceof z.ZodError) {
      return res.status(400).json({ message: 'Date invalide', issues: err.issues });
    }
    console.error('forgot-password error:', err);
    res.status(500).json({ message: 'Eroare server' });
  }
});

const verifyResetCodeSchema = z.object({
  email: z.string().email(),
  code: z.string().length(6),
});

router.post('/verify-reset-code', async (req, res) => {
  try {
    const { email, code } = verifyResetCodeSchema.parse(req.body);

    const userResult = await query(
      `SELECT id FROM users WHERE email = $1`,
      [email.toLowerCase()]
    );
    const user = userResult.rows[0];
    if (!user) {
      return res.status(400).json({ message: 'Cod invalid sau expirat.' });
    }

    const tokenResult = await query(
      `SELECT id, code_hash
       FROM password_reset_tokens
       WHERE user_id = $1
         AND used = FALSE
         AND expires_at > NOW()
       ORDER BY created_at DESC
       LIMIT 1`,
      [user.id]
    );

    const tokenRow = tokenResult.rows[0];
    if (!tokenRow) {
      return res.status(400).json({ message: 'Cod invalid sau expirat.' });
    }

    const match = await bcrypt.compare(code, tokenRow.code_hash);
    if (!match) {
      return res.status(400).json({ message: 'Cod incorect.' });
    }

    await query(
      `UPDATE password_reset_tokens SET used = TRUE WHERE id = $1`,
      [tokenRow.id]
    );

    const resetToken = jwt.sign(
      { sub: user.id, purpose: 'password_reset' },
      config.jwtAccessSecret,
      { expiresIn: '15m' }
    );

    res.json({ resetToken });
  } catch (err) {
    if (err instanceof z.ZodError) {
      return res.status(400).json({ message: 'Date invalide', issues: err.issues });
    }
    console.error('verify-reset-code error:', err);
    res.status(500).json({ message: 'Eroare server' });
  }
});

const resetPasswordSchema = z.object({
  resetToken: z.string().min(1),
  newPassword: z.string().min(8).max(128),
});

router.post('/reset-password', async (req, res) => {
  try {
    const { resetToken, newPassword } = resetPasswordSchema.parse(req.body);

    let payload;
    try {
      payload = jwt.verify(resetToken, config.jwtAccessSecret);
    } catch {
      return res.status(401).json({ message: 'Token expirat sau invalid.' });
    }

    if (payload.purpose !== 'password_reset') {
      return res.status(401).json({ message: 'Token invalid.' });
    }

    const userId = Number(payload.sub);

    const passwordHash = await bcrypt.hash(newPassword, 10);
    await query(
      `UPDATE users SET password_hash = $1, updated_at = NOW() WHERE id = $2`,
      [passwordHash, userId]
    );

    await query(
      `DELETE FROM refresh_tokens WHERE user_id = $1`,
      [userId]
    );

    res.json({ message: 'Parola a fost resetată cu succes.' });
  } catch (err) {
    if (err instanceof z.ZodError) {
      return res.status(400).json({ message: 'Date invalide', issues: err.issues });
    }
    console.error('reset-password error:', err);
    res.status(500).json({ message: 'Eroare server' });
  }
});

export default router;
