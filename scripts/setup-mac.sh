#!/bin/bash

set -e  # Exit on error

echo "🚀 Setting up 12-Factor Training App on macOS"
echo "============================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker Desktop for Mac first."
    echo "Download from: https://www.docker.com/products/docker-desktop/"
    exit 1
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    print_error "Docker is not running. Please start Docker Desktop."
    exit 1
fi

print_status "Docker is installed and running"

# Check for Node.js (optional, for local development)
if ! command -v node &> /dev/null; then
    print_warning "Node.js is not installed locally. Installing via Homebrew..."
    if ! command -v brew &> /dev/null; then
        echo "Installing Homebrew first..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    brew install node
fi

print_status "Node.js $(node -v) is available"

# Create project structure
echo ""
echo "📁 Creating project structure..."
mkdir -p config src public scripts k8s terraform

# Create package.json
print_status "Creating package.json..."
cat > package.json << 'EOF'
{
  "name": "12-factor-training-app",
  "version": "1.0.0",
  "description": "12-Factor Application Training Platform",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js",
    "test": "jest",
    "migrate": "node scripts/migrate.js",
    "seed": "node scripts/seed.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "pg": "^8.11.3",
    "redis": "^4.6.7",
    "prom-client": "^14.2.0",
    "winston": "^3.10.0",
    "dotenv": "^16.3.1",
    "helmet": "^7.0.0",
    "compression": "^1.7.4",
    "cors": "^2.8.5"
  },
  "devDependencies": {
    "nodemon": "^3.0.1",
    "jest": "^29.6.2",
    "supertest": "^6.3.3"
  },
  "engines": {
    "node": ">=18.0.0"
  }
}
EOF

# Create server.js
print_status "Creating server.js..."
cat > server.js << 'EOF'
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
      { id: 9, name: 'Disposability', description: 'Fast startup and graceful shutdown' },
      { id: 10, name: 'Dev/Prod Parity', description: 'Keep environments similar' },
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
EOF

# Create Dockerfile (fixed version)
print_status "Creating Dockerfile..."
cat > Dockerfile << 'EOF'
FROM node:18-alpine

# Install dumb-init for proper signal handling
RUN apk add --no-cache dumb-init

# Create app directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy application files
COPY . .

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (r) => {r.statusCode === 200 ? process.exit(0) : process.exit(1)})"

# Start the application
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "server.js"]
EOF

# Create docker-compose.yml
print_status "Creating docker-compose.yml..."
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  web:
    build: .
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=development
      - PORT=3000
      - DATABASE_URL=postgres://user:password@db:5432/twelveapp
      - REDIS_URL=redis://redis:6379
      - LOG_LEVEL=debug
    depends_on:
      - db
      - redis
    volumes:
      - .:/app
      - /app/node_modules
    networks:
      - app-network
    restart: unless-stopped

  db:
    image: postgres:14-alpine
    environment:
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=password
      - POSTGRES_DB=twelveapp
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./scripts/init.sql:/docker-entrypoint-initdb.d/init.sql
    ports:
      - "5432:5432"
    networks:
      - app-network
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    ports:
      - "6379:6379"
    networks:
      - app-network
    restart: unless-stopped

  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./config/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
    networks:
      - app-network
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3001:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana_data:/var/lib/grafana
    depends_on:
      - prometheus
    networks:
      - app-network
    restart: unless-stopped

networks:
  app-network:
    driver: bridge

volumes:
  postgres_data:
  redis_data:
  prometheus_data:
  grafana_data:
EOF

# Create config/index.js
print_status "Creating config files..."
cat > config/index.js << 'EOF'
module.exports = {
  port: parseInt(process.env.PORT || '3000', 10),
  env: process.env.NODE_ENV || 'development',
  
  database: {
    url: process.env.DATABASE_URL || 'postgres://user:password@localhost:5432/twelveapp',
    pool: {
      min: parseInt(process.env.DB_POOL_MIN || '2', 10),
      max: parseInt(process.env.DB_POOL_MAX || '10', 10),
      idleTimeoutMillis: parseInt(process.env.DB_IDLE_TIMEOUT || '30000', 10),
    }
  },
  
  redis: {
    url: process.env.REDIS_URL || 'redis://localhost:6379',
    ttl: parseInt(process.env.REDIS_TTL || '3600', 10),
  },
  
  logging: {
    level: process.env.LOG_LEVEL || 'info',
    format: process.env.LOG_FORMAT || 'json',
  }
};
EOF

# Create prometheus.yml
cat > config/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'node-app'
    static_configs:
      - targets: ['web:3000']
    metrics_path: '/metrics'
    scrape_interval: 5s

  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
