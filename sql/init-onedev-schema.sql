-- Tiation OneDev Enterprise - Supabase Schema
-- This script sets up the necessary tables for OneDev integration with Supabase

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Projects table for OneDev project metadata
CREATE TABLE IF NOT EXISTS onedev_projects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    onedev_project_path VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    visibility VARCHAR(50) DEFAULT 'private',
    github_repository VARCHAR(255),
    github_sync_enabled BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Issues table for OneDev issues
CREATE TABLE IF NOT EXISTS onedev_issues (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    onedev_project_path VARCHAR(255) NOT NULL,
    issue_number BIGINT NOT NULL,
    title VARCHAR(500) NOT NULL,
    description TEXT,
    state VARCHAR(100) NOT NULL,
    submitter VARCHAR(255),
    assignee VARCHAR(255),
    priority VARCHAR(50),
    labels JSONB DEFAULT '[]'::jsonb,
    milestone VARCHAR(255),
    github_issue_number BIGINT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(onedev_project_path, issue_number)
);

-- Builds table for OneDev CI/CD builds
CREATE TABLE IF NOT EXISTS onedev_builds (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    onedev_project_path VARCHAR(255) NOT NULL,
    build_number BIGINT NOT NULL,
    job_name VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL,
    branch VARCHAR(255) NOT NULL,
    commit_hash VARCHAR(40),
    commit_message TEXT,
    started_at TIMESTAMPTZ,
    finished_at TIMESTAMPTZ,
    duration INTERVAL,
    error_message TEXT,
    artifacts JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(onedev_project_path, build_number)
);

-- Pull requests table
CREATE TABLE IF NOT EXISTS onedev_pull_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    onedev_project_path VARCHAR(255) NOT NULL,
    pr_number BIGINT NOT NULL,
    title VARCHAR(500) NOT NULL,
    description TEXT,
    state VARCHAR(50) NOT NULL,
    source_branch VARCHAR(255) NOT NULL,
    target_branch VARCHAR(255) NOT NULL,
    submitter VARCHAR(255),
    reviewers JSONB DEFAULT '[]'::jsonb,
    github_pr_number BIGINT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(onedev_project_path, pr_number)
);

-- User activities table for collaboration features
CREATE TABLE IF NOT EXISTS user_activities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id VARCHAR(255) NOT NULL,
    project_path VARCHAR(255),
    activity_type VARCHAR(100) NOT NULL,
    entity_type VARCHAR(50), -- 'issue', 'build', 'pr', 'commit', etc.
    entity_id VARCHAR(100),
    metadata JSONB DEFAULT '{}'::jsonb,
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- IDE sessions table for tracking active IDE connections
CREATE TABLE IF NOT EXISTS ide_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id VARCHAR(255) NOT NULL,
    project_path VARCHAR(255) NOT NULL,
    ide_type VARCHAR(50) NOT NULL, -- 'vscode', 'intellij', 'vim', etc.
    session_token VARCHAR(255) UNIQUE NOT NULL,
    last_activity TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    ended_at TIMESTAMPTZ
);

-- Code navigation cache table
CREATE TABLE IF NOT EXISTS code_navigation_cache (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_path VARCHAR(255) NOT NULL,
    file_path VARCHAR(500) NOT NULL,
    commit_hash VARCHAR(40) NOT NULL,
    symbols JSONB DEFAULT '[]'::jsonb,
    references JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '1 hour'),
    UNIQUE(project_path, file_path, commit_hash)
);

-- Analytics snapshots table
CREATE TABLE IF NOT EXISTS analytics_snapshots (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_path VARCHAR(255) NOT NULL,
    snapshot_date DATE DEFAULT CURRENT_DATE,
    metrics JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(project_path, snapshot_date)
);

