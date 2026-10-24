// JWT utility — all token creation/verification lives here so it is
// easy to change claims or expiry later without touching controllers.
const jwt = require('jsonwebtoken');
const config = require('../config/env');

const TOKEN_EXPIRY = '7d'; // Reasonable for a mobile app session.

// Signs a token with ONLY the user id ("sub" claim).
// Never put email, name, or any secret inside the JWT.
function signToken(userId) {
  return jwt.sign({ sub: userId }, config.jwtSecret, { expiresIn: TOKEN_EXPIRY });
}

// Verifies a token and returns its payload, or null if invalid/expired.
function verifyToken(token) {
  try {
    return jwt.verify(token, config.jwtSecret);
  } catch {
    return null;
  }
}

module.exports = { signToken, verifyToken };
