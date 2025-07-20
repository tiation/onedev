package io.onedev.server.plugin.integration.supabase;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.onedev.server.OneDev;
import io.onedev.server.entitymanager.SettingManager;
import io.onedev.server.model.support.administration.GlobalSetting;
import org.apache.http.client.methods.CloseableHttpResponse;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.entity.StringEntity;
import org.apache.http.impl.client.CloseableHttpClient;
import org.apache.http.impl.client.HttpClients;
import org.apache.http.util.EntityUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.inject.Inject;
import javax.inject.Singleton;
import java.io.IOException;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Singleton
public class SupabaseService {
    
    private static final Logger logger = LoggerFactory.getLogger(SupabaseService.class);
    
    private final SettingManager settingManager;
    private final ObjectMapper objectMapper;
    private final CloseableHttpClient httpClient;
    
    @Inject
    public SupabaseService(SettingManager settingManager) {
        this.settingManager = settingManager;
        this.objectMapper = OneDev.getInstance(ObjectMapper.class);
        this.httpClient = HttpClients.createDefault();
    }
    
    private SupabaseIntegrationSetting getSetting() {
        return settingManager.getSetting(SupabaseIntegrationSetting.class);
    }
    
    public boolean isConfigured() {
        SupabaseIntegrationSetting setting = getSetting();
        return setting != null && 
               setting.getSupabaseUrl() != null && 
               setting.getServiceRoleKey() != null;
    }
    
    public boolean isHealthy() {
        if (!isConfigured()) {
            return false;
        }
        
        try {
            return testConnection();
        } catch (Exception e) {
            logger.error("Supabase health check failed", e);
            return false;
        }
    }
    
    private boolean testConnection() {
        SupabaseIntegrationSetting setting = getSetting();
        
        try {
            HttpGet request = new HttpGet(setting.getSupabaseUrl() + "/rest/v1/");
            request.setHeader("apikey", setting.getAnonKey());
            request.setHeader("Authorization", "Bearer " + setting.getServiceRoleKey());
            
            try (CloseableHttpResponse response = httpClient.execute(request)) {
                return response.getStatusLine().getStatusCode() == 200;
            }
        } catch (IOException e) {
            logger.error("Failed to test Supabase connection", e);
            return false;
        }
    }
    
    // Database operations
    public Connection getDatabaseConnection() throws SQLException {
        SupabaseIntegrationSetting setting = getSetting();
        if (setting == null) {
            throw new IllegalStateException("Supabase not configured");
        }
        
        String jdbcUrl = setting.getSupabaseUrl().replace("https://", "jdbc:postgresql://")
                .replace(".supabase.co", ".supabase.co:5432") + "/postgres";
        
        return DriverManager.getConnection(
            jdbcUrl,
            "postgres", 
            setting.getDatabasePassword()
        );
    }
    
    // REST API operations
    public JsonNode query(String table, String select, String filter) throws IOException {
        SupabaseIntegrationSetting setting = getSetting();
        
        StringBuilder url = new StringBuilder(setting.getSupabaseUrl())
            .append("/rest/v1/").append(table);
        
        if (select != null) {
            url.append("?select=").append(select);
        }
        
        if (filter != null) {
            url.append(select != null ? "&" : "?").append(filter);
        }
        
        HttpGet request = new HttpGet(url.toString());
        request.setHeader("apikey", setting.getAnonKey());
        request.setHeader("Authorization", "Bearer " + setting.getServiceRoleKey());
        request.setHeader("Content-Type", "application/json");
        
        try (CloseableHttpResponse response = httpClient.execute(request)) {
            String responseBody = EntityUtils.toString(response.getEntity());
            
            if (response.getStatusLine().getStatusCode() >= 400) {
                throw new IOException("Supabase query failed: " + responseBody);
            }
            
            return objectMapper.readTree(responseBody);
        }
    }
    
    public JsonNode insert(String table, Object data) throws IOException {
        SupabaseIntegrationSetting setting = getSetting();
        
        String url = setting.getSupabaseUrl() + "/rest/v1/" + table;
        
        HttpPost request = new HttpPost(url);
        request.setHeader("apikey", setting.getAnonKey());
        request.setHeader("Authorization", "Bearer " + setting.getServiceRoleKey());
        request.setHeader("Content-Type", "application/json");
        request.setHeader("Prefer", "return=representation");
        
        String jsonData = objectMapper.writeValueAsString(data);
        request.setEntity(new StringEntity(jsonData));
        
        try (CloseableHttpResponse response = httpClient.execute(request)) {
            String responseBody = EntityUtils.toString(response.getEntity());
            
            if (response.getStatusLine().getStatusCode() >= 400) {
                throw new IOException("Supabase insert failed: " + responseBody);
            }
            
            return objectMapper.readTree(responseBody);
        }
    }
    