-- GitHub sync status table
CREATE TABLE IF NOT EXISTS github_sync_status (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_path VARCHAR(255) UNIQUE NOT NULL,
    github_repository VARCHAR(255) NOT NULL,
    last_sync_at TIMESTAMPTZ,
    last_sync_status VARCHAR(50) DEFAULT 'pending', -- 'success', 'failed', 'pending'
    last_error_message TEXT,
    webhook_configured BOOLEAN DEFAULT false,
    bidirectional_sync BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_onedev_projects_path ON onedev_projects(onedev_project_path);
CREATE INDEX IF NOT EXISTS idx_onedev_issues_project ON onedev_issues(onedev_project_path);
CREATE INDEX IF NOT EXISTS idx_onedev_issues_state ON onedev_issues(state);
CREATE INDEX IF NOT EXISTS idx_onedev_issues_created ON onedev_issues(created_at);
CREATE INDEX IF NOT EXISTS idx_onedev_builds_project ON onedev_builds(onedev_project_path);
CREATE INDEX IF NOT EXISTS idx_onedev_builds_status ON onedev_builds(status);
CREATE INDEX IF NOT EXISTS idx_onedev_builds_branch ON onedev_builds(branch);
CREATE INDEX IF NOT EXISTS idx_onedev_prs_project ON onedev_pull_requests(onedev_project_path);
CREATE INDEX IF NOT EXISTS idx_user_activities_user ON user_activities(user_id);
CREATE INDEX IF NOT EXISTS idx_user_activities_project ON user_activities(project_path);
CREATE INDEX IF NOT EXISTS idx_user_activities_timestamp ON user_activities(timestamp);
CREATE INDEX IF NOT EXISTS idx_ide_sessions_user ON ide_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_ide_sessions_project ON ide_sessions(project_path);
CREATE INDEX IF NOT EXISTS idx_code_navigation_project_file ON code_navigation_cache(project_path, file_path);
CREATE INDEX IF NOT EXISTS idx_code_navigation_expires ON code_navigation_cache(expires_at);

-- Full-text search indexes
CREATE INDEX IF NOT EXISTS idx_onedev_issues_title_search ON onedev_issues USING gin(to_tsvector('english', title));
CREATE INDEX IF NOT EXISTS idx_onedev_issues_description_search ON onedev_issues USING gin(to_tsvector('english', description));

-- Functions and triggers for automatic timestamp updates
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply update triggers
DROP TRIGGER IF EXISTS update_onedev_projects_updated_at ON onedev_projects;
CREATE TRIGGER update_onedev_projects_updated_at 
    BEFORE UPDATE ON onedev_projects 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_onedev_issues_updated_at ON onedev_issues;
CREATE TRIGGER update_onedev_issues_updated_at 
    BEFORE UPDATE ON onedev_issues 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_onedev_prs_updated_at ON onedev_pull_requests;
CREATE TRIGGER update_onedev_prs_updated_at 
    BEFORE UPDATE ON onedev_pull_requests 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_github_sync_status_updated_at ON github_sync_status;
CREATE TRIGGER update_github_sync_status_updated_at 
    BEFORE UPDATE ON github_sync_status 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Cleanup function for expired cache entries
CREATE OR REPLACE FUNCTION cleanup_expired_cache()
RETURNS void AS $$
BEGIN
    DELETE FROM code_navigation_cache WHERE expires_at < NOW();
    DELETE FROM ide_sessions WHERE ended_at IS NOT NULL AND ended_at < (NOW() - INTERVAL '7 days');
    DELETE FROM user_activities WHERE timestamp < (NOW() - INTERVAL '30 days');
END;
$$ LANGUAGE plpgsql;

-- Views for common queries
CREATE OR REPLACE VIEW project_summary AS
SELECT 
    p.onedev_project_path,
    p.name,
    p.description,
    p.visibility,
    p.github_repository,
    COUNT(DISTINCT i.id) as total_issues,
    COUNT(DISTINCT CASE WHEN i.state = 'Open' THEN i.id END) as open_issues,
    COUNT(DISTINCT b.id) as total_builds,
    COUNT(DISTINCT CASE WHEN b.status = 'SUCCESS' THEN b.id END) as successful_builds,
    COUNT(DISTINCT pr.id) as total_prs,
    p.created_at,
    p.updated_at
FROM onedev_projects p
LEFT JOIN onedev_issues i ON p.onedev_project_path = i.onedev_project_path
LEFT JOIN onedev_builds b ON p.onedev_project_path = b.onedev_project_path
LEFT JOIN onedev_pull_requests pr ON p.onedev_project_path = pr.onedev_project_path
GROUP BY p.id, p.onedev_project_path, p.name, p.description, p.visibility, 
         p.github_repository, p.created_at, p.updated_at;

-- Row Level Security (RLS) setup for multi-tenancy
ALTER TABLE onedev_projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE onedev_issues ENABLE ROW LEVEL SECURITY;
ALTER TABLE onedev_builds ENABLE ROW LEVEL SECURITY;
ALTER TABLE onedev_pull_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_activities ENABLE ROW LEVEL SECURITY;

-- Create policies (these would be customized based on your authentication setup)
CREATE POLICY "Users can view their accessible projects" ON onedev_projects
    FOR SELECT USING (true); -- This would be more restrictive in production

CREATE POLICY "Users can view issues from accessible projects" ON onedev_issues
    FOR SELECT USING (true); -- This would be more restrictive in production

-- Insert initial configuration data
INSERT INTO analytics_snapshots (project_path, snapshot_date, metrics)
VALUES ('_global', CURRENT_DATE, '{"initialized": true, "version": "1.0.0"}'::jsonb)
ON CONFLICT (project_path, snapshot_date) DO NOTHING;

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'Tiation OneDev Enterprise schema initialized successfully!';
    RAISE NOTICE 'Tables created: onedev_projects, onedev_issues, onedev_builds, onedev_pull_requests, user_activities, ide_sessions, code_navigation_cache, analytics_snapshots, github_sync_status';
    RAISE NOTICE 'Indexes and triggers configured for optimal performance';
    RAISE NOTICE 'Row Level Security enabled for multi-tenancy support';
END $$;