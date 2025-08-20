#!/bin/bash

echo "🚀 Setting up 12-Factor Training App on macOS"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker Desktop for Mac first."
    echo "Download from: https://www.docker.com/products/docker-desktop/"
    exit 1
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo "❌ Docker is not running. Please start Docker Desktop."
    exit 1
fi

echo "✅ Docker is installed and running"

# Install Node.js if not present (using Homebrew)
if ! command -v node &> /dev/null; then
    echo "📦 Installing Node.js..."
    if ! command -v brew &> /dev/null; then
        echo "Installing Homebrew first..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    brew install node
fi

echo "✅ Node.js $(node -v) is installed"

# Install dependencies
echo "📦 Installing npm dependencies..."
npm install

# Create .env file from example
if [ ! -f .env ]; then
    echo "📝 Creating .env file..."
    cp .env.example .env
    echo "✅ .env file created. Please update with your values."
fi

# Build Docker images
echo "🐳 Building Docker images..."
docker-compose build

# Start services
echo "🚀 Starting services..."
docker-compose up -d

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 10

# Check service health
echo "🏥 Checking service health..."
curl -f http://localhost:3000/health || echo "⚠️  Service not yet ready"

echo "✅ Setup complete!"
echo ""
echo "📊 Access points:"
echo "  - Application: http://localhost:3000"
echo "  - Prometheus: http://localhost:9090"
echo "  - Grafana: http://localhost:3001 (admin/admin)"
echo "  - PostgreSQL: localhost:5432"
echo "  - Redis: localhost:6379"
echo ""
echo "🎯 Next steps:"
echo "  1. Open http://localhost:3000 in your browser"
echo "  2. Check the health endpoint: http://localhost:3000/health"
echo "  3. View metrics: http://localhost:3000/metrics"
echo "  4. Access Grafana dashboards: http://localhost:3001"
