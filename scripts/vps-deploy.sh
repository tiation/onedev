#!/bin/bash

# Tiation OneDev Enterprise VPS Deployment Script
# For VPS: 153.92.214.1

set -e

echo "🚀 Deploying Tiation OneDev Enterprise to VPS 153.92.214.1"
echo "============================================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run this script as root"
    echo "Run: sudo $0"
    exit 1
fi

# Detect existing services
echo "🔍 Checking existing services..."
EXISTING_GIT=""
EXISTING_NGINX=""
EXISTING_DOCKER=""

if systemctl is-active --quiet nginx 2>/dev/null; then
    EXISTING_NGINX="yes"
    echo "📋 Found existing Nginx service"
fi

if systemctl is-active --quiet docker 2>/dev/null; then
    EXISTING_DOCKER="yes"
    echo "📋 Found existing Docker service"
fi

if pgrep -f "git" > /dev/null; then
    EXISTING_GIT="yes"
    echo "📋 Found existing Git processes"
    ps aux | grep -i git | grep -v grep
fi

# Check available ports
echo "🔌 Checking port availability..."
ONEDEV_PORT=6610
IDE_BRIDGE_PORT=8080
MONITORING_PORT=3000

if netstat -tlnp 2>/dev/null | grep -q ":$ONEDEV_PORT "; then
    ONEDEV_PORT=6612
    echo "⚠️  Port 6610 in use, using $ONEDEV_PORT"
fi

if netstat -tlnp 2>/dev/null | grep -q ":$IDE_BRIDGE_PORT "; then
    IDE_BRIDGE_PORT=8082
    echo "⚠️  Port 8080 in use, using $IDE_BRIDGE_PORT"
fi

# Update system
echo "📦 Updating system packages..."
apt update && apt upgrade -y

# Install required packages
echo "🛠️ Installing required packages..."
apt install -y \
    curl wget git build-essential software-properties-common \
    docker.io docker-compose \
    nginx certbot python3-certbot-nginx \
    postgresql-client redis-tools \
    htop iotop unzip jq \
    fail2ban ufw

# Configure Docker
if [ "$EXISTING_DOCKER" != "yes" ]; then
    echo "🐳 Configuring Docker..."
    systemctl enable docker
    systemctl start docker
fi

# Create onedev user if not exists
if ! id "onedev" &>/dev/null; then
    echo "👤 Creating onedev user..."
    useradd -m -s /bin/bash onedev
    usermod -aG docker onedev
    usermod -aG sudo onedev
fi

# Set up application directories
echo "📁 Setting up directories..."
mkdir -p /opt/tiation/{onedev,ssl,monitoring,backups,logs}
chown -R onedev:onedev /opt/tiation

# Clone OneDev Enterprise repository
echo "📦 Setting up OneDev Enterprise repository..."
cd /opt/tiation
if [ ! -d "onedev-enterprise" ]; then
    sudo -u onedev git clone https://github.com/tiation/onedev.git onedev-enterprise
    cd onedev-enterprise
else
    echo "Repository already exists, pulling latest changes..."
    cd onedev-enterprise
    sudo -u onedev git pull origin main
fi

# Create environment file
echo "📄 Creating environment configuration..."
cat > /opt/tiation/.env << EOF
# Tiation OneDev Enterprise Configuration
NODE_ENV=production
DOMAIN=153.92.214.1

# Port Configuration
ONEDEV_PORT=$ONEDEV_PORT
IDE_BRIDGE_PORT=$IDE_BRIDGE_PORT
MONITORING_PORT=$MONITORING_PORT

# Database Configuration
DB_USERNAME=onedev_user
DB_PASSWORD=$(openssl rand -base64 32)
POSTGRES_DB=onedev_enterprise

# Redis Configuration  
REDIS_PASSWORD=$(openssl rand -base64 32)

# GitHub Integration
GITHUB_WEBHOOK_SECRET=$(openssl rand -base64 32)

# Supabase Configuration (UPDATE THESE WITH YOUR VALUES)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_supabase_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key

# Security
JWT_SECRET=$(openssl rand -base64 64)
GRAFANA_PASSWORD=$(openssl rand -base64 16)

# Generated at: $(date)
EOF

chown onedev:onedev /opt/tiation/.env
chmod 600 /opt/tiation/.env

