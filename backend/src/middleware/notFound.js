// Terminal middleware, registered after every route in app.js: any
// request that matched no route lands here and still gets the project's
// standard { success, message } JSON instead of an HTML error page.
module.exports = (req, res) => {
  res.status(404).json({
    success: false,
    message: `Route not found: ${req.method} ${req.originalUrl}`,
  });
};
