import { Router } from 'express';
import { randomBytes } from 'crypto';
import { z } from 'zod';
import { query } from '../db.js';

const router = Router();

const sseClients = new Map();

function sendSseUpdate(token, payload) {
  const clients = sseClients.get(token);
  if (!clients || clients.size === 0) return;
  const data = `event: update\ndata: ${JSON.stringify(payload)}\n\n`;
  for (const res of clients) {
    try {
      res.write(data);
    } catch (err) {

    }
  }
}

const createSessionSchema = z.object({
  durationMinutes: z.number().int().min(5).max(720),
});

const updateLocationSchema = z.object({
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
  accuracyMeters: z.number().positive().optional(),
});

function buildPublicShareUrl(req, token) {
  const protocol = (req.get('x-forwarded-proto') || req.protocol || 'http').split(',')[0].trim();
  const host = (req.get('x-forwarded-host') || req.get('host') || 'localhost:4000').split(',')[0].trim();
  return new URL(`/share/location/${token}`, `${protocol}://${host}`).toString();
}

function buildStatusMessage(session) {
  if (session.status === 'ended') {
    return 'Live location sharing has ended.';
  }

  if (session.status === 'expired') {
    return 'Live location sharing has expired.';
  }

  return 'Live location sharing is currently active.';
}

router.post('/api/location-shares', async (req, res) => {
  try {
    const { durationMinutes } = createSessionSchema.parse(req.body);
    const token = randomBytes(18).toString('base64url');
    const expiresAt = new Date(Date.now() + durationMinutes * 60_000);

    await query(
      `
        INSERT INTO location_share_sessions (
          token,
          expires_at,
          duration_minutes
        ) VALUES ($1, $2, $3)
      `,
      [token, expiresAt, durationMinutes]
    );

    res.status(201).json({
      token,
      shareUrl: buildPublicShareUrl(req, token),
      expiresAt,
      durationMinutes,
    });
  } catch (err) {
    if (err instanceof z.ZodError) {
      return res.status(400).json({ message: 'Invalid input', issues: err.issues });
    }
    res.status(500).json({ message: 'Server error' });
  }
});

router.patch('/api/location-shares/:token/location', async (req, res) => {
  try {
    const { token } = req.params;
    const data = updateLocationSchema.parse(req.body);

    console.log(`[location-shares] PATCH /api/location-shares/${token}/location ->`, {
      latitude: data.latitude,
      longitude: data.longitude,
      accuracyMeters: data.accuracyMeters ?? null,
    });

    const sessionResult = await query(
      `
        SELECT id, status, expires_at
        FROM location_share_sessions
        WHERE token = $1
      `,
      [token]
    );

    const session = sessionResult.rows[0];
    if (!session) {
      return res.status(404).json({ message: 'Share session not found' });
    }

    if (session.status !== 'active' || new Date(session.expires_at) <= new Date()) {
      await query(
        `
          UPDATE location_share_sessions
          SET status = 'expired', ended_at = COALESCE(ended_at, NOW())
          WHERE token = $1
        `,
        [token]
      );
      return res.status(410).json({ message: 'Share session expired' });
    }

    await query(
      `
        UPDATE location_share_sessions
        SET latest_latitude = $2,
            latest_longitude = $3,
            latest_accuracy_m = $4,
            last_location_at = NOW()
        WHERE token = $1
      `,
      [token, data.latitude, data.longitude, data.accuracyMeters ?? null]
    );

    try {
      const fresh = await query(
        `
          SELECT token, status, created_at, updated_at, started_at, expires_at,
                 ended_at, latest_latitude, latest_longitude, latest_accuracy_m,
                 last_location_at, duration_minutes
          FROM location_share_sessions
          WHERE token = $1
        `,
        [token]
      );
      const s = fresh.rows[0];
      if (s) {
        sendSseUpdate(token, {
          token: s.token,
          status: s.status,
          message: buildStatusMessage(s),
          createdAt: s.created_at,
          updatedAt: s.updated_at,
          startedAt: s.started_at,
          expiresAt: s.expires_at,
          endedAt: s.ended_at,
          latestLatitude: s.latest_latitude,
          latestLongitude: s.latest_longitude,
          latestAccuracyMeters: s.latest_accuracy_m,
          lastLocationAt: s.last_location_at,
          durationMinutes: s.duration_minutes,
        });
      }
    } catch (err) {

    }

    res.json({ success: true });
  } catch (err) {
    if (err instanceof z.ZodError) {
      return res.status(400).json({ message: 'Invalid input', issues: err.issues });
    }
    res.status(500).json({ message: 'Server error' });
  }
});

