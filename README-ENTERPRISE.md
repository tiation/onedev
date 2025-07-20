# Tiation OneDev Enterprise Setup

This repository contains the enhanced OneDev setup for Tiation's enterprise-grade development platform, integrating with GitHub, Supabase, and IDE tooling.

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   VS Code/      │    │   Nginx Proxy   │    │   OneDev Core   │
│   IntelliJ      │◄──►│   Load Balancer │◄──►│   Git Server    │
│   IDE Bridge    │    │   SSL/Security  │    │   CI/CD Engine  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
        │                       │                       │
        ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Supabase      │    │   GitHub        │    │   Monitoring    │
│   Database      │    │   Integration   │    │   Grafana/      │
│   Auth & APIs   │    │   Webhooks      │    │   Prometheus    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🚀 Quick Start

### Prerequisites
- Ubuntu 20.04/22.04 server
- Docker and Docker Compose
- Domain name with DNS configured
- Supabase project
- GitHub repository access

### 1. Clone and Setup

```bash
git clone git@github.com:tiation/onedev.git
cd onedev
chmod +x scripts/enterprise-vps-setup.sh
sudo ./scripts/enterprise-vps-setup.sh
```

### 2. Configure Environment

Edit `/opt/tiation/.env` with your actual values:

```bash
sudo nano /opt/tiation/.env
```

Required configuration:
- `DOMAIN`: Your domain name
- `SUPABASE_URL`: Your Supabase project URL
- `SUPABASE_ANON_KEY`: Supabase anonymous key
- `SUPABASE_SERVICE_ROLE_KEY`: Supabase service role key
- `GITHUB_WEBHOOK_SECRET`: GitHub webhook secret

### 3. Deploy Services

```bash
cd /opt/tiation/onedev-src
sudo systemctl start tiation-onedev

# Check status
/opt/tiation/maintenance.sh status
```

### 4. Configure SSL

```bash
sudo certbot --nginx -d your-domain.com
```

## 🔧 Enterprise Features

### GitHub Integration
- **Bidirectional Sync**: Real-time sync between OneDev and GitHub
- **Webhook Support**: Automatic updates from GitHub events
- **Issue Sync**: Issues, pull requests, and comments
- **Branch Protection**: Enforce code review and CI/CD requirements

### IDE Integration
- **VS Code Extension**: Native OneDev integration
- **IntelliJ Plugin**: Full IDE support with code navigation
- **Language Server Protocol**: Code completion, hover info, go-to-definition
- **Real-time Collaboration**: Live editing and code review

### Supabase Integration
- **PostgreSQL Backend**: High-performance database with OneDev
- **Real-time Features**: Live updates and notifications
- **Analytics Dashboard**: Project metrics and insights
- **User Activity Tracking**: Collaboration and productivity metrics

### Enterprise Security
- **SAML/OIDC Support**: Enterprise authentication
- **Role-based Access Control**: Fine-grained permissions
- **Audit Logging**: Complete activity tracking
- **Security Headers**: OWASP compliance

## 📊 Monitoring & Analytics

Access monitoring at: `https://your-domain.com/monitoring/`

- **System Metrics**: CPU, memory, disk usage
- **Application Metrics**: Build success rates, issue velocity
- **User Analytics**: Activity patterns, collaboration metrics
- **Performance Monitoring**: Response times, error rates

## 🛠️ Management Commands

```bash
# Check system status
/opt/tiation/maintenance.sh status

# View logs
/opt/tiation/maintenance.sh logs

# Restart services
/opt/tiation/maintenance.sh restart

# Deploy updates
/opt/tiation/deploy.sh

# Create backup
/opt/tiation/maintenance.sh backup
```

## 🔌 IDE Setup

### VS Code Extension
1. Install the "Tiation OneDev" extension
2. Configure server URL: `https://your-domain.com`
3. Authenticate with your OneDev credentials
4. Enable real-time features in settings

### IntelliJ IDEA Plugin
1. Install plugin from JetBrains Marketplace
2. Go to Settings → Tools → OneDev
3. Configure server URL and authentication
4. Enable code navigation features

## 🔗 API Integration

### REST API Endpoints

```bash
# Get project information
GET https://your-domain.com/api/projects/{project-path}

# IDE bridge endpoints
GET https://your-domain.com/ide/api/capabilities
POST https://your-domain.com/ide/api/lsp/{method}

# GitHub webhook
POST https://your-domain.com/api/github-webhook
```

### WebSocket Real-time

```javascript
const ws = new WebSocket('wss://your-domain.com/ide/');
ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  // Handle real-time updates
};
```

## 🗄️ Database Schema

The Supabase integration includes tables for:
- `onedev_projects`: Project metadata and settings
- `onedev_issues`: Issue synchronization
- `onedev_builds`: CI/CD build information
- `user_activities`: Collaboration tracking
- `ide_sessions`: Active IDE connections
- `analytics_snapshots`: Historical metrics

## 🔄 GitHub Sync Setup

1. **Create GitHub App**:
   - Go to GitHub Settings → Developer settings → GitHub Apps
   - Create new app with webhook URL: `https://your-domain.com/api/github-webhook`
   - Enable permissions for repositories, issues, pull requests

2. **Configure Webhooks**:
   - Set webhook secret in OneDev settings
   - Enable events: push, pull_request, issues, issue_comment

3. **Install App**:
   - Install the GitHub App on your repositories
   - Configure repository mappings in OneDev

## 🚨 Troubleshooting

### Common Issues

**Connection Issues**:
```bash
# Check service status
docker-compose -f /opt/tiation/onedev-src/docker-compose.enterprise.yml ps

# Check logs
docker-compose -f /opt/tiation/onedev-src/docker-compose.enterprise.yml logs onedev-server
```

**Database Issues**:
```bash
# Check PostgreSQL connection
docker-compose -f /opt/tiation/onedev-src/docker-compose.enterprise.yml exec supabase-db psql -U onedev -d onedev -c "SELECT version();"
```

**SSL/Certificate Issues**:
```bash
# Renew certificates
sudo certbot renew
sudo systemctl reload nginx
```

### Performance Tuning

**Java Heap Size**:
Edit `docker-compose.enterprise.yml` and adjust `JAVA_OPTS`:
```yaml
environment:
  - JAVA_OPTS=-Xmx8g -XX:+UseG1GC -XX:+UseStringDeduplication
```

**Database Optimization**:
```sql
-- Run in Supabase SQL editor
ANALYZE;
VACUUM;
REINDEX DATABASE onedev;
```

## 📧 Support & Documentation

- **Enterprise Support**: support@tiation.com
- **Documentation**: https://docs.tiation.com/onedev
- **GitHub Issues**: https://github.com/tiation/onedev/issues
- **Community Discord**: https://discord.gg/tiation

## 📄 License

This enterprise setup is licensed under MIT License. See `LICENSE` file for details.

---

**Tiation OneDev Enterprise** - Elevating your development workflow with enterprise-grade features, seamless integrations, and powerful collaboration tools.