# utils/

- `jwt.js` — sign/verify JSON Web Tokens.
- `password.js` — bcrypt hash/verify (per-user salt; hashes never logged).
- `validate.js`, `taskValidate.js`, `goalValidate.js`, `profileValidate.js` —
  server-side input validation. Validation lives here (not only in the app)
  because the mobile app is not a trust boundary.
