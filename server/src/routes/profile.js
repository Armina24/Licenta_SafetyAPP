import { Router } from 'express';
import { z } from 'zod';
import { query } from '../db.js';
import { requireAuth } from '../utils/auth.js';

const router = Router();

const profileUpdateSchema = z.object({
  displayName: z.string().min(1).max(255).optional(),
  phoneNumber: z.string().max(20).optional(),
  profilePictureUrl: z.string().url().optional(),
  bio: z.string().max(500).optional(),
});

const emergencyContactSchema = z.object({
  name: z.string().min(1).max(255),
  phoneNumber: z.string().min(1).max(20),
  relationship: z.string().max(100).optional(),
});

router.get('/profile', requireAuth, async (req, res) => {
  try {
    const result = await query(
      `
        SELECT id, user_id, display_name, phone_number, profile_picture_url, bio, created_at, updated_at
        FROM user_profiles
        WHERE user_id = $1
      `,
      [req.userId]
    );

    const profile = result.rows[0];
    if (!profile) {
      return res.status(404).json({ message: 'Profile not found' });
    }

    res.json({
      id: profile.id,
      userId: profile.user_id,
      displayName: profile.display_name,
      phoneNumber: profile.phone_number,
      profilePictureUrl: profile.profile_picture_url,
      bio: profile.bio,
      createdAt: profile.created_at,
      updatedAt: profile.updated_at,
    });
  } catch (err) {
    res.status(500).json({ message: 'Server error' });
  }
});

router.post('/profile', requireAuth, async (req, res) => {
  try {
    const data = profileUpdateSchema.parse(req.body);

    const existingResult = await query(
      `SELECT id FROM user_profiles WHERE user_id = $1`,
      [req.userId]
    );

    if (existingResult.rows.length > 0) {

      const result = await query(
        `
          UPDATE user_profiles
          SET display_name = COALESCE($1, display_name),
              phone_number = COALESCE($2, phone_number),
              profile_picture_url = COALESCE($3, profile_picture_url),
              bio = COALESCE($4, bio),
              updated_at = NOW()
          WHERE user_id = $5
          RETURNING id, user_id, display_name, phone_number, profile_picture_url, bio, created_at, updated_at
        `,
        [
          data.displayName || null,
          data.phoneNumber || null,
          data.profilePictureUrl || null,
          data.bio || null,
          req.userId,
        ]
      );

      const profile = result.rows[0];
      return res.json({
        id: profile.id,
        userId: profile.user_id,
        displayName: profile.display_name,
        phoneNumber: profile.phone_number,
        profilePictureUrl: profile.profile_picture_url,
        bio: profile.bio,
        createdAt: profile.created_at,
        updatedAt: profile.updated_at,
      });
    } else {

      const result = await query(
        `
          INSERT INTO user_profiles (user_id, display_name, phone_number, profile_picture_url, bio)
          VALUES ($1, $2, $3, $4, $5)
          RETURNING id, user_id, display_name, phone_number, profile_picture_url, bio, created_at, updated_at
        `,
        [
          req.userId,
          data.displayName || null,
          data.phoneNumber || null,
          data.profilePictureUrl || null,
          data.bio || null,
        ]
      );

      const profile = result.rows[0];
      return res.status(201).json({
        id: profile.id,
        userId: profile.user_id,
        displayName: profile.display_name,
        phoneNumber: profile.phone_number,
        profilePictureUrl: profile.profile_picture_url,
        bio: profile.bio,
        createdAt: profile.created_at,
        updatedAt: profile.updated_at,
      });
    }
  } catch (err) {
    if (err instanceof z.ZodError) {
      return res.status(400).json({ message: 'Invalid input', issues: err.issues });
    }
    res.status(500).json({ message: 'Server error' });
  }
});

router.get('/emergency-contacts', requireAuth, async (req, res) => {
  try {
    const result = await query(
      `
        SELECT id, user_id, name, phone_number, relationship, created_at, updated_at
        FROM emergency_contacts
        WHERE user_id = $1
        ORDER BY created_at DESC
      `,
      [req.userId]
    );

    const contacts = result.rows.map((row) => ({
      id: row.id,
      userId: row.user_id,
      name: row.name,
      phoneNumber: row.phone_number,
      relationship: row.relationship,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    }));

    res.json(contacts);
  } catch (err) {
    res.status(500).json({ message: 'Server error' });
  }
});