router.post('/api/location-shares/:token/stop', async (req, res) => {
  try {
    const { token } = req.params;
    const result = await query(
      `
        UPDATE location_share_sessions
        SET status = 'ended',
            ended_at = NOW()
        WHERE token = $1
        RETURNING token
      `,
      [token]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Share session not found' });
    }

    try {
      const fresh = await query(
        `SELECT token, status, expires_at, ended_at, latest_latitude, latest_longitude, latest_accuracy_m, last_location_at, duration_minutes
         FROM location_share_sessions WHERE token = $1`,
        [token]
      );
      const s = fresh.rows[0];
      if (s) {
        sendSseUpdate(token, {
          token: s.token,
          status: s.status,
          message: buildStatusMessage(s),
          expiresAt: s.expires_at,
          endedAt: s.ended_at,
          latestLatitude: s.latest_latitude,
          latestLongitude: s.latest_longitude,
          latestAccuracyMeters: s.latest_accuracy_m,
          lastLocationAt: s.last_location_at,
          durationMinutes: s.duration_minutes,
        });
      }
    } catch (err) {

    }

    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ message: 'Server error' });
  }
});

router.get('/api/location-shares/:token/stream', async (req, res) => {
  try {
    const { token } = req.params;
    res.set({
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      Connection: 'keep-alive',
    });
    res.flushHeaders?.();

    const clients = sseClients.get(token) ?? new Set();
    clients.add(res);
    sseClients.set(token, clients);

    req.on('close', () => {
      const set = sseClients.get(token);
      if (set) {
        set.delete(res);
        if (set.size === 0) sseClients.delete(token);
      }
    });

    try {
      const fresh = await query(
        `
          SELECT token, status, created_at, updated_at, started_at, expires_at,
                 ended_at, latest_latitude, latest_longitude, latest_accuracy_m,
                 last_location_at, duration_minutes
          FROM location_share_sessions
          WHERE token = $1
        `,
        [token]
      );
      const s = fresh.rows[0];
      if (s) {
        const payload = {
          token: s.token,
          status: s.status,
          message: buildStatusMessage(s),
          createdAt: s.created_at,
          updatedAt: s.updated_at,
          startedAt: s.started_at,
          expiresAt: s.expires_at,
          endedAt: s.ended_at,
          latestLatitude: s.latest_latitude,
          latestLongitude: s.latest_longitude,
          latestAccuracyMeters: s.latest_accuracy_m,
          lastLocationAt: s.last_location_at,
          durationMinutes: s.duration_minutes,
        };
        res.write(`event: update\ndata: ${JSON.stringify(payload)}\n\n`);
      }
    } catch (err) {

    }
  } catch (err) {
    res.status(500).end();
  }
});

router.get('/api/location-shares/:token', async (req, res) => {
  try {
    const { token } = req.params;
    const result = await query(
      `
        SELECT token, status, created_at, updated_at, started_at, expires_at,
               ended_at, latest_latitude, latest_longitude, latest_accuracy_m,
               last_location_at, duration_minutes
        FROM location_share_sessions
        WHERE token = $1
      `,
      [token]
    );

    const session = result.rows[0];
    if (!session) {
      return res.status(404).json({ message: 'Share session not found' });
    }

    if (session.status === 'active' && new Date(session.expires_at) <= new Date()) {
      await query(
        `
          UPDATE location_share_sessions
          SET status = 'expired', ended_at = COALESCE(ended_at, NOW())
          WHERE token = $1
        `,
        [token]
      );
      session.status = 'expired';
    }

    res.json({
      token: session.token,
      status: session.status,
      message: buildStatusMessage(session),
      createdAt: session.created_at,
      updatedAt: session.updated_at,
      startedAt: session.started_at,
      expiresAt: session.expires_at,
      endedAt: session.ended_at,
      latestLatitude: session.latest_latitude,
      latestLongitude: session.latest_longitude,
      latestAccuracyMeters: session.latest_accuracy_m,
      lastLocationAt: session.last_location_at,
      durationMinutes: session.duration_minutes,
    });
  } catch (err) {
    res.status(500).json({ message: 'Server error' });
  }
});

