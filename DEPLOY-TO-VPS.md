# Deploy to VPS 153.92.214.1

## Quick Deployment Steps

### 1. Copy Files to VPS

```bash
# Copy the deployment script to your VPS
scp scripts/vps-deploy.sh root@153.92.214.1:/tmp/

# Copy the entire onedev directory (if you want all files)
rsync -avz --progress ./ root@153.92.214.1:/tmp/onedev-enterprise/
```

### 2. SSH into VPS and Run Deployment

```bash
# SSH into your VPS
ssh root@153.92.214.1

# Make script executable and run
chmod +x /tmp/vps-deploy.sh
/tmp/vps-deploy.sh
```

### 3. Alternative: Run Everything in One Command

```bash
# This will copy and execute the script in one go
scp scripts/vps-deploy.sh root@153.92.214.1:/tmp/ && \
ssh root@153.92.214.1 "chmod +x /tmp/vps-deploy.sh && /tmp/vps-deploy.sh"
```

### 4. Manual Setup (if needed)

If you prefer to set up manually:

```bash
ssh root@153.92.214.1

# Update system
apt update && apt upgrade -y

# Install Docker
apt install -y docker.io docker-compose git nginx

# Create directories
mkdir -p /opt/tiation

# Clone our repository
cd /opt/tiation
git clone https://github.com/tiation/onedev.git onedev-enterprise

# Copy our files (you'll need to upload them first)
cd onedev-enterprise

# Start services
docker-compose -f docker-compose.production.yml up -d --build
```

## Expected Results

After deployment, you should see:

- **OneDev**: http://153.92.214.1:6610
- **IDE Bridge**: http://153.92.214.1:8080  
- **Monitoring**: http://153.92.214.1:3000

## Checking Status

```bash
# SSH to VPS
ssh root@153.92.214.1

# Check services
/opt/tiation/manage.sh status

# Check logs
/opt/tiation/manage.sh logs

# Check what's running
docker ps
```

## Troubleshooting

**If SSH fails:**
```bash
# Add the host key
ssh-keyscan 153.92.214.1 >> ~/.ssh/known_hosts

# Or connect with key verification disabled (less secure)
ssh -o StrictHostKeyChecking=no root@153.92.214.1
```

**If ports are occupied:**
The script automatically detects conflicts and uses alternative ports.

**If you need to see what's already running:**
```bash
ssh root@153.92.214.1 "netstat -tulpn | grep LISTEN"
```

## Next Steps After Deployment

1. **Configure Supabase**: Edit `/opt/tiation/.env` with your Supabase credentials
2. **Setup GitHub**: Add webhook URL to your GitHub repositories  
3. **Create Admin User**: Visit OneDev web interface to set up first user
4. **Configure SSL**: Run `certbot --nginx` for HTTPS