EOF

# Create src/health.js
print_status "Creating source files..."
cat > src/health.js << 'EOF'
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
EOF

# Create src/metrics.js
cat > src/metrics.js << 'EOF'
const promClient = require('prom-client');

const register = new promClient.Registry();
promClient.collectDefaultMetrics({ register });

const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_ms',
  help: 'Duration of HTTP requests in milliseconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 5, 15, 50, 100, 500, 1000, 5000]
});

const httpRequestTotal = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code']
});

register.registerMetric(httpRequestDuration);
register.registerMetric(httpRequestTotal);

function metricsMiddleware(req, res, next) {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    const route = req.route ? req.route.path : req.url;
    
    httpRequestDuration
      .labels(req.method, route, res.statusCode.toString())
      .observe(duration);
    
    httpRequestTotal
      .labels(req.method, route, res.statusCode.toString())
      .inc();
  });
  
  next();
}

function setupMetrics(app) {
  app.get('/metrics', async (req, res) => {
    try {
      res.set('Content-Type', register.contentType);
      const metrics = await register.metrics();
      res.end(metrics);
    } catch (error) {
      res.status(500).end(error.message);
    }
  });
}

module.exports = { setupMetrics, metricsMiddleware, register };
EOF

# Create src/graceful-shutdown.js
cat > src/graceful-shutdown.js << 'EOF'
function setupGracefulShutdown(server) {
  const gracefulShutdown = (signal) => {
    console.log(`${signal} received. Starting graceful shutdown...`);
    
    server.close((err) => {
      if (err) {
        console.error('Error during server close:', err);
        process.exit(1);
      }
      
      console.log('Server closed to new connections');
      process.exit(0);
    });
    
    setTimeout(() => {
      console.error('Forcing shutdown after timeout');
      process.exit(1);
    }, 30000);
  };
  
  process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
  process.on('SIGINT', () => gracefulShutdown('SIGINT'));
}

module.exports = { setupGracefulShutdown };
EOF

# Create src/middleware.js
cat > src/middleware.js << 'EOF'
const winston = require('winston');

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.json(),
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.json()
      )
    })
  ]
});

function requestLogger(req, res, next) {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    logger.info({
      method: req.method,
      url: req.url,
      status: res.statusCode,
      duration
    });
  });
  
  next();
}

function errorHandler(err, req, res, next) {
  logger.error({
    error: err.message,
    stack: err.stack,
    url: req.url,
    method: req.method
  });
  
  res.status(err.status || 500).json({
    error: {
      message: err.message || 'Internal server error',
      status: err.status || 500
    }
  });
}

module.exports = { requestLogger, errorHandler, logger };
EOF