    // OneDev-specific integration methods
    public void syncProjectToSupabase(String projectPath, Map<String, Object> projectData) {
        try {
            Map<String, Object> data = new HashMap<>();
            data.put("onedev_project_path", projectPath);
            data.put("name", projectData.get("name"));
            data.put("description", projectData.get("description"));
            data.put("visibility", projectData.get("visibility"));
            data.put("created_at", projectData.get("createdAt"));
            data.put("updated_at", java.time.Instant.now().toString());
            
            // Upsert project data
            insert("onedev_projects", data);
            
            logger.info("Synced project {} to Supabase", projectPath);
            
        } catch (IOException e) {
            logger.error("Failed to sync project {} to Supabase", projectPath, e);
        }
    }
    
    public void syncIssueToSupabase(String projectPath, Long issueNumber, Map<String, Object> issueData) {
        try {
            Map<String, Object> data = new HashMap<>();
            data.put("onedev_project_path", projectPath);
            data.put("issue_number", issueNumber);
            data.put("title", issueData.get("title"));
            data.put("description", issueData.get("description"));
            data.put("state", issueData.get("state"));
            data.put("submitter", issueData.get("submitter"));
            data.put("created_at", issueData.get("createdAt"));
            data.put("updated_at", java.time.Instant.now().toString());
            
            insert("onedev_issues", data);
            
            logger.info("Synced issue #{} from project {} to Supabase", issueNumber, projectPath);
            
        } catch (IOException e) {
            logger.error("Failed to sync issue #{} from project {} to Supabase", 
                    issueNumber, projectPath, e);
        }
    }
    
    public void syncBuildToSupabase(String projectPath, Long buildNumber, Map<String, Object> buildData) {
        try {
            Map<String, Object> data = new HashMap<>();
            data.put("onedev_project_path", projectPath);
            data.put("build_number", buildNumber);
            data.put("job_name", buildData.get("jobName"));
            data.put("status", buildData.get("status"));
            data.put("branch", buildData.get("branch"));
            data.put("commit_hash", buildData.get("commitHash"));
            data.put("started_at", buildData.get("startedAt"));
            data.put("finished_at", buildData.get("finishedAt"));
            data.put("duration", buildData.get("duration"));
            
            insert("onedev_builds", data);
            
            logger.info("Synced build #{} from project {} to Supabase", buildNumber, projectPath);
            
        } catch (IOException e) {
            logger.error("Failed to sync build #{} from project {} to Supabase", 
                    buildNumber, projectPath, e);
        }
    }
    
    // Real-time collaboration features
    public void notifyUserActivity(String userId, String projectPath, String activity, Map<String, Object> metadata) {
        try {
            Map<String, Object> data = new HashMap<>();
            data.put("user_id", userId);
            data.put("project_path", projectPath);
            data.put("activity_type", activity);
            data.put("metadata", objectMapper.writeValueAsString(metadata));
            data.put("timestamp", java.time.Instant.now().toString());
            
            insert("user_activities", data);
            
        } catch (IOException e) {
            logger.error("Failed to record user activity", e);
        }
    }
    
    public List<Map<String, Object>> getRecentActivities(String projectPath, int limit) {
        try {
            String filter = "project_path=eq." + projectPath + "&order=timestamp.desc&limit=" + limit;
            JsonNode result = query("user_activities", "*", filter);
            
            List<Map<String, Object>> activities = new ArrayList<>();
            if (result.isArray()) {
                for (JsonNode activity : result) {
                    Map<String, Object> activityMap = objectMapper.convertValue(activity, Map.class);
                    activities.add(activityMap);
                }
            }
            
            return activities;
            
        } catch (IOException e) {
            logger.error("Failed to get recent activities for project {}", projectPath, e);
            return new ArrayList<>();
        }
    }
    
    // Analytics and reporting
    public Map<String, Object> getProjectAnalytics(String projectPath) {
        Map<String, Object> analytics = new HashMap<>();
        
        try (Connection conn = getDatabaseConnection()) {
            // Get issue statistics
            try (PreparedStatement stmt = conn.prepareStatement(
                    "SELECT state, COUNT(*) as count FROM onedev_issues WHERE onedev_project_path = ? GROUP BY state")) {
                stmt.setString(1, projectPath);
                try (ResultSet rs = stmt.executeQuery()) {
                    Map<String, Integer> issueStats = new HashMap<>();
                    while (rs.next()) {
                        issueStats.put(rs.getString("state"), rs.getInt("count"));
                    }
                    analytics.put("issues", issueStats);
                }
            }
            
            // Get build statistics
            try (PreparedStatement stmt = conn.prepareStatement(
                    "SELECT status, COUNT(*) as count FROM onedev_builds WHERE onedev_project_path = ? GROUP BY status")) {
                stmt.setString(1, projectPath);
                try (ResultSet rs = stmt.executeQuery()) {
                    Map<String, Integer> buildStats = new HashMap<>();
                    while (rs.next()) {
                        buildStats.put(rs.getString("status"), rs.getInt("count"));
                    }
                    analytics.put("builds", buildStats);
                }
            }
            
        } catch (SQLException e) {
            logger.error("Failed to get analytics for project {}", projectPath, e);
        }
        
        return analytics;
    }
    
    public void cleanup() {
        try {
            httpClient.close();
        } catch (IOException e) {
            logger.error("Error closing HTTP client", e);
        }
    }
}