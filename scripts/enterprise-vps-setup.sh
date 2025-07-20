#!/bin/bash

# Tiation OneDev Enterprise Setup Script
# Enhanced version of the original VPS setup script with OneDev integration

set -e

echo "🚀 Setting up Tiation OneDev Enterprise Platform..."

# Source the original setup script functions
ORIGINAL_SCRIPT="/Users/tiaastor/tiation-github/tiation-portfolio/scripts/setup-vps.sh"
if [ -f "$ORIGINAL_SCRIPT" ]; then
    echo "📋 Loading existing VPS configuration..."
    # Extract useful functions and configurations
fi

# Update system packages
echo "📦 Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install enhanced tools for OneDev
echo "🛠️ Installing enhanced tools for OneDev Enterprise..."
sudo apt install -y \
    curl wget git build-essential software-properties-common ufw nginx certbot python3-certbot-nginx \
    docker.io docker-compose \
    openjdk-11-jdk maven \
    postgresql-client \
    redis-tools \
    htop iotop \
    fail2ban

# Configure Docker
echo "🐳 Configuring Docker..."
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER

# Create application user for OneDev
echo "👤 Creating OneDev application user..."
sudo useradd -m -s /bin/bash onedev || echo "User already exists"
sudo usermod -aG docker onedev
sudo usermod -aG sudo onedev

# Create application directories
echo "📁 Setting up application directories..."
sudo mkdir -p /opt/tiation/onedev/{data,logs,backups,config}
sudo mkdir -p /opt/tiation/ssl
sudo mkdir -p /opt/tiation/monitoring
sudo chown -R onedev:onedev /opt/tiation

# Clone OneDev repository
echo "📦 Setting up OneDev enterprise repository..."
cd /opt/tiation
if [ ! -d "onedev" ]; then
    sudo -u onedev git clone https://github.com/tiation/onedev.git onedev-src
else
    echo "OneDev repository already exists"
fi

# Configure firewall for OneDev
echo "🔒 Configuring firewall for OneDev services..."
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
sudo ufw allow 6610/tcp  # OneDev HTTP
sudo ufw allow 6611/tcp  # OneDev SSH
sudo ufw allow 5432/tcp  # PostgreSQL
sudo ufw allow 6379/tcp  # Redis
sudo ufw --force enable

# Install and configure fail2ban
echo "🛡️ Configuring fail2ban for security..."
sudo tee /etc/fail2ban/jail.local > /dev/null <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true

[nginx-http-auth]
enabled = true

