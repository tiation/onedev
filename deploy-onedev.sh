#!/bin/bash

# Tiation OneDev Enterprise - One-Click VPS Deployment
# Usage: ./deploy-onedev.sh

set -e

VPS_IP="153.92.214.1"
VPS_USER="root"

echo "🚀 Deploying Tiation OneDev Enterprise to VPS $VPS_IP"
echo "======================================================"

# Check if we can connect to VPS
echo "🔍 Testing VPS connection..."
if ! ssh -o ConnectTimeout=10 -o BatchMode=yes $VPS_USER@$VPS_IP exit 2>/dev/null; then
    echo "❌ Cannot connect to VPS. Please ensure:"
    echo "   1. SSH key is set up: ssh-copy-id $VPS_USER@$VPS_IP"
    echo "   2. Or run manually: ssh $VPS_USER@$VPS_IP"
    exit 1
fi

echo "✅ VPS connection successful!"

# Upload deployment script
echo "📤 Uploading deployment script..."
scp -q scripts/vps-deploy.sh $VPS_USER@$VPS_IP:/tmp/vps-deploy.sh

# Upload the entire codebase
echo "📦 Uploading OneDev Enterprise files..."
rsync -avz --progress --exclude='.git' --exclude='node_modules' --exclude='target' \
    ./ $VPS_USER@$VPS_IP:/tmp/onedev-enterprise/

# Execute deployment on VPS
echo "🔧 Executing deployment on VPS..."
ssh $VPS_USER@$VPS_IP << 'DEPLOY_SCRIPT'
    set -e
    echo "Starting deployment on VPS..."
    
    # Copy files to proper location
    if [ -d "/tmp/onedev-enterprise" ]; then
        echo "Copying files to /opt/tiation/..."
        mkdir -p /opt/tiation
        cp -r /tmp/onedev-enterprise /opt/tiation/ 2>/dev/null || true
    fi
    
    # Make deploy script executable and run
    chmod +x /tmp/vps-deploy.sh
    /tmp/vps-deploy.sh
    
    echo "Deployment script completed!"
DEPLOY_SCRIPT

# Check deployment status
echo "📊 Checking deployment status..."
ssh $VPS_USER@$VPS_IP << 'STATUS_CHECK'
    echo "Checking services..."
    
    if command -v docker >/dev/null 2>&1; then
        echo "Docker containers:"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    fi
    
    echo ""
    echo "Listening ports:"
    netstat -tulpn 2>/dev/null | grep LISTEN | head -10
    
    echo ""
    echo "Service status:"
    if [ -x "/opt/tiation/manage.sh" ]; then
        /opt/tiation/manage.sh status
    fi
STATUS_CHECK

# Get access information
echo ""
echo "🎉 Deployment Complete!"
echo "======================="
echo ""

# Get the actual ports being used
ONEDEV_PORT=$(ssh $VPS_USER@$VPS_IP "grep ONEDEV_PORT /opt/tiation/.env 2>/dev/null | cut -d'=' -f2" || echo "6610")
IDE_PORT=$(ssh $VPS_USER@$VPS_IP "grep IDE_BRIDGE_PORT /opt/tiation/.env 2>/dev/null | cut -d'=' -f2" || echo "8080")
GRAFANA_PORT=$(ssh $VPS_USER@$VPS_IP "grep MONITORING_PORT /opt/tiation/.env 2>/dev/null | cut -d'=' -f2" || echo "3000")

echo "🌐 Access your services:"
echo "   🔧 OneDev Server:  http://$VPS_IP:$ONEDEV_PORT"
echo "   💻 IDE Bridge:    http://$VPS_IP:$IDE_PORT"  
echo "   📊 Monitoring:    http://$VPS_IP:$GRAFANA_PORT"
echo ""
echo "🔧 Management commands (run on VPS):"
echo "   ssh $VPS_USER@$VPS_IP '/opt/tiation/manage.sh status'"
echo "   ssh $VPS_USER@$VPS_IP '/opt/tiation/manage.sh logs'"
echo "   ssh $VPS_USER@$VPS_IP '/opt/tiation/manage.sh restart'"
echo ""
echo "📋 Next steps:"
echo "   1. Visit http://$VPS_IP:$ONEDEV_PORT to create your admin account"
echo "   2. Update Supabase credentials: ssh $VPS_USER@$VPS_IP 'nano /opt/tiation/.env'"
echo "   3. Configure GitHub webhooks to: http://$VPS_IP:$ONEDEV_PORT/api/github-webhook"
echo "   4. Set up SSL: ssh $VPS_USER@$VPS_IP 'certbot --nginx'"
echo ""

# Open browser to OneDev if on macOS
if command -v open >/dev/null 2>&1; then
    echo "🌐 Opening OneDev in browser..."
    sleep 2
    open "http://$VPS_IP:$ONEDEV_PORT" 2>/dev/null || true
fi

echo "✨ Deployment successful! Your OneDev Enterprise platform is ready!"
EOF

chmod +x /Users/tiaastor/Github/tiation-repos/onedev/deploy-onedev.sh