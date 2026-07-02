import dotenv from 'dotenv';

dotenv.config();

export const config = {
  port: Number(process.env.PORT || 4000),
  databaseUrl: process.env.DATABASE_URL,
  jwtAccessSecret: process.env.JWT_ACCESS_SECRET,
  jwtRefreshSecret: process.env.JWT_REFRESH_SECRET,
  accessTokenTtl: process.env.ACCESS_TOKEN_TTL || '15m',
  refreshTokenTtl: process.env.REFRESH_TOKEN_TTL || '7d',
  clientOrigin: process.env.CLIENT_ORIGIN || '*',
  emailFrom: process.env.EMAIL_FROM || '',
  emailPass: process.env.EMAIL_PASS || '',
};

function assertEnv(name, value) {
  if (!value || String(value).trim() === '') {
    throw new Error(`Missing required environment variable: ${name}`);
  }
}

export function assertRequiredEnv() {
  assertEnv('DATABASE_URL', config.databaseUrl);
  assertEnv('JWT_ACCESS_SECRET', config.jwtAccessSecret);
  assertEnv('JWT_REFRESH_SECRET', config.jwtRefreshSecret);
}
