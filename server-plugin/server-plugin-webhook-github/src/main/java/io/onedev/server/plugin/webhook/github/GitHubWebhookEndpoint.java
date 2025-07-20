package io.onedev.server.plugin.webhook.github;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.onedev.commons.utils.ExplicitException;
import io.onedev.server.OneDev;
import io.onedev.server.entitymanager.ProjectManager;
import io.onedev.server.model.Project;
import io.onedev.server.rest.jersey.JerseyConfigurator;
import io.onedev.server.security.SecurityUtils;
import org.apache.commons.lang3.StringUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import javax.inject.Inject;
import javax.inject.Singleton;
import javax.ws.rs.*;
import javax.ws.rs.core.MediaType;
import javax.ws.rs.core.Response;
import java.io.IOException;
import java.security.InvalidKeyException;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;

@Path("/github-webhook")
@Consumes(MediaType.APPLICATION_JSON)
@Singleton
public class GitHubWebhookEndpoint implements JerseyConfigurator {
	
	private static final Logger logger = LoggerFactory.getLogger(GitHubWebhookEndpoint.class);
	
	private final GitHubWebhookHandler webhookHandler;
	private final ProjectManager projectManager;
	private final ObjectMapper objectMapper;
	
	@Inject
	public GitHubWebhookEndpoint(GitHubWebhookHandler webhookHandler, ProjectManager projectManager) {
		this.webhookHandler = webhookHandler;
		this.projectManager = projectManager;
		this.objectMapper = OneDev.getInstance(ObjectMapper.class);
	}
	
	@POST
	public Response handleWebhook(
			@HeaderParam("X-GitHub-Event") String eventType,
			@HeaderParam("X-GitHub-Delivery") String deliveryId,
			@HeaderParam("X-Hub-Signature-256") String signature,
			String payload) {
		
		logger.info("Received GitHub webhook: event={}, delivery={}", eventType, deliveryId);
		
		try {
			JsonNode payloadNode = objectMapper.readTree(payload);
			
			// Verify webhook signature if configured
			if (StringUtils.isNotBlank(signature)) {
				if (!verifySignature(payload, signature)) {
					logger.warn("Invalid webhook signature for delivery: {}", deliveryId);
					return Response.status(Response.Status.UNAUTHORIZED)
							.entity("Invalid signature").build();
				}
			}
			
			// Extract repository information
			JsonNode repoNode = payloadNode.get("repository");
			if (repoNode == null) {
				logger.warn("No repository information in webhook payload");
				return Response.status(Response.Status.BAD_REQUEST)
						.entity("No repository information").build();
			}
			
			String repoFullName = repoNode.get("full_name").asText();
			Project project = findProjectByGitHubRepo(repoFullName);
			
			if (project == null) {
				logger.info("No matching OneDev project found for GitHub repository: {}", repoFullName);
				return Response.ok().entity("Repository not configured").build();
			}
			
			// Process the webhook event
			switch (eventType) {
				case "push":
					webhookHandler.handlePushEvent(project, payloadNode);
					break;
				case "pull_request":
					webhookHandler.handlePullRequestEvent(project, payloadNode);
					break;
				case "issues":
					webhookHandler.handleIssueEvent(project, payloadNode);
					break;
				case "issue_comment":
					webhookHandler.handleIssueCommentEvent(project, payloadNode);
					break;
				case "create":
				case "delete":
					webhookHandler.handleBranchTagEvent(project, payloadNode, eventType);
					break;
				case "repository":
					webhookHandler.handleRepositoryEvent(project, payloadNode);
					break;
				default:
					logger.debug("Unhandled GitHub webhook event type: {}", eventType);
					return Response.ok().entity("Event type not handled").build();
			}
			
			return Response.ok().entity("Webhook processed successfully").build();
			
		} catch (Exception e) {
			logger.error("Error processing GitHub webhook", e);
			return Response.status(Response.Status.INTERNAL_SERVER_ERROR)
					.entity("Error processing webhook: " + e.getMessage()).build();
		}
	}
	
	private boolean verifySignature(String payload, String signature) {
		String webhookSecret = getWebhookSecret();
		if (StringUtils.isBlank(webhookSecret)) {
			logger.warn("Webhook secret not configured, skipping signature verification");
			return true;
		}
		
		try {
			Mac sha256Hmac = Mac.getInstance("HmacSHA256");
			SecretKeySpec secretKey = new SecretKeySpec(webhookSecret.getBytes(), "HmacSHA256");
			sha256Hmac.init(secretKey);
			
			byte[] hash = sha256Hmac.doFinal(payload.getBytes());
			String expectedSignature = "sha256=" + HexFormat.of().formatHex(hash);
			
			return expectedSignature.equals(signature);
			
		} catch (NoSuchAlgorithmException | InvalidKeyException e) {
			logger.error("Error verifying webhook signature", e);
			return false;
		}
	}
	
	private String getWebhookSecret() {
		// TODO: Implement webhook secret configuration
		// This should be configurable in OneDev settings
		return System.getProperty("github.webhook.secret");
	}
	
	private Project findProjectByGitHubRepo(String repoFullName) {
		// Try to find project by GitHub repository URL or name mapping
		// This is a simplified implementation - in production, you'd want
		// a more sophisticated mapping mechanism
		
		for (Project project : projectManager.query()) {
			if (project.getName().equals(repoFullName) || 
				project.getPath().equals(repoFullName) ||
				project.getName().equals(repoFullName.substring(repoFullName.lastIndexOf('/') + 1))) {
				return project;
			}
		}
		return null;
	}
	
	@Override
	public void configure() {
		// Jersey configuration if needed
	}
}