package io.onedev.server.plugin.webhook.github;

import io.onedev.server.annotation.Editable;
import io.onedev.server.annotation.Password;
import io.onedev.server.model.support.administration.GlobalSetting;

import javax.validation.constraints.NotEmpty;
import java.io.Serializable;
import java.util.ArrayList;
import java.util.List;

@Editable
public class GitHubIntegrationSetting implements Serializable, GlobalSetting {

	private static final long serialVersionUID = 1L;
	
	private String webhookSecret;
	
	private String defaultGitHubApiUrl = "https://api.github.com";
	
	private List<GitHubProjectMapping> projectMappings = new ArrayList<>();
	
	private boolean enableRealTimeSync = true;
	
	private boolean enableBidirectionalSync = false;
	
	@Editable(order=100, name="Webhook Secret", description="Secret used to verify GitHub webhook requests. "
			+ "This should match the secret configured in your GitHub webhook settings.")
	@Password
	public String getWebhookSecret() {
		return webhookSecret;
	}

	public void setWebhookSecret(String webhookSecret) {
		this.webhookSecret = webhookSecret;
	}

	@Editable(order=200, name="Default GitHub API URL", description="Default GitHub API URL for integration. "
			+ "Use https://api.github.com for GitHub.com or your GitHub Enterprise API URL.")
	@NotEmpty
	public String getDefaultGitHubApiUrl() {
		return defaultGitHubApiUrl;
	}

	public void setDefaultGitHubApiUrl(String defaultGitHubApiUrl) {
		this.defaultGitHubApiUrl = defaultGitHubApiUrl;
	}

	@Editable(order=300, name="Project Mappings", description="Configure mappings between GitHub repositories "
			+ "and OneDev projects.")
	public List<GitHubProjectMapping> getProjectMappings() {
		return projectMappings;
	}

	public void setProjectMappings(List<GitHubProjectMapping> projectMappings) {
		this.projectMappings = projectMappings;
	}

	@Editable(order=400, name="Enable Real-time Sync", description="Enable real-time synchronization of changes "
			+ "from GitHub to OneDev via webhooks.")
	public boolean isEnableRealTimeSync() {
		return enableRealTimeSync;
	}

	public void setEnableRealTimeSync(boolean enableRealTimeSync) {
		this.enableRealTimeSync = enableRealTimeSync;
	}

	@Editable(order=500, name="Enable Bidirectional Sync", description="Enable synchronization of changes from "
			+ "OneDev back to GitHub. This requires appropriate API tokens and permissions.")
	public boolean isEnableBidirectionalSync() {
		return enableBidirectionalSync;
	}

	public void setEnableBidirectionalSync(boolean enableBidirectionalSync) {
		this.enableBidirectionalSync = enableBidirectionalSync;
	}

	@Editable
	public static class GitHubProjectMapping implements Serializable {
		
		private static final long serialVersionUID = 1L;
		
		private String gitHubRepository;
		
		private String oneDevProject;
		
		private String gitHubApiUrl;
		
		private String accessToken;
		
		@Editable(order=100, name="GitHub Repository", description="GitHub repository in format 'owner/repo'")
		@NotEmpty
		public String getGitHubRepository() {
			return gitHubRepository;
		}

		public void setGitHubRepository(String gitHubRepository) {
			this.gitHubRepository = gitHubRepository;
		}

		@Editable(order=200, name="OneDev Project", description="OneDev project path")
		@NotEmpty
		public String getOneDevProject() {
			return oneDevProject;
		}

		public void setOneDevProject(String oneDevProject) {
			this.oneDevProject = oneDevProject;
		}

		@Editable(order=300, name="GitHub API URL", description="GitHub API URL for this repository. "
				+ "Leave empty to use default.")
		public String getGitHubApiUrl() {
			return gitHubApiUrl;
		}

		public void setGitHubApiUrl(String gitHubApiUrl) {
			this.gitHubApiUrl = gitHubApiUrl;
		}

		@Editable(order=400, name="Access Token", description="GitHub personal access token for bidirectional sync")
		@Password
		public String getAccessToken() {
			return accessToken;
		}

		public void setAccessToken(String accessToken) {
			this.accessToken = accessToken;
		}
	}
}