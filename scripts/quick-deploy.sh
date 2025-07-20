#!/bin/bash

# Quick OneDev Enterprise Deployment
# For VPS with existing Docker

set -e

echo "🚀 Quick OneDev Enterprise Deployment"
echo "====================================="

# Create onedev user if not exists
if ! id "onedev" &>/dev/null; then
    echo "👤 Creating onedev user..."
    useradd -m -s /bin/bash onedev
    usermod -aG sudo onedev
fi

# Set up directories
echo "📁 Setting up directories..."
mkdir -p /opt/tiation/{data,logs,config}
chown -R onedev:onedev /opt/tiation

# Install docker-compose using pip3
echo "📦 Installing docker-compose..."
apt update
apt install -y python3-pip nginx
pip3 install docker-compose

# Create basic OneDev setup
echo "🔧 Creating OneDev configuration..."
mkdir -p /opt/tiation/onedev

cd /opt/tiation/onedev

# Create minimal docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  onedev:
    image: 1dev/server:12.0.1
    container_name: onedev
    restart: unless-stopped
    ports:
      - "6610:6610"
      - "6611:6611"
    volumes:
      - onedev_data:/opt/onedev
    environment:
      - hibernate_dialect=org.hibernate.dialect.HSQLDialect
      - hibernate_connection_driver_class=org.hsqldb.jdbc.JDBCDriver
      - hibernate_connection_url=jdbc:hsqldb:file:/opt/onedev/database/db;shutdown=true
      - hibernate_connection_username=sa
      - hibernate_connection_password=
    networks:
      - onedev

  postgres:
    image: postgres:15-alpine
    container_name: onedev-postgres
    restart: unless-stopped
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      - POSTGRES_DB=onedev
      - POSTGRES_USER=onedev
      - POSTGRES_PASSWORD=onedev123
    networks:
      - onedev

networks:
  onedev:
    driver: bridge

volumes:
  onedev_data:
    driver: local
  postgres_data:
    driver: local
EOF

# Configure firewall
echo "🔒 Configuring firewall..."
ufw allow 6610/tcp
ufw allow 6611/tcp
ufw allow 80/tcp
ufw allow 443/tcp

# Configure Nginx proxy
echo "🌐 Configuring Nginx..."
cat > /etc/nginx/sites-available/onedev << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:6610;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        client_max_body_size 100M;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }

    location /health {
        access_log off;
        return 200 "healthy\n";
    }
}
EOF

# Remove default site and enable onedev
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/onedev /etc/nginx/sites-enabled/

# Test and reload nginx
nginx -t && systemctl reload nginx

# Start OneDev
echo "🚀 Starting OneDev..."
docker-compose up -d

# Create management script
cat > /opt/tiation/manage.sh << 'EOF'
#!/bin/bash
cd /opt/tiation/onedev

case "$1" in
    start)
        docker-compose up -d
        ;;
    stop)
        docker-compose down
        ;;
    restart)
        docker-compose restart
        ;;
    logs)
        docker-compose logs -f ${2:-onedev}
        ;;
    status)
        docker-compose ps
        ;;
    shell)
        docker-compose exec onedev /bin/bash
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|logs|status|shell}"
        ;;
esac
EOF

chmod +x /opt/tiation/manage.sh

# Wait for OneDev to start
echo "⏳ Waiting for OneDev to start..."
sleep 30

# Check status
echo "📊 Service Status:"
docker ps

echo ""
echo "✅ OneDev Enterprise deployment completed!"
echo "======================================="
echo ""
echo "🌐 Access OneDev at: http://153.92.214.1"
echo "🔧 SSH Access: ssh -p 6611 onedev@153.92.214.1"
echo ""
echo "📊 Management commands:"
echo "   /opt/tiation/manage.sh status"
echo "   /opt/tiation/manage.sh logs"
echo "   /opt/tiation/manage.sh restart"
echo ""
echo "🎉 Setup your admin account at: http://153.92.214.1"
EOF

chmod +x /Users/tiaastor/Github/tiation-repos/onedev/scripts/quick-deploy.sh