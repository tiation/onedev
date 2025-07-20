# 🔗 OneDev GitHub Import Guide

## Current Status

✅ **OneDev is running at: http://153.92.214.1**  
⚠️  **GitHub API Token needs verification**

## 🎯 Step-by-Step GitHub Import

### Step 1: Access OneDev Admin
1. Open your browser and go to: **http://153.92.214.1**
2. If this is first time setup, create your admin account
3. Login to OneDev

### Step 2: Navigate to Import
1. Click **Administration** (top right menu)
2. Select **Import Projects** 
3. Choose **GitHub**

### Step 3: Configure GitHub Connection
```
GitHub API URL: https://api.github.com
Personal Access Token: pBDD0r1hx9IZzSDYMJHzFRejmsXo9z2pNdBwe4KC
```

### Step 4: Select Tiation Repositories

If the token works, you'll see all tiation repositories. Select these:

- ☑️ **tiation/onedev** - The enhanced OneDev repository
- ☑️ **tiation/tiation-portfolio** - Main portfolio website
- ☑️ **tiation/tiation-github** - GitHub integration tools
- ☑️ **tiation/ai-remix-platform** - AI platform project
- ☑️ **tiation/developer-tools** - Development utilities
- ☑️ **tiation/infrastructure-config** - Infrastructure as code

### Step 5: Import Options
Enable these options:
- ✅ **Import Issues** 
- ✅ **Import Pull Requests**
- ✅ **Import Milestones**
- ✅ **Keep synchronized with GitHub**

### Step 6: Execute Import
1. Click **Import** button
2. Wait for import process to complete
3. Check progress in the import log

## 🔧 If GitHub Token Issues

If you get "Bad credentials" error:

### Option A: Create New GitHub Token
1. Go to: https://github.com/settings/tokens
2. Click **Generate new token (classic)**
3. Name: `OneDev Integration`
4. Scopes needed:
   - ✅ `repo` (Full repository access)
   - ✅ `read:org` (Read organization data)
   - ✅ `admin:repo_hook` (Repository webhooks)
5. Copy the new token and use it in OneDev

### Option B: Manual Repository Clone
If API import fails, you can manually clone each repository:

```bash
# SSH to your VPS
ssh root@153.92.214.1

# Create projects manually in OneDev and clone
docker exec -it onedev bash

# Inside OneDev container, clone repositories
cd /opt/onedev
git clone https://github.com/tiation/onedev.git
git clone https://github.com/tiation/tiation-portfolio.git
git clone https://github.com/tiation/tiation-github.git
git clone https://github.com/tiation/ai-remix-platform.git
git clone https://github.com/tiation/developer-tools.git
git clone https://github.com/tiation/infrastructure-config.git
```

## 🚀 After Import

Once repositories are imported, they will be available at:
- **Projects**: http://153.92.214.1/projects
- **Code Browser**: http://153.92.214.1/projects/{project-name}
- **Issues**: http://153.92.214.1/projects/{project-name}/issues
- **Builds**: http://153.92.214.1/projects/{project-name}/builds

## 🔄 Setting Up Webhooks

After import, set up GitHub webhooks for real-time sync:

1. **In GitHub** (for each repository):
   - Go to repository Settings → Webhooks
   - Add webhook: `http://153.92.214.1/api/github-webhook`
   - Content type: `application/json`
   - Secret: (use webhook secret from OneDev)
   - Events: Choose individual events (pushes, pull requests, issues)

2. **In OneDev**:
   - Go to project Settings → Integrations
   - Configure GitHub integration
   - Enable webhook synchronization

## 📊 Verification

After setup, verify:
- [ ] All repositories visible in http://153.92.214.1/projects
- [ ] Issues imported correctly
- [ ] Code browsing works
- [ ] Git operations work via SSH: `git clone ssh://git@153.92.214.1:6611/tiation/onedev.git`

## 🆘 Troubleshooting

**If import hangs:**
```bash
ssh root@153.92.214.1
/opt/tiation/manage-onedev.sh logs
```

**If repositories don't appear:**
- Check OneDev logs for errors
- Verify GitHub token permissions
- Try importing one repository at a time

**For support:**
- OneDev logs: `/opt/tiation/manage-onedev.sh logs`
- GitHub API test: `curl -H "Authorization: token YOUR_TOKEN" https://api.github.com/user`

---

🎉 **Once complete, you'll have all Tiation repositories synchronized with your OneDev instance!**