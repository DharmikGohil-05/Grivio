// Auth service — contains ALL business logic for registration/login.
// Controllers stay thin: they validate input, call the service, and
// shape the HTTP response.
const { query } = require('../config/db');
const { hashPassword, comparePassword } = require('../utils/password');
const { signToken } = require('../utils/jwt');

// Registers a new user. Throws an Error with a safe .message on failure;
// the controller converts that into a proper HTTP status code.
async function register({ name, email, password }) {
  // Normalize email so "User@X.com" and "user@x.com" are the same account.
  const normalizedEmail = email.trim().toLowerCase();

  // Prevent duplicate accounts with a safe, generic message.
  const existing = await query('SELECT id FROM users WHERE email = $1', [normalizedEmail]);
  if (existing.rowCount > 0) {
    const err = new Error('An account with this email already exists');
    err.statusCode = 409;
    throw err;
  }

  const passwordHash = await hashPassword(password);

  // Insert the user and return only safe fields — never the hash.
  const result = await query(
    `INSERT INTO users (email, password_hash)
     VALUES ($1, $2)
     RETURNING id, email, created_at`,
    [normalizedEmail, passwordHash]
  );
  const user = result.rows[0];

  // Create the profile row so personalization (Phase 4) has a home.
  await query('INSERT INTO profiles (user_id, name) VALUES ($1, $2)', [user.id, name.trim()]);

  const token = signToken(user.id);
  return { user: { id: user.id, email: user.email, name: name.trim() }, token };
}

// Verifies credentials and returns a JWT + safe user info.
// Uses ONE generic failure message so attackers cannot tell whether
// an email exists (prevents account enumeration).
async function login({ email, password }) {
  const normalizedEmail = email.trim().toLowerCase();
  const result = await query(
    'SELECT id, email, password_hash FROM users WHERE email = $1',
    [normalizedEmail]
  );
  if (result.rowCount === 0) {
    throw invalidCredentials();
  }

  const user = result.rows[0];
  const ok = await comparePassword(password, user.password_hash);
  if (!ok) throw invalidCredentials();

  // Fetch the profile name so the app can greet the user.
  const profile = await query('SELECT name FROM profiles WHERE user_id = $1', [user.id]);
  const token = signToken(user.id);
  return {
    user: { id: user.id, email: user.email, name: profile.rows[0]?.name ?? '' },
    token,
  };
}

function invalidCredentials() {
  const err = new Error('Invalid email or password');
  err.statusCode = 401;
  return err;
}

// Returns safe info for the currently authenticated user (used by /me).
async function getCurrentUser(userId) {
  const result = await query(
    `SELECT u.id, u.email, u.created_at, p.name, p.profile_picture, p.short_description
     FROM users u LEFT JOIN profiles p ON p.user_id = u.id
     WHERE u.id = $1`,
    [userId]
  );
  if (result.rowCount === 0) {
    const err = new Error('User not found');
    err.statusCode = 404;
    throw err;
  }
  return result.rows[0];
}

module.exports = { register, login, getCurrentUser };
