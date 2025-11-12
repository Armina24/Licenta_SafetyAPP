import jwt from 'jsonwebtoken';
import { config } from '../config.js';

export function signAccessToken(userId) {
  return jwt.sign({ sub: userId }, config.jwtAccessSecret, { expiresIn: config.accessTokenTtl });
}

export function requireAuth(req, res, next) {
  const authHeader = req.headers.authorization || '';
  const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;
  if (!token) return res.status(401).json({ message: 'Missing Authorization header' });
  try {
    const payload = jwt.verify(token, config.jwtAccessSecret);
    req.userId = Number(payload.sub);
    return next();
  } catch {
    return res.status(401).json({ message: 'Invalid or expired token' });
  }
}