router.get('/share/location/:token', async (req, res) => {
  try {
    const { token } = req.params;
    const result = await query(
      `
        SELECT token, status, expires_at, ended_at,
               latest_latitude, latest_longitude, latest_accuracy_m,
               last_location_at, duration_minutes
        FROM location_share_sessions
        WHERE token = $1
      `,
      [token]
    );

    const session = result.rows[0];
    if (!session) {
      return res.status(404).send('<h1>Share session not found</h1>');
    }

    res.type('html').send(`
      <!doctype html>
      <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>Live Location Sharing</title>
        <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
        <style>
          body {
            margin: 0;
            font-family: Arial, sans-serif;
            background: linear-gradient(180deg, #fff7f0 0%, #ffffff 100%);
            color: #1f1f1f;
          }
          .card {
            max-width: 920px;
            margin: 24px auto;
            padding: 24px;
            background: rgba(255, 255, 255, 0.94);
            border-radius: 20px;
            box-shadow: 0 12px 40px rgba(0,0,0,0.08);
          }
          .status {
            display: inline-block;
            padding: 6px 12px;
            border-radius: 999px;
            font-weight: 700;
            background: #ffe7d6;
            color: #b44a00;
          }
          .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
            gap: 12px;
            margin-top: 20px;
          }
          .tile {
            padding: 14px;
            border-radius: 14px;
            background: #fafafa;
            border: 1px solid #ececec;
          }
          .label { font-size: 12px; text-transform: uppercase; letter-spacing: .06em; color: #666; }
          .value { margin-top: 6px; font-size: 16px; font-weight: 600; word-break: break-word; }
          .actions { margin-top: 20px; display: flex; gap: 12px; flex-wrap: wrap; }
          a.button {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            padding: 12px 16px;
            border-radius: 12px;
            text-decoration: none;
            background: #ff8c42;
            color: #fff;
            font-weight: 700;
          }
          .muted { color: #666; }
          .map-box {
            margin-top: 20px;
            height: 420px;
            border-radius: 18px;
            overflow: hidden;
            border: 1px solid #ececec;
            background: #fff;
            display: grid;
            grid-template-columns: 1fr;
            gap: 12px;
            padding: 0;
          }
          #map { width: 100%; height: 100%; }
          .map-overlay {
            position: absolute; z-index: 400; margin: 16px; background: rgba(255,255,255,0.9); padding: 8px 12px; border-radius: 12px; box-shadow: 0 6px 18px rgba(0,0,0,0.06);
          }
        </style>
      </head>
      <body>
        <main class="card">
          <div class="status" id="status">Loading live location…</div>
          <h1>Live Location Sharing</h1>
          <p class="muted">This page refreshes automatically while the sender is sharing location.</p>

          <div class="grid">
            <div class="tile">
              <div class="label">Latest coordinates</div>
              <div class="value" id="coords">Waiting for location…</div>
            </div>
            <div class="tile">
              <div class="label">Last update</div>
              <div class="value" id="lastUpdate">—</div>
            </div>
            <div class="tile">
              <div class="label">Expires</div>
              <div class="value" id="expiresAt">—</div>
            </div>
          </div>

          <div class="map-box" id="mapBox">
            <div id="map"></div>
          </div>

          <div style="margin-top:12px; display:flex; gap:12px;">
            <a id="mapLink" class="button" href="#" target="_blank" rel="noreferrer" style="display:none;">Open in Maps</a>
          </div>

          <div id="diagnostics" style="margin-top:12px; font-size:13px; color:#666;">
            <div><strong>Diagnostics</strong></div>
            <div>SSE: <span id="sseStatus">—</span></div>
            <div>Leaflet: <span id="leafletStatus">—</span></div>
            <div>Last event:<pre id="lastEvent" style="white-space:pre-wrap; background:#f6f6f6; padding:8px; border-radius:6px; max-height:160px; overflow:auto;">—</pre></div>
          </div>
        </main>

        <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
        <script>
          const token = ${JSON.stringify(token)};
          const statusEl = document.getElementById('status');
          const coordsEl = document.getElementById('coords');
          const lastUpdateEl = document.getElementById('lastUpdate');
          const expiresAtEl = document.getElementById('expiresAt');
          const mapLinkEl = document.getElementById('mapLink');

          function formatDate(value) {
            if (!value) return '—';
            return new Date(value).toLocaleString();
          }

          function setMapLink(lat, lon) {
            const link = 'https://www.google.com/maps?q=' + lat + ',' + lon;
            mapLinkEl.href = link;
            mapLinkEl.style.display = 'inline-flex';
          }

          let map = null;
          let marker = null;
          let accuracyCircle = null;
          let firstFix = true;

          function initMap() {
            map = L.map('map', { zoomControl: true }).setView([0, 0], 2);
            L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
              attribution: '&copy; OpenStreetMap contributors'
            }).addTo(map);
          }

          function updateMap(lat, lon, accuracy) {
            const latNum = Number(lat);
            const lonNum = Number(lon);
            if (!marker) {
              marker = L.marker([latNum, lonNum]).addTo(map);
            } else {
              marker.setLatLng([latNum, lonNum]);
            }

            if (accuracy != null) {
              if (!accuracyCircle) {
                accuracyCircle = L.circle([latNum, lonNum], { radius: Number(accuracy), color: '#3b82f6', opacity: 0.4 }).addTo(map);
              } else {
                accuracyCircle.setLatLng([latNum, lonNum]);
                accuracyCircle.setRadius(Number(accuracy));
              }
            }

            if (firstFix) {
              firstFix = false;
              try { map.setView([latNum, lonNum], 16); } catch (e) {}
            }
          }

          async function refresh() {
            try {
              const response = await fetch('/api/location-shares/' + token);
              if (!response.ok) {
                statusEl.textContent = 'Unable to load location session.';
                return;
              }

              const data = await response.json();
              statusEl.textContent = data.message || data.status;
              expiresAtEl.textContent = formatDate(data.expiresAt);
              lastUpdateEl.textContent = formatDate(data.lastLocationAt);

              if (data.latestLatitude != null && data.latestLongitude != null) {
                const lat = Number(data.latestLatitude).toFixed(6);
                const lon = Number(data.latestLongitude).toFixed(6);
                coordsEl.textContent = lat + ', ' + lon;
                setMapLink(lat, lon);
                updateMap(lat, lon, data.latestAccuracyMeters ?? null);
              } else {
                coordsEl.textContent = 'Waiting for the first live update…';
              }

              if (data.status !== 'active') {
                window.clearInterval(window.__liveLocationTimer);
              }
            } catch (error) {
              statusEl.textContent = 'Unable to load location session.';
            }
          }

          try {
            initMap();
          } catch (err) {
            console.error('Map initialization failed', err);
            const mapTextEl = document.getElementById('mapBox');
            if (mapTextEl) {
              mapTextEl.textContent = 'Map failed to load. Open the link in a browser that allows loading external scripts.';
            }
          }
          // Try Server-Sent Events (SSE) for realtime updates; fallback to polling
          function startPolling() {
            window.__liveLocationTimer = window.setInterval(refresh, 5000);
            refresh();
          }

          if (typeof EventSource !== 'undefined') {
            try {
              const es = new EventSource('/api/location-shares/' + token + '/stream');
              // server sends events as 'event: update' so listen for that event name
              es.addEventListener('update', (e) => {
                try {
                  const data = JSON.parse(e.data);
                  const lastEventEl = document.getElementById('lastEvent');
                  const sseStatusEl = document.getElementById('sseStatus');
                  if (sseStatusEl) sseStatusEl.textContent = 'connected';
                  if (lastEventEl) lastEventEl.textContent = JSON.stringify(data, null, 2);
                  statusEl.textContent = data.message || data.status;
                  expiresAtEl.textContent = formatDate(data.expiresAt);
                  lastUpdateEl.textContent = formatDate(data.lastLocationAt);

                  if (data.latestLatitude != null && data.latestLongitude != null) {
                    const lat = Number(data.latestLatitude).toFixed(6);
                    const lon = Number(data.latestLongitude).toFixed(6);
                    coordsEl.textContent = lat + ', ' + lon;
                    setMapLink(lat, lon);
                    updateMap(lat, lon, data.latestAccuracyMeters ?? null);
                  }

                  if (data.status !== 'active') {
                    es.close();
                  }
                } catch (err) {
                  // ignore parse errors
                }
              });

              // also accept default message events just in case
              es.onmessage = (e) => {
                try {
                  const data = JSON.parse(e.data);
                  const lastEventEl = document.getElementById('lastEvent');
                  const sseStatusEl = document.getElementById('sseStatus');
                  if (sseStatusEl) sseStatusEl.textContent = 'connected';
                  if (lastEventEl) lastEventEl.textContent = JSON.stringify(data, null, 2);
                  statusEl.textContent = data.message || data.status;
                  expiresAtEl.textContent = formatDate(data.expiresAt);
                  lastUpdateEl.textContent = formatDate(data.lastLocationAt);
                  if (data.latestLatitude != null && data.latestLongitude != null) {
                    const lat = Number(data.latestLatitude).toFixed(6);
                    const lon = Number(data.latestLongitude).toFixed(6);
                    coordsEl.textContent = lat + ', ' + lon;
                    setMapLink(lat, lon);
                    updateMap(lat, lon, data.latestAccuracyMeters ?? null);
                  }
                } catch (err) {}
              };

              es.onopen = () => {
                const sseStatusEl = document.getElementById('sseStatus');
                if (sseStatusEl) sseStatusEl.textContent = 'open';
              };
              es.onerror = () => {
                const sseStatusEl = document.getElementById('sseStatus');
                if (sseStatusEl) sseStatusEl.textContent = 'error';
                try { es.close(); } catch (e) {}
                startPolling();
              };
              es.onclose = () => {
                const sseStatusEl = document.getElementById('sseStatus');
                if (sseStatusEl) sseStatusEl.textContent = 'closed';
              };
            } catch (err) {
              startPolling();
            }
          } else {
            startPolling();
          }
        </script>
      </body>
      </html>
    `);
  } catch (err) {
    res.status(500).send('<h1>Server error</h1>');
  }
});

export default router;
