// Central error handler. Add domain errors in later phases.
// eslint-disable-next-line no-unused-vars
module.exports = (err, req, res, next) => {
  console.error(err);
  const status = err.statusCode || 500;
  res.status(status).json({
    success: false,
    message: err.message || 'Internal server error',
  });
};
