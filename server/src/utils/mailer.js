import nodemailer from 'nodemailer';
import { config } from '../config.js';

function createTransporter() {
  if (!config.emailFrom || !config.emailPass) {
    return null;
  }

  return nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: config.emailFrom,
      pass: config.emailPass,
    },
  });
}

export async function sendPasswordResetEmail(to, code) {
  const transporter = createTransporter();

  if (!transporter) {
    console.log(`\n[DEV – email not configured]`);
    console.log(`    To:   ${to}`);
    console.log(`    Code: ${code}\n`);
    return;
  }

  const html = `
    <div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto; padding: 32px; background: #FFF8F2; border-radius: 16px;">
      <h2 style="color: #FF8C42; margin-bottom: 8px;">Resetare parolă</h2>
      <p style="color: #444; font-size: 16px;">
        Codul tău de verificare este:
      </p>
      <div style="font-size: 40px; font-weight: bold; letter-spacing: 10px; color: #1F1F1F; text-align: center; padding: 24px 0;">
        ${code}
      </div>
      <p style="color: #777; font-size: 14px;">
        Codul este valabil <strong>10 minute</strong>. Dacă nu ai solicitat resetarea parolei, ignoră acest email.
      </p>
      <hr style="border: none; border-top: 1px solid #eee; margin: 24px 0;" />
      <p style="color: #aaa; font-size: 12px; text-align: center;">Safety App</p>
    </div>
  `;

  await transporter.sendMail({
    from: `"Safety App" <${config.emailFrom}>`,
    to,
    subject: `Codul tău de resetare parolă: ${code}`,
    html,
  });
}
