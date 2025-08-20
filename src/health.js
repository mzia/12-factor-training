const { Pool } = require('pg');
const redis = require('redis');
const config = require('../config');

let dbPool;
let redisClient;

async function initConnections() {
  // Initialize database connection
  if (!dbPool) {
    dbPool = new Pool({
      connectionString: config.database.url,
      ...config.database.pool
    });
  }
  
  // Initialize Redis connection
  if (!redisClient) {
    redisClient = redis.createClient({
      url: config.redis.url
    });
    await redisClient.connect();
  }
}

async function checkDatabase() {
  try {
    const result = await dbPool.query('SELECT 1');
    return { status: 'healthy', latency: result.duration || 0 };
  } catch (error) {
    return { status: 'unhealthy', error: error.message };
  }
}

async function checkRedis() {
  try {
    const start = Date.now();
    await redisClient.ping();
    return { status: 'healthy', latency: Date.now() - start };
  } catch (error) {
    return { status: 'unhealthy', error: error.message };
  }
}

function setupHealthChecks(app) {
  // Liveness probe - is the app running?
  app.get('/health/live', (req, res) => {
    res.status(200).json({
      status: 'alive',
      timestamp: new Date().toISOString(),
      uptime: process.uptime()
    });
  });
  
  // Readiness probe - is the app ready to serve traffic?
  app.get('/health/ready', async (req, res) => {
    await initConnections();
    
    const checks = {
      database: await checkDatabase(),
      redis: await checkRedis(),
      memory: {
        used: process.memoryUsage().heapUsed / 1024 / 1024,
        limit: process.memoryUsage().heapTotal / 1024 / 1024
      }
    };
    
    const isHealthy = checks.database.status === 'healthy' && 
                     checks.redis.status === 'healthy';
    
    res.status(isHealthy ? 200 : 503).json({
      status: isHealthy ? 'ready' : 'not ready',
      checks,
      timestamp: new Date().toISOString()
    });
  });
  
  // Combined health check
  app.get('/health', async (req, res) => {
    await initConnections();
    
    const health = {
      status: 'healthy',
      version: process.env.APP_VERSION || '1.0.0',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      checks: {
        database: await checkDatabase(),
        redis: await checkRedis()
      }
    };
    
    const isHealthy = health.checks.database.status === 'healthy' && 
                     health.checks.redis.status === 'healthy';
    
    health.status = isHealthy ? 'healthy' : 'degraded';
    
    res.status(isHealthy ? 200 : 503).json(health);
  });
}

module.exports = { setupHealthChecks };