# Update docker-compose with correct ports
echo "🔧 Configuring Docker Compose..."
cd /opt/tiation/onedev-enterprise

# Create production docker-compose with adjusted ports
cat > docker-compose.production.yml << EOF
version: '3.8'

services:
  onedev-server:
    build:
      context: .
      dockerfile: server-product/docker/Dockerfile.server
    container_name: tiation-onedev-server
    restart: unless-stopped
    ports:
      - "$ONEDEV_PORT:6610"
      - "2222:6611"  # SSH on alternate port to avoid conflicts
    volumes:
      - onedev_data:/opt/onedev
      - onedev_logs:/opt/onedev/logs
      - ./enterprise-config:/opt/onedev/conf/enterprise
    environment:
      - JAVA_OPTS=-Xmx2g -Dhibernate.connection.url=jdbc:postgresql://supabase-db:5432/onedev_enterprise -Dhibernate.connection.username=\${DB_USERNAME} -Dhibernate.connection.password=\${DB_PASSWORD}
      - ONEDEV_SERVER_URL=http://\${DOMAIN}:\${ONEDEV_PORT}
      - GITHUB_WEBHOOK_SECRET=\${GITHUB_WEBHOOK_SECRET}
    depends_on:
      - supabase-db
      - redis
    networks:
      - tiation-network

  supabase-db:
    image: postgres:15-alpine
    container_name: tiation-supabase-db
    restart: unless-stopped
    ports:
      - "5433:5432"  # External port to avoid conflicts
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./sql/init-onedev-schema.sql:/docker-entrypoint-initdb.d/01-init-onedev-schema.sql
    environment:
      - POSTGRES_DB=\${POSTGRES_DB}
      - POSTGRES_USER=\${DB_USERNAME}
      - POSTGRES_PASSWORD=\${DB_PASSWORD}
    networks:
      - tiation-network

  redis:
    image: redis:7-alpine
    container_name: tiation-redis
    restart: unless-stopped
    ports:
      - "6380:6379"  # External port to avoid conflicts
    volumes:
      - redis_data:/data
    command: redis-server --appendonly yes --requirepass \${REDIS_PASSWORD}
    networks:
      - tiation-network

  ide-bridge:
    build:
      context: ./ide-bridge
      dockerfile: Dockerfile
    container_name: tiation-ide-bridge
    restart: unless-stopped
    ports:
      - "$IDE_BRIDGE_PORT:8080"
    environment:
      - ONEDEV_URL=http://onedev-server:6610
      - SUPABASE_URL=\${SUPABASE_URL}
      - SUPABASE_ANON_KEY=\${SUPABASE_ANON_KEY}
    depends_on:
      - onedev-server
    networks:
      - tiation-network

  grafana:
    image: grafana/grafana:latest
    container_name: tiation-grafana
    restart: unless-stopped
    ports:
      - "$MONITORING_PORT:3000"
    volumes:
      - grafana_data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=\${GRAFANA_PASSWORD}
    networks:
      - tiation-network

networks:
  tiation-network:
    driver: bridge

volumes:
  onedev_data:
    driver: local
  onedev_logs:
    driver: local
  postgres_data:
    driver: local
  redis_data:
    driver: local
  grafana_data:
    driver: local
EOF

# Configure firewall to work with existing services
echo "🔒 Configuring firewall..."
ufw --force enable
ufw allow ssh
ufw allow 80
ufw allow 443
ufw allow $ONEDEV_PORT/tcp
ufw allow 2222/tcp  # OneDev SSH
ufw allow $IDE_BRIDGE_PORT/tcp
ufw allow $MONITORING_PORT/tcp

# Configure Nginx proxy (if not conflicting)
if [ "$EXISTING_NGINX" = "yes" ]; then
    echo "⚠️  Existing Nginx detected - creating backup and adding OneDev configuration"
    cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup.$(date +%Y%m%d_%H%M%S)
fi

