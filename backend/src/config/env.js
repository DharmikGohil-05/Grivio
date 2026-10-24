// Central configuration, read once at startup.
// dotenv loads a local .env file into process.env; in production the same
// variables come from the host's environment instead.
//
// Defaults exist so a MISSING value never crashes the process at import
// time — the app still boots and /api/health can reveal what is broken.
// The trade-off: a blank JWT_SECRET or DATABASE_URL fails later, at the
// moment it is used (signing a token, running a query), not here.
require('dotenv').config();

const config = {
  port: Number(process.env.PORT) || 5000,
  databaseUrl: process.env.DATABASE_URL || '',
  jwtSecret: process.env.JWT_SECRET || '',
  groqApiKey: process.env.GROQ_API_KEY || '',
  groqModel: process.env.GROQ_MODEL || '',
  nodeEnv: process.env.NODE_ENV || 'development',
};

module.exports = config;
