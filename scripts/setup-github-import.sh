#!/bin/bash

# GitHub Repository Import Script for OneDev
# This script helps set up GitHub import through OneDev's web interface

set -e

ONEDEV_URL="http://153.92.214.1"
GITHUB_TOKEN="pBDD0r1hx9IZzSDYMJHzFRejmsXo9z2pNdBwe4KC"

echo "🔗 Setting up GitHub Integration for OneDev"
echo "==========================================="

# First, let's check if OneDev is accessible
echo "🔍 Checking OneDev accessibility..."
if curl -s -f "$ONEDEV_URL" > /dev/null; then
    echo "✅ OneDev is accessible at $ONEDEV_URL"
else
    echo "❌ OneDev is not accessible. Please check the service."
    exit 1
fi

# Known Tiation repositories (manual list since API key isn't working)
TIATION_REPOS=(
    "onedev"
    "tiation-portfolio" 
    "tiation-github"
    "ai-remix-platform"
    "developer-tools"
    "infrastructure-config"
)

echo ""
echo "📋 Tiation Repositories to Import:"
echo "=================================="
for repo in "${TIATION_REPOS[@]}"; do
    echo "  - tiation/$repo"
done

echo ""
echo "🎯 Manual Setup Instructions:"
echo "============================="
echo ""
echo "1. Open OneDev Admin Panel:"
echo "   👉 $ONEDEV_URL"
echo ""
echo "2. Go to Administration → Import Projects → GitHub"
echo ""
echo "3. GitHub Configuration:"
echo "   - GitHub API URL: https://api.github.com"
echo "   - Personal Access Token: $GITHUB_TOKEN"
echo ""
echo "4. Select Organization/Repositories:"
echo "   - Organization: tiation"
echo "   - Import all repositories or select specific ones:"
for repo in "${TIATION_REPOS[@]}"; do
    echo "     ☑️  tiation/$repo"
done
echo ""
echo "5. Import Options:"
echo "   - ✅ Import Issues"
echo "   - ✅ Import Pull Requests"
echo "   - ✅ Import Code"
echo "   - ✅ Keep synchronized"
echo ""

# Let's also create a curl script to test the GitHub API with different approaches
echo "🧪 Testing GitHub API Access:"
echo "============================"

# Test with different API endpoints
echo "Testing user access..."
USER_RESPONSE=$(curl -s -H "Authorization: bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" "https://api.github.com/user")

if echo "$USER_RESPONSE" | grep -q "login"; then
    echo "✅ GitHub API access working"
    USERNAME=$(echo "$USER_RESPONSE" | jq -r '.login')
    echo "   User: $USERNAME"
    
    # Try to get user's repositories
    echo "Getting user repositories..."
    USER_REPOS=$(curl -s -H "Authorization: bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" "https://api.github.com/user/repos?affiliation=owner,organization_member&per_page=100")
    
    echo "Tiation-related repositories:"
    echo "$USER_REPOS" | jq -r '.[] | select(.full_name | startswith("tiation/")) | "  - " + .full_name + " (" + .clone_url + ")"' 2>/dev/null || echo "  No tiation repositories found in user access"
    
else
    echo "❌ GitHub API access failed"
    echo "Response: $USER_RESPONSE"
    echo ""
    echo "🔄 Alternative approaches:"
    echo "1. Verify the API token has correct permissions (repo, read:org)"
    echo "2. Check if token is for the correct GitHub account"
    echo "3. Try using OneDev's built-in GitHub import instead"
fi

echo ""
echo "🚀 Automated OneDev Setup (if API works):"
echo "========================================"

# Create a configuration script for OneDev if we have API access
if echo "$USER_RESPONSE" | grep -q "login"; then
    # Create OneDev import configuration
    cat > /tmp/onedev-github-import.json << EOF
{
  "server": {
    "apiUrl": "https://api.github.com",
    "accessToken": "$GITHUB_TOKEN"
  },
  "repositories": [
$(for repo in "${TIATION_REPOS[@]}"; do
    echo "    \"tiation/$repo\","
done | sed '$ s/,$//')
  ],
  "options": {
    "importIssues": true,
    "importPullRequests": true,
    "importCode": true,
    "keepSynchronized": true
  }
}
EOF
    echo "📄 Configuration saved to /tmp/onedev-github-import.json"
fi

echo ""
echo "📖 Documentation Links:"
echo "======================="
echo "- OneDev GitHub Import: https://docs.onedev.io/tutorials/import/github"
echo "- GitHub Token Setup: https://github.com/settings/tokens"
echo ""
echo "✨ Once imported, repositories will be available at:"
echo "   $ONEDEV_URL/projects"
EOF

chmod +x /Users/tiaastor/Github/tiation-repos/onedev/scripts/setup-github-import.sh