# Create public/index.html
print_status "Creating public files..."
cat > public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>12-Factor App Training Platform</title>
    <style>
        body {
            font-family: 'Courier New', monospace;
            background: linear-gradient(135deg, #0f0f0f 0%, #1a1a2e 100%);
            color: #e0e0e0;
            padding: 20px;
            min-height: 100vh;
        }
        h1 { 
            color: #00ff88; 
            text-shadow: 0 0 10px rgba(0, 255, 136, 0.5);
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        .status { 
            background: rgba(0,0,0,0.5); 
            padding: 20px; 
            border-radius: 10px;
            margin: 20px 0;
            border: 1px solid #333;
        }
        .factor {
            background: rgba(0,255,136,0.1);
            border: 1px solid #00ff88;
            padding: 15px;
            margin: 10px 0;
            border-radius: 5px;
            transition: all 0.3s;
        }
        .factor:hover {
            background: rgba(0,255,136,0.2);
            transform: translateX(5px);
        }
        .factor strong {
            color: #00ff88;
            font-size: 1.1em;
        }
        .loading {
            color: #888;
            font-style: italic;
        }
        .healthy { color: #00ff88; }
        .unhealthy { color: #ff4444; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🎓 12-Factor Application Training Platform</h1>
        
        <div class="status">
            <h2>System Status</h2>
            <div id="status-content" class="loading">Loading...</div>
        </div>
        
        <div id="factors">
            <h2>The 12 Factors</h2>
            <div id="factors-content" class="loading">Loading factors...</div>
        </div>
    </div>
    
    <script>
        // Check health endpoint
        fetch('/health')
            .then(res => res.json())
            .then(data => {
                const statusClass = data.status === 'healthy' ? 'healthy' : 'unhealthy';
                document.getElementById('status-content').innerHTML = `
                    <p>Status: <span class="${statusClass}">${data.status}</span></p>
                    <p>Uptime: ${Math.floor(data.uptime)}s</p>
                    <p>Database: <span class="${data.checks?.database?.status === 'healthy' ? 'healthy' : 'unhealthy'}">${data.checks?.database?.status || 'unknown'}</span></p>
                    <p>Redis: <span class="${data.checks?.redis?.status === 'healthy' ? 'healthy' : 'unhealthy'}">${data.checks?.redis?.status || 'unknown'}</span></p>
                `;
            })
            .catch(err => {
                document.getElementById('status-content').innerHTML = '<span class="unhealthy">Error loading status</span>';
            });
            
        // Load factors
        fetch('/api/factors')
            .then(res => res.json())
            .then(data => {
                const container = document.getElementById('factors-content');
                container.innerHTML = '';
                data.factors.forEach(factor => {
                    const factorDiv = document.createElement('div');
                    factorDiv.className = 'factor';
                    factorDiv.innerHTML = `
                        <strong>${factor.id}. ${factor.name}</strong><br>
                        ${factor.description}
                    `;
                    container.appendChild(factorDiv);
                });
            })
            .catch(err => {
                document.getElementById('factors-content').innerHTML = '<span class="unhealthy">Error loading factors</span>';
            });
    </script>
</body>
</html>
EOF

# Create database init script
print_status "Creating database scripts..."
cat > scripts/init.sql << 'EOF'
CREATE TABLE IF NOT EXISTS factors (
    id SERIAL PRIMARY KEY,
    number INTEGER NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO factors (number, name, description) VALUES
(1, 'Codebase', 'One codebase tracked in revision control, many deploys'),
(2, 'Dependencies', 'Explicitly declare and isolate dependencies'),
(3, 'Config', 'Store config in the environment'),
(4, 'Backing Services', 'Treat backing services as attached resources'),
(5, 'Build, Release, Run', 'Strictly separate build and run stages'),
(6, 'Processes', 'Execute the app as one or more stateless processes'),
(7, 'Port Binding', 'Export services via port binding'),
(8, 'Concurrency', 'Scale out via the process model'),
(9, 'Disposability', 'Maximize robustness with fast startup and graceful shutdown'),
(10, 'Dev/Prod Parity', 'Keep development, staging, and production as similar as possible'),
(11, 'Logs', 'Treat logs as event streams'),
(12, 'Admin Processes', 'Run admin/management tasks as one-off processes')
ON CONFLICT DO NOTHING;
EOF

# Create .env file
print_status "Creating .env file..."
cat > .env << 'EOF'
NODE_ENV=development
PORT=3000
DATABASE_URL=postgres://user:password@localhost:5432/twelveapp
REDIS_URL=redis://localhost:6379
LOG_LEVEL=debug
EOF

# Create .dockerignore
print_status "Creating .dockerignore..."
cat > .dockerignore << 'EOF'
node_modules
npm-debug.log
.env
.git
.gitignore
README.md
.DS_Store
.vscode
.idea
EOF

# Create .gitignore
print_status "Creating .gitignore..."
cat > .gitignore << 'EOF'
node_modules/
.env
.DS_Store
*.log
dist/
build/
.vscode/
.idea/
coverage/
EOF

# Install npm dependencies
print_status "Installing npm dependencies..."
npm install

# Stop any existing containers
print_status "Cleaning up existing containers..."
docker-compose down 2>/dev/null || true

# Build Docker images
print_status "Building Docker images..."
docker-compose build

# Start services
print_status "Starting services..."
docker-compose up -d

# Wait for services to be ready
echo ""
echo "⏳ Waiting for services to be ready..."
sleep 10

# Check service health
echo ""
echo "🏥 Checking service health..."
if curl -f http://localhost:3000/health 2>/dev/null; then
    print_status "Application is healthy!"
else
    print_warning "Application may still be starting up..."
fi

# Final output
echo ""
echo "============================================="
print_status "Setup complete!"
echo ""
echo "📊 Access points:"
echo "  - Application: http://localhost:3000"
echo "  - Health Check: http://localhost:3000/health"
echo "  - Metrics: http://localhost:3000/metrics"
echo "  - Prometheus: http://localhost:9090"
echo "  - Grafana: http://localhost:3001 (admin/admin)"
echo "  - PostgreSQL: localhost:5432 (user/password)"
echo "  - Redis: localhost:6379"
echo ""
echo "🎯 Next steps:"
echo "  1. Open http://localhost:3000 in your browser"
echo "  2. Check logs: docker-compose logs -f"
echo "  3. Stop services: docker-compose down"
echo "  4. Restart services: docker-compose up -d"
echo ""
echo "📚 Learn more about the 12 factors at https://12factor.net"
echo "============================================="