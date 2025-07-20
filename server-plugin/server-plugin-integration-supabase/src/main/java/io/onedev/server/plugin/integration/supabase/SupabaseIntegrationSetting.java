package io.onedev.server.plugin.integration.supabase;

import io.onedev.server.annotation.Editable;
import io.onedev.server.annotation.Password;
import io.onedev.server.model.support.administration.GlobalSetting;

import javax.validation.constraints.NotEmpty;
import java.io.Serializable;

@Editable
public class SupabaseIntegrationSetting implements Serializable, GlobalSetting {

    private static final long serialVersionUID = 1L;
    
    private String supabaseUrl;
    
    private String anonKey;
    
    private String serviceRoleKey;
    
    private String databasePassword;
    
    private boolean enableRealTimeSync = true;
    
    private boolean enableAnalytics = true;
    
    private boolean enableUserActivityTracking = false;
    
    private String webhookSecret;
    
    @Editable(order=100, name="Supabase URL", description="Your Supabase project URL (e.g., https://your-project.supabase.co)")
    @NotEmpty
    public String getSupabaseUrl() {
        return supabaseUrl;
    }

    public void setSupabaseUrl(String supabaseUrl) {
        this.supabaseUrl = supabaseUrl;
    }

    @Editable(order=200, name="Anonymous Key", description="Supabase anonymous/public key from your project settings")
    @NotEmpty
    public String getAnonKey() {
        return anonKey;
    }

    public void setAnonKey(String anonKey) {
        this.anonKey = anonKey;
    }

    @Editable(order=300, name="Service Role Key", description="Supabase service role key for server-side operations")
    @Password
    @NotEmpty
    public String getServiceRoleKey() {
        return serviceRoleKey;
    }

    public void setServiceRoleKey(String serviceRoleKey) {
        this.serviceRoleKey = serviceRoleKey;
    }

    @Editable(order=400, name="Database Password", description="Password for direct database connections")
    @Password
    public String getDatabasePassword() {
        return databasePassword;
    }

    public void setDatabasePassword(String databasePassword) {
        this.databasePassword = databasePassword;
    }

    @Editable(order=500, name="Enable Real-time Sync", description="Enable real-time synchronization of OneDev data to Supabase")
    public boolean isEnableRealTimeSync() {
        return enableRealTimeSync;
    }

    public void setEnableRealTimeSync(boolean enableRealTimeSync) {
        this.enableRealTimeSync = enableRealTimeSync;
    }

    @Editable(order=600, name="Enable Analytics", description="Enable analytics data collection in Supabase")
    public boolean isEnableAnalytics() {
        return enableAnalytics;
    }

    public void setEnableAnalytics(boolean enableAnalytics) {
        this.enableAnalytics = enableAnalytics;
    }

    @Editable(order=700, name="Enable User Activity Tracking", description="Track user activities for collaboration features")
    public boolean isEnableUserActivityTracking() {
        return enableUserActivityTracking;
    }

    public void setEnableUserActivityTracking(boolean enableUserActivityTracking) {
        this.enableUserActivityTracking = enableUserActivityTracking;
    }

    @Editable(order=800, name="Webhook Secret", description="Secret for validating incoming webhooks from Supabase")
    @Password
    public String getWebhookSecret() {
        return webhookSecret;
    }

    public void setWebhookSecret(String webhookSecret) {
        this.webhookSecret = webhookSecret;
    }
}