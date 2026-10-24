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