router.post('/emergency-contacts', requireAuth, async (req, res) => {
  try {
    const data = emergencyContactSchema.parse(req.body);

    const result = await query(
      `
        INSERT INTO emergency_contacts (user_id, name, phone_number, relationship)
        VALUES ($1, $2, $3, $4)
        RETURNING id, user_id, name, phone_number, relationship, created_at, updated_at
      `,
      [req.userId, data.name, data.phoneNumber, data.relationship || null]
    );

    const contact = result.rows[0];
    res.status(201).json({
      id: contact.id,
      userId: contact.user_id,
      name: contact.name,
      phoneNumber: contact.phone_number,
      relationship: contact.relationship,
      createdAt: contact.created_at,
      updatedAt: contact.updated_at,
    });
  } catch (err) {
    if (err instanceof z.ZodError) {
      return res.status(400).json({ message: 'Invalid input', issues: err.issues });
    }
    res.status(500).json({ message: 'Server error' });
  }
});

router.put('/emergency-contacts/:contactId', requireAuth, async (req, res) => {
  try {
    const { contactId } = req.params;
    const data = emergencyContactSchema.partial().parse(req.body);

    const checkResult = await query(
      `SELECT id FROM emergency_contacts WHERE id = $1 AND user_id = $2`,
      [contactId, req.userId]
    );

    if (checkResult.rows.length === 0) {
      return res.status(404).json({ message: 'Contact not found' });
    }

    const result = await query(
      `
        UPDATE emergency_contacts
        SET name = COALESCE($1, name),
            phone_number = COALESCE($2, phone_number),
            relationship = COALESCE($3, relationship),
            updated_at = NOW()
        WHERE id = $4 AND user_id = $5
        RETURNING id, user_id, name, phone_number, relationship, created_at, updated_at
      `,
      [
        data.name || null,
        data.phoneNumber || null,
        data.relationship || null,
        contactId,
        req.userId,
      ]
    );

    const contact = result.rows[0];
    res.json({
      id: contact.id,
      userId: contact.user_id,
      name: contact.name,
      phoneNumber: contact.phone_number,
      relationship: contact.relationship,
      createdAt: contact.created_at,
      updatedAt: contact.updated_at,
    });
  } catch (err) {
    if (err instanceof z.ZodError) {
      return res.status(400).json({ message: 'Invalid input', issues: err.issues });
    }
    res.status(500).json({ message: 'Server error' });
  }
});

router.delete('/emergency-contacts/:contactId', requireAuth, async (req, res) => {
  try {
    const { contactId } = req.params;

    const checkResult = await query(
      `SELECT id FROM emergency_contacts WHERE id = $1 AND user_id = $2`,
      [contactId, req.userId]
    );

    if (checkResult.rows.length === 0) {
      return res.status(404).json({ message: 'Contact not found' });
    }

    await query(
      `DELETE FROM emergency_contacts WHERE id = $1 AND user_id = $2`,
      [contactId, req.userId]
    );

    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ message: 'Server error' });
  }
});

router.get('/alerts', requireAuth, async (req, res) => {
  try {
    const result = await query(
      `
        SELECT id, user_id, timestamp, latitude, longitude, status, contacts_reached, message, created_at
        FROM alerts_history
        WHERE user_id = $1
        ORDER BY timestamp DESC
        LIMIT 100
      `,
      [req.userId]
    );

    const alerts = result.rows.map((row) => ({
      id: row.id,
      userId: row.user_id,
      timestamp: row.timestamp,
      latitude: row.latitude,
      longitude: row.longitude,
      status: row.status,
      contactsReached: row.contacts_reached,
      message: row.message,
      createdAt: row.created_at,
    }));

    res.json(alerts);
  } catch (err) {
    res.status(500).json({ message: 'Server error' });
  }
});

router.post('/alerts', requireAuth, async (req, res) => {
  try {
    const { latitude, longitude, status, contactsReached, message } = req.body;

    const result = await query(
      `
        INSERT INTO alerts_history (user_id, latitude, longitude, status, contacts_reached, message)
        VALUES ($1, $2, $3, $4, $5, $6)
        RETURNING id, user_id, timestamp, latitude, longitude, status, contacts_reached, message, created_at
      `,
      [
        req.userId,
        latitude || null,
        longitude || null,
        status || 'pending',
        contactsReached || 0,
        message || null,
      ]
    );

    const alert = result.rows[0];
    res.status(201).json({
      id: alert.id,
      userId: alert.user_id,
      timestamp: alert.timestamp,
      latitude: alert.latitude,
      longitude: alert.longitude,
      status: alert.status,
      contactsReached: alert.contacts_reached,
      message: alert.message,
      createdAt: alert.created_at,
    });
  } catch (err) {
    res.status(500).json({ message: 'Server error' });
  }
});

export default router;
