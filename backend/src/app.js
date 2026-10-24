const express = require('express');
const cors = require('cors');

const healthRoutes = require('./routes/health.routes');
const authRoutes = require('./routes/auth.routes');
const profileRoutes = require('./routes/profile.routes');
const goalRoutes = require('./routes/goal.routes');
const taskRoutes = require('./routes/task.routes');
const focusRoutes = require('./routes/focus.routes');
const progressRoutes = require('./routes/progress.routes');
const weeklyRoutes = require('./routes/weekly.routes');
const reflectionRoutes = require('./routes/reflection.routes');
const aiRoutes = require('./routes/ai.routes');
const notFound = require('./middleware/notFound');
const errorHandler = require('./middleware/errorHandler');

const app = express();

app.use(express.json());

// Permissive for local Flutter development; tighten for production (Phase 16).
app.use(cors());

app.use('/api/health', healthRoutes);
app.use('/api/auth', authRoutes);
app.use('/api/profile', profileRoutes);
app.use('/api', goalRoutes);
app.use('/api', taskRoutes);
app.use('/api', focusRoutes);
app.use('/api', progressRoutes);
app.use('/api', weeklyRoutes);
app.use('/api', reflectionRoutes);
app.use('/api', aiRoutes);
app.use(notFound);
app.use(errorHandler);

module.exports = app;
