require('dotenv').config();
const express = require('express');
const path = require('path');
const helmet = require('helmet');
const compression = require('compression');
const cors = require('cors');

const config = require('./config');
const { setupMetrics, metricsMiddleware } = require('./src/metrics');
const { setupHealthChecks } = require('./src/health');
const { setupGracefulShutdown } = require('./src/graceful-shutdown');
const { errorHandler, requestLogger } = require('./src/middleware');

const app = express();
const PORT = config.port;

// Security middleware
app.use(helmet());
app.use(cors());
app.use(compression());

// Body parsing
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Logging and metrics
app.use(requestLogger);
app.use(metricsMiddleware);

// Serve static files
app.use(express.static('public'));

// Setup metrics endpoint
setupMetrics(app);

// Setup health checks
setupHealthChecks(app);

// Main route
app.get('/api/factors', (req, res) => {
  res.json({
    factors: [
      { id: 1, name: 'Codebase', description: 'One codebase tracked in revision control' },
      { id: 2, name: 'Dependencies', description: 'Explicitly declare dependencies' },
      { id: 3, name: 'Config', description: 'Store config in the environment' },
      { id: 4, name: 'Backing Services', description: 'Treat backing services as attached resources' },
      { id: 5, name: 'Build, Release, Run', description: 'Strictly separate build and run stages' },
      { id: 6, name: 'Processes', description: 'Execute app as stateless processes' },
      { id: 7, name: 'Port Binding', description: 'Export services via port binding' },
      { id: 8, name: 'Concurrency', description: 'Scale out via the process model' },
      { id: 9, name: 'Disposability', description: 'Maximize robustness with fast startup and graceful shutdown' },
      { id: 10, name: 'Dev/Prod Parity', description: 'Keep development and production similar' },
      { id: 11, name: 'Logs', description: 'Treat logs as event streams' },
      { id: 12, name: 'Admin Processes', description: 'Run admin tasks as one-off processes' }
    ]
  });
});

// Error handling
app.use(errorHandler);

// Start server
const server = app.listen(PORT, () => {
  console.log(`🚀 12-Factor Training App running on port ${PORT}`);
  console.log(`📊 Metrics available at http://localhost:${PORT}/metrics`);
  console.log(`🏥 Health check at http://localhost:${PORT}/health`);
});

// Setup graceful shutdown
setupGracefulShutdown(server);

module.exports = app;
