#!/usr/bin/env python3

import requests
import json
import sys
import time

# Configuration
ONEDEV_URL = "http://153.92.214.1"
GITHUB_TOKEN = "pBDD0r1hx9IZzSDYMJHzFRejmsXo9z2pNdBwe4KC"

# Known Tiation repositories
TIATION_REPOS = [
    "onedev",
    "tiation-portfolio", 
    "tiation-github",
    "ai-remix-platform",
    "developer-tools", 
    "infrastructure-config"
]

def test_github_token():
    """Test if the GitHub token is valid"""
    headers = {
        'Authorization': f'token {GITHUB_TOKEN}',
        'Accept': 'application/vnd.github.v3+json'
    }
    
    print("🔑 Testing GitHub API token...")
    
    # Test user endpoint
    response = requests.get('https://api.github.com/user', headers=headers)
    
    if response.status_code == 200:
        user_data = response.json()
        print(f"✅ Token valid for user: {user_data['login']}")
        return True
    else:
        print(f"❌ Token invalid. Status: {response.status_code}")
        print(f"Response: {response.text}")
        return False

def get_tiation_repos():
    """Get all tiation repositories"""
    headers = {
        'Authorization': f'token {GITHUB_TOKEN}',
        'Accept': 'application/vnd.github.v3+json'
    }
    
    print("📋 Fetching Tiation repositories...")
    
    # Try organization endpoint
    response = requests.get('https://api.github.com/orgs/tiation/repos?per_page=100', headers=headers)
    
    if response.status_code == 200:
        repos = response.json()
        repo_list = []
        for repo in repos:
            repo_list.append({
                'name': repo['name'],
                'full_name': repo['full_name'],
                'clone_url': repo['clone_url'],
                'ssh_url': repo['ssh_url'],
                'description': repo['description'],
                'private': repo['private']
            })
        return repo_list
    else:
        print(f"❌ Could not fetch org repos. Status: {response.status_code}")
        # Try user repos instead
        response = requests.get('https://api.github.com/user/repos?affiliation=owner,organization_member&per_page=100', headers=headers)
        
        if response.status_code == 200:
            repos = response.json()
            tiation_repos = []
            for repo in repos:
                if repo['full_name'].startswith('tiation/'):
                    tiation_repos.append({
                        'name': repo['name'],
                        'full_name': repo['full_name'],
                        'clone_url': repo['clone_url'],
                        'ssh_url': repo['ssh_url'],
                        'description': repo['description'],
                        'private': repo['private']
                    })
            return tiation_repos
        else:
            print(f"❌ Could not fetch user repos either. Status: {response.status_code}")
            return None

def check_onedev_status():
    """Check if OneDev is accessible"""
    print("🔍 Checking OneDev status...")
    
    try:
        response = requests.get(f"{ONEDEV_URL}", timeout=10)
        if response.status_code == 200:
            print("✅ OneDev is accessible")
            return True
        else:
            print(f"⚠️  OneDev returned status: {response.status_code}")
            return False
    except requests.exceptions.RequestException as e:
        print(f"❌ Could not connect to OneDev: {e}")
        return False

def create_manual_instructions(repos):
    """Create detailed manual setup instructions"""
    print("\n" + "="*60)
    print("📖 MANUAL SETUP INSTRUCTIONS")
    print("="*60)
    
    print(f"\n1. 🌐 Open OneDev in your browser:")
    print(f"   {ONEDEV_URL}")
    
    print(f"\n2. 🔑 Login as administrator (first time setup)")
    print(f"   - Create admin account if prompted")
    
    print(f"\n3. 📥 Go to: Administration → Import Projects → GitHub")
    
    print(f"\n4. ⚙️  GitHub Server Configuration:")
    print(f"   - GitHub API URL: https://api.github.com")
    print(f"   - Personal Access Token: {GITHUB_TOKEN}")
    
    print(f"\n5. 📦 Select Repositories to Import:")
    if repos:
        for repo in repos:
            status = "🔒 Private" if repo['private'] else "🌐 Public"
            desc = repo['description'] if repo['description'] else "No description"
            print(f"   ☑️  {repo['full_name']} - {status}")
            print(f"       {desc}")
    else:
        print("   ⚠️  If API token works, you'll see all tiation repositories")
        print("   Otherwise, manually add these repositories:")
        for repo in TIATION_REPOS:
            print(f"   ☑️  tiation/{repo}")
    
    print(f"\n6. 🔧 Import Options:")
    print(f"   ☑️  Import Issues")
    print(f"   ☑️  Import Pull Requests") 
    print(f"   ☑️  Import Milestones")
    print(f"   ☑️  Keep synchronized with GitHub")
    
    print(f"\n7. 🚀 Click 'Import' and wait for completion")
    
    print(f"\n8. ✅ Verify imports at: {ONEDEV_URL}/projects")

def create_automated_script():
    """Create a script for automated import via OneDev API"""
    print("\n" + "="*60)
    print("🤖 AUTOMATED SETUP SCRIPT")
    print("="*60)
    
    script_content = f'''#!/bin/bash

# OneDev GitHub Import Automation Script
ONEDEV_URL="{ONEDEV_URL}"
GITHUB_TOKEN="{GITHUB_TOKEN}"

echo "🚀 Automating OneDev GitHub Import..."

# Wait for OneDev to be fully ready
echo "⏳ Waiting for OneDev to be ready..."
until curl -f -s "$ONEDEV_URL" > /dev/null; do
    echo "   Still waiting..."
    sleep 5
done

echo "✅ OneDev is ready!"

# The actual import would need to be done through OneDev's REST API
# This requires admin authentication which needs to be set up first

echo "📋 Repositories to import:"
'''

    for repo in TIATION_REPOS:
        script_content += f'echo "  - tiation/{repo}"\n'
    
    script_content += f'''
echo ""
echo "🔗 Please complete the setup manually at:"
echo "{ONEDEV_URL}"
echo ""
echo "📖 Or use the OneDev REST API once authenticated"
'''

    # Save the script
    with open('/tmp/onedev-import.sh', 'w') as f:
        f.write(script_content)
    
    print("📄 Automated script saved to: /tmp/onedev-import.sh")

def main():
    print("🔗 OneDev GitHub Integration Setup")
    print("="*50)
    
    # Check OneDev
    onedev_ok = check_onedev_status()
    
    # Test GitHub token  
    github_ok = test_github_token()
    
    repos = None
    if github_ok:
        repos = get_tiation_repos()
        if repos:
            print(f"✅ Found {len(repos)} repositories:")
            for repo in repos:
                status = "🔒" if repo['private'] else "🌐"
                print(f"  {status} {repo['full_name']}")
    
    # Create setup instructions
    create_manual_instructions(repos)
    create_automated_script()
    
    print(f"\n🎯 NEXT STEPS:")
    print(f"1. Visit {ONEDEV_URL} to complete OneDev setup")
    print(f"2. Use the manual instructions above")
    print(f"3. If GitHub token issues persist, create a new one at:")
    print(f"   https://github.com/settings/tokens")
    print(f"   Required scopes: repo, read:org, admin:repo_hook")

if __name__ == "__main__":
    main()