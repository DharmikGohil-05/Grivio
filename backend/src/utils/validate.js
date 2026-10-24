// Input validation for auth endpoints.
// Keeps controller code clean and returns consistent, safe error messages.

// Basic RFC-style email sanity check.
function isValidEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

// Password policy: at least 8 chars, one letter, one number.
function isStrongPassword(password) {
  return (
    typeof password === 'string' &&
    password.length >= 8 &&
    /[A-Za-z]/.test(password) &&
    /[0-9]/.test(password)
  );
}

// Returns an array of validation problems (empty array = valid).
function validateRegisterInput({ name, email, password }) {
  const errors = [];
  if (!name || !name.trim()) errors.push('Name is required');
  if (!email || !isValidEmail(email)) errors.push('A valid email is required');
  if (!isStrongPassword(password)) {
    errors.push('Password must be at least 8 characters and include letters and numbers');
  }
  return errors;
}

function validateLoginInput({ email, password }) {
  const errors = [];
  if (!email || !isValidEmail(email)) errors.push('A valid email is required');
  if (!password) errors.push('Password is required');
  return errors;
}

module.exports = { validateRegisterInput, validateLoginInput };
