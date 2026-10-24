// Password hashing — bcrypt with cost factor 10 (good default balance
// between security and speed). Plain-text passwords are NEVER stored.
const bcrypt = require('bcryptjs');

async function hashPassword(plain) {
  return bcrypt.hash(plain, 10);
}

async function comparePassword(plain, hash) {
  return bcrypt.compare(plain, hash);
}

module.exports = { hashPassword, comparePassword };
