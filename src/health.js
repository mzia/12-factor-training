const { Pool } = require('pg');
const redis = require('redis');
const config = require('../config');

let dbPool;
let redisClient;

async function initConnections() {
  if (!dbPool) {
    dbPool = new Pool({
      connectionString: config.database.url,
      ...config.database.pool
    });
  }
  
  if (!redisClient) {
    redisClient = redis.createClient({
      url: config.redis.url
    });
    await redisClient.connect().catch(() => {});
  }
}

async function checkDatabase() {
  try {
    if (!dbPool) return { status: 'not initialized' };
    const result = await dbPool.query('SELECT 1');
    return { status: 'healthy' };
  } catch (error) {
    return { status: 'unhealthy', error: error.message };
  }
}

async function checkRedis() {
  try {
    if (!redisClient) return { status: 'not initialized' };
    await redisClient.ping();
    return { status: 'healthy' };
  } catch (error) {
    return { status: 'unhealthy', error: error.message };
  }
}

function setupHealthChecks(app) {
  app.get('/health', async (req, res) => {
    await initConnections();
    
    const health = {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      checks: {
        database: await checkDatabase(),
        redis: await checkRedis()
      }
    };
    
    const isHealthy = health.checks.database.status === 'healthy' || 
                     health.checks.redis.status === 'healthy';
    
    health.status = isHealthy ? 'healthy' : 'degraded';
    res.status(isHealthy ? 200 : 503).json(health);
  });
}

module.exports = { setupHealthChecks };
