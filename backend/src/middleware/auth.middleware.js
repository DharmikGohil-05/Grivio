// Auth middleware — protects routes that require a logged-in user.
// Expects:  Authorization: Bearer <jwt>
const { verifyToken } = require('../utils/jwt');

module.exports = function authMiddleware(req, res, next) {
  const header = req.headers.authorization || '';
  const [scheme, token] = header.split(' ');

  if (scheme !== 'Bearer' || !token) {
    return res.status(401).json({ success: false, message: 'Missing or malformed token' });
  }

  const payload = verifyToken(token);
  if (!payload) {
    return res.status(401).json({ success: false, message: 'Invalid or expired token' });
  }

  // Attach the user id so controllers/services can trust the caller's identity.
  // Identity ALWAYS comes from the verified token — never from the request
  // body, query string, or headers, which are attacker-controlled. Every
  // service query filters by this id, which is what stops one user from
  // reading or changing another user's records (the authorization boundary).
  req.userId = payload.sub;
  next();
};
