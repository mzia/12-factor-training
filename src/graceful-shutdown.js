const config = require('../config');

let isShuttingDown = false;
const connections = new Set();

function setupGracefulShutdown(server) {
  // Track connections
  server.on('connection', (connection) => {
    connections.add(connection);
    connection.on('close', () => {
      connections.delete(connection);
    });
  });
  
  // Graceful shutdown handler
  const gracefulShutdown = (signal) => {
    console.log(`\\n${signal} received. Starting graceful shutdown...`);
    
    if (isShuttingDown) {
      console.log('Shutdown already in progress');
      return;
    }
    
    isShuttingDown = true;
    
    // Stop accepting new connections
    server.close((err) => {
      if (err) {
        console.error('Error during server close:', err);
        process.exit(1);
      }
      
      console.log('✅ Server closed to new connections');
      
      // Close existing connections
      console.log(`Closing ${connections.size} existing connections...`);
      connections.forEach((connection) => {
        connection.end();
      });
      
      // Force close after timeout
      setTimeout(() => {
        connections.forEach((connection) => {
          connection.destroy();
        });
      }, 5000);
      
      // Cleanup resources
      cleanupResources().then(() => {
        console.log('✅ All resources cleaned up');
        console.log('👋 Graceful shutdown complete');
        process.exit(0);
      }).catch((error) => {
        console.error('Error during cleanup:', error);
        process.exit(1);
      });
    });
    
    // Force shutdown after 30 seconds
    setTimeout(() => {
      console.error('⚠️  Forcing shutdown after timeout');
      process.exit(1);
    }, 30000);
  };
  
  // Register shutdown handlers
  process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
  process.on('SIGINT', () => gracefulShutdown('SIGINT'));
  
  // Handle uncaught errors
  process.on('uncaughtException', (error) => {
    console.error('Uncaught Exception:', error);
    gracefulShutdown('UNCAUGHT_EXCEPTION');
  });
  
  process.on('unhandledRejection', (reason, promise) => {
    console.error('Unhandled Rejection at:', promise, 'reason:', reason);
    gracefulShutdown('UNHANDLED_REJECTION');
  });
}

async function cleanupResources() {
  const cleanupTasks = [];
  
  // Add cleanup tasks here
  // e.g., close database connections, flush caches, etc.
  
  return Promise.all(cleanupTasks);
}

module.exports = { setupGracefulShutdown };