# Create OneDev Nginx configuration
cat > /etc/nginx/sites-available/onedev << EOF
server {
    listen 80;
    server_name $DOMAIN 153.92.214.1;

    # OneDev main application
    location / {
        proxy_pass http://127.0.0.1:$ONEDEV_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        client_max_body_size 100M;
    }

    # IDE Bridge
    location /ide/ {
        proxy_pass http://127.0.0.1:$IDE_BRIDGE_PORT/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # Monitoring
    location /monitoring/ {
        proxy_pass http://127.0.0.1:$MONITORING_PORT/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Enable the site
ln -sf /etc/nginx/sites-available/onedev /etc/nginx/sites-enabled/

# Test and reload Nginx
nginx -t && systemctl reload nginx

# Create Docker network
echo "🌐 Creating Docker network..."
docker network create tiation-network 2>/dev/null || echo "Network already exists"

# Build and start services
echo "🚀 Building and starting services..."
cd /opt/tiation/onedev-enterprise

# Export environment variables
export $(cat /opt/tiation/.env | grep -v '^#' | xargs)

# Start services
sudo -u onedev docker-compose -f docker-compose.production.yml up -d --build

# Create systemd service
echo "🔄 Creating systemd service..."
cat > /etc/systemd/system/tiation-onedev.service << EOF
[Unit]
Description=Tiation OneDev Enterprise Platform
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/tiation/onedev-enterprise
EnvironmentFile=/opt/tiation/.env
ExecStart=/usr/bin/docker-compose -f docker-compose.production.yml up -d
ExecStop=/usr/bin/docker-compose -f docker-compose.production.yml down
TimeoutStartSec=0
User=onedev
Group=onedev

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable tiation-onedev

# Create management script
cat > /opt/tiation/manage.sh << 'EOF'
#!/bin/bash
cd /opt/tiation/onedev-enterprise
export $(cat /opt/tiation/.env | grep -v '^#' | xargs)

case "$1" in
    status)
        docker-compose -f docker-compose.production.yml ps
        ;;
    logs)
        docker-compose -f docker-compose.production.yml logs -f --tail=100 ${2:-}
        ;;
    restart)
        docker-compose -f docker-compose.production.yml restart ${2:-}
        ;;
    update)
        git pull origin main
        docker-compose -f docker-compose.production.yml up -d --build
        ;;
    backup)
        /usr/local/bin/backup-tiation-onedev.sh
        ;;
    shell)
        docker-compose -f docker-compose.production.yml exec ${2:-onedev-server} /bin/bash
        ;;
    *)
        echo "Usage: $0 {status|logs|restart|update|backup|shell}"
        echo "Examples:"
        echo "  $0 status           # Show service status"
        echo "  $0 logs onedev-server # Show logs for specific service"
        echo "  $0 restart          # Restart all services"
        echo "  $0 update           # Update and rebuild"
        echo "  $0 shell onedev-server # Access container shell"
        exit 1
        ;;
esac
EOF

chmod +x /opt/tiation/manage.sh
chown onedev:onedev /opt/tiation/manage.sh

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 30

# Show status
echo "📊 Service Status:"
/opt/tiation/manage.sh status

# Show important information
echo ""
echo "✅ Tiation OneDev Enterprise deployment completed!"
echo "=============================================="
echo ""
echo "🌐 Access URLs:"
echo "   OneDev:     http://153.92.214.1:$ONEDEV_PORT"
echo "   IDE Bridge: http://153.92.214.1:$IDE_BRIDGE_PORT"
echo "   Monitoring: http://153.92.214.1:$MONITORING_PORT"
echo ""
echo "📊 Management Commands:"
echo "   Status:     /opt/tiation/manage.sh status"
echo "   Logs:       /opt/tiation/manage.sh logs"
echo "   Restart:    /opt/tiation/manage.sh restart"
echo "   Update:     /opt/tiation/manage.sh update"
echo ""
echo "🔐 Important Files:"
echo "   Environment: /opt/tiation/.env"
echo "   Logs:        /opt/tiation/onedev-enterprise/"
echo ""
echo "⚠️  NEXT STEPS:"
echo "1. Update Supabase credentials in /opt/tiation/.env"
echo "2. Configure GitHub webhook URL: http://153.92.214.1:$ONEDEV_PORT/api/github-webhook"
echo "3. Set up SSL certificate: certbot --nginx -d 153.92.214.1"
echo "4. Create your first admin user at: http://153.92.214.1:$ONEDEV_PORT"
echo ""
echo "🎉 Happy coding with Tiation OneDev Enterprise!"
EOF

chmod +x /Users/tiaastor/Github/tiation-repos/onedev/scripts/vps-deploy.sh