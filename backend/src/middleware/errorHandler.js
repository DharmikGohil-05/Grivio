// Central error handler. Add domain errors in later phases.
// Any error passed to next(err) from a controller/service lands here, so
// every failure response shares one shape: { success, message }.
// Express identifies error middleware by its FOUR parameters — `next` is
// unused but must remain in the signature, or Express treats this as a
// normal middleware and it would never run.
// err.statusCode is a convention set by services for expected problems
// (404, 409, ...); anything without one is an unexpected bug, so we fall
// back to 500 and never leak the raw error to the client.
// eslint-disable-next-line no-unused-vars
module.exports = (err, req, res, next) => {
  console.error(err);
  const status = err.statusCode || 500;
  res.status(status).json({
    success: false,
    message: err.message || 'Internal server error',
  });
};