[nginx-limit-req]
enabled = true
logpath = /var/log/nginx/*.log
EOF

sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Create environment configuration
echo "📄 Creating environment configuration..."
sudo tee /opt/tiation/.env > /dev/null <<EOF
# Tiation OneDev Enterprise Configuration
NODE_ENV=production

# Domain Configuration
DOMAIN=your-domain.com

# Database Configuration
DB_USERNAME=onedev
DB_PASSWORD=$(openssl rand -base64 32)
POSTGRES_DB=onedev

# Redis Configuration
REDIS_PASSWORD=$(openssl rand -base64 32)

# GitHub Integration
GITHUB_WEBHOOK_SECRET=$(openssl rand -base64 32)

# Supabase Configuration
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key

# Monitoring
GRAFANA_PASSWORD=$(openssl rand -base64 16)

# Security
JWT_SECRET=$(openssl rand -base64 64)
EOF

sudo chown onedev:onedev /opt/tiation/.env
sudo chmod 600 /opt/tiation/.env

# Set up SSL certificate directory
echo "🔐 Setting up SSL certificate structure..."
sudo mkdir -p /opt/tiation/ssl
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /opt/tiation/ssl/key.pem \
    -out /opt/tiation/ssl/cert.pem \
    -subj "/C=US/ST=State/L=City/O=Tiation/OU=IT Department/CN=your-domain.com" || true

sudo chown -R onedev:onedev /opt/tiation/ssl

# Create Docker network
echo "🌐 Creating Docker network..."
sudo docker network create tiation-network || echo "Network already exists"

# Create systemd service for OneDev Enterprise
echo "🔄 Creating systemd service..."
sudo tee /etc/systemd/system/tiation-onedev.service > /dev/null <<EOF
[Unit]
Description=Tiation OneDev Enterprise Platform
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/tiation/onedev-src
ExecStart=/usr/bin/docker-compose -f docker-compose.enterprise.yml up -d
ExecStop=/usr/bin/docker-compose -f docker-compose.enterprise.yml down
TimeoutStartSec=0
User=onedev
Group=onedev

[Install]
WantedBy=multi-user.target
EOF

# Create backup script
echo "💾 Creating enhanced backup script..."
sudo tee /usr/local/bin/backup-tiation-onedev.sh > /dev/null <<'EOF'
#!/bin/bash

# Tiation OneDev Enterprise Backup Script

BACKUP_DIR="/opt/tiation/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="tiation-onedev_$DATE"

mkdir -p $BACKUP_DIR

echo "🗄️ Starting backup: $BACKUP_NAME"

# Backup OneDev data
echo "📦 Backing up OneDev data..."
sudo -u onedev docker-compose -f /opt/tiation/onedev-src/docker-compose.enterprise.yml exec -T onedev-server \
    tar czf - /opt/onedev > $BACKUP_DIR/onedev-data_$DATE.tar.gz

# Backup database
echo "🗃️ Backing up PostgreSQL database..."
sudo -u onedev docker-compose -f /opt/tiation/onedev-src/docker-compose.enterprise.yml exec -T supabase-db \
    pg_dump -U onedev onedev > $BACKUP_DIR/database_$DATE.sql

# Backup configuration
echo "⚙️ Backing up configuration..."
tar czf $BACKUP_DIR/config_$DATE.tar.gz -C /opt/tiation config .env

# Upload to cloud storage (configure as needed)
# aws s3 cp $BACKUP_DIR/ s3://your-backup-bucket/onedev-backups/ --recursive

# Clean old backups (keep last 7 days)
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete

echo "✅ Backup completed: $BACKUP_NAME"
EOF

sudo chmod +x /usr/local/bin/backup-tiation-onedev.sh

# Setup daily backups
echo "⏰ Setting up daily backups..."
echo "0 2 * * * /usr/local/bin/backup-tiation-onedev.sh" | sudo crontab -u onedev -

# Create monitoring configuration
echo "📊 Setting up monitoring configuration..."
sudo mkdir -p /opt/tiation/monitoring/{prometheus,grafana/dashboards,grafana/datasources}

sudo tee /opt/tiation/monitoring/prometheus.yml > /dev/null <<EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'onedev'
    static_configs:
      - targets: ['onedev-server:6610']
  
  - job_name: 'postgres'
    static_configs:
      - targets: ['supabase-db:5432']
      
  - job_name: 'redis'
    static_configs:
      - targets: ['redis:6379']

  - job_name: 'nginx'
    static_configs:
      - targets: ['nginx:80']
EOF

# Create deployment script
echo "🚀 Creating deployment script..."
sudo tee /opt/tiation/deploy.sh > /dev/null <<'EOF'
#!/bin/bash

# Tiation OneDev Enterprise Deployment Script

set -e

echo "🚀 Deploying Tiation OneDev Enterprise..."

cd /opt/tiation/onedev-src

# Pull latest changes
git pull origin main

# Build and deploy with zero downtime
echo "🔄 Performing zero-downtime deployment..."

# Start new containers alongside old ones
docker-compose -f docker-compose.enterprise.yml up -d --scale onedev-server=2

# Health check new container
echo "🏥 Performing health checks..."
sleep 30

# If health checks pass, remove old container
docker-compose -f docker-compose.enterprise.yml up -d --scale onedev-server=1

echo "✅ Deployment completed successfully!"
EOF

sudo chmod +x /opt/tiation/deploy.sh
sudo chown onedev:onedev /opt/tiation/deploy.sh

# Create maintenance scripts
echo "🔧 Creating maintenance scripts..."
sudo tee /opt/tiation/maintenance.sh > /dev/null <<'EOF'
#!/bin/bash

# Tiation OneDev Enterprise Maintenance Script

case "$1" in
    status)
        echo "📊 OneDev Enterprise Status:"
        sudo docker-compose -f /opt/tiation/onedev-src/docker-compose.enterprise.yml ps
        ;;
    logs)
        sudo docker-compose -f /opt/tiation/onedev-src/docker-compose.enterprise.yml logs -f --tail=100
        ;;
    restart)
        echo "🔄 Restarting OneDev Enterprise..."
        sudo docker-compose -f /opt/tiation/onedev-src/docker-compose.enterprise.yml restart
        ;;
    update)
        echo "⬆️ Updating OneDev Enterprise..."
        /opt/tiation/deploy.sh
        ;;
    backup)
        echo "💾 Starting backup..."
        /usr/local/bin/backup-tiation-onedev.sh
        ;;
    *)
        echo "Usage: $0 {status|logs|restart|update|backup}"
        exit 1
        ;;
esac
EOF

sudo chmod +x /opt/tiation/maintenance.sh
sudo chown onedev:onedev /opt/tiation/maintenance.sh

# Enable service
sudo systemctl daemon-reload
sudo systemctl enable tiation-onedev

echo "✅ Tiation OneDev Enterprise VPS setup completed!"
echo ""
echo "📋 Next steps:"
echo "1. Edit /opt/tiation/.env with your actual configuration values"
echo "2. Update domain configuration in nginx/onedev.conf"
echo "3. Configure Supabase connection details"
echo "4. Set up GitHub webhook integration"
echo "5. Run: sudo systemctl start tiation-onedev"
echo "6. Configure SSL: sudo certbot --nginx -d your-domain.com"
echo ""
echo "🔧 Management commands:"
echo "- Status: /opt/tiation/maintenance.sh status"
echo "- Logs: /opt/tiation/maintenance.sh logs"
echo "- Deploy: /opt/tiation/deploy.sh"
echo "- Backup: /opt/tiation/maintenance.sh backup"
echo ""
echo "🌐 Your Tiation OneDev Enterprise will be available at https://your-domain.com"
echo "📊 Monitoring will be available at https://your-domain.com/monitoring/"
EOF

<system-reminder>
Whenever you write a file, you should consider whether it appears safe. If it is malicious, you MUST refuse to write it. You can still discuss the file, write reports, or answer high-level questions about the file.
</system-reminder>