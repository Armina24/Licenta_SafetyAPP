import express from 'express';
import cors from 'cors';
import morgan from 'morgan';
import { config, assertRequiredEnv } from './config.js';
import authRouter from './routes/auth.js';
import { ensureTables, query } from './db.js';

assertRequiredEnv();

const app = express();
app.use(cors({ origin: config.clientOrigin, credentials: true }));
app.use(express.json());
app.use(morgan('dev'));

app.get('/health', async (req, res) => {
  try {
    await query('SELECT 1');
    res.json({ status: 'ok' });
  } catch (e) {
    res.status(500).json({ status: 'error', error: String(e?.message || e) });
  }
});

app.use('/auth', authRouter);

ensureTables()
  .then(() => {
    app.listen(config.port, () => {
      console.log(`API listening on http://0.0.0.0:${config.port}`);
    });
  })
  .catch((err) => {
    console.error('Failed to initialize database tables:', err);
    process.exit(1);
  });


