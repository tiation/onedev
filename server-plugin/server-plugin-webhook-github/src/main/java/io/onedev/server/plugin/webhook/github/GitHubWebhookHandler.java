package io.onedev.server.plugin.webhook.github;

import com.fasterxml.jackson.databind.JsonNode;
import io.onedev.server.OneDev;
import io.onedev.server.entitymanager.IssueManager;
import io.onedev.server.entitymanager.PullRequestManager;
import io.onedev.server.entitymanager.UserManager;
import io.onedev.server.git.GitUtils;
import io.onedev.server.model.Issue;
import io.onedev.server.model.Project;
import io.onedev.server.model.PullRequest;
import io.onedev.server.model.User;
import io.onedev.server.persistence.TransactionManager;
import org.apache.commons.lang3.StringUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.inject.Inject;
import javax.inject.Singleton;
import java.util.Date;

@Singleton
public class GitHubWebhookHandler {
	
	private static final Logger logger = LoggerFactory.getLogger(GitHubWebhookHandler.class);
	
	private final TransactionManager transactionManager;
	private final IssueManager issueManager;
	private final PullRequestManager pullRequestManager;
	private final UserManager userManager;
	private final GitHubSyncService syncService;
	
	@Inject
	public GitHubWebhookHandler(TransactionManager transactionManager, 
								IssueManager issueManager,
								PullRequestManager pullRequestManager, 
								UserManager userManager,
								GitHubSyncService syncService) {
		this.transactionManager = transactionManager;
		this.issueManager = issueManager;
		this.pullRequestManager = pullRequestManager;
		this.userManager = userManager;
		this.syncService = syncService;
	}
	
	public void handlePushEvent(Project project, JsonNode payload) {
		transactionManager.run(() -> {
			try {
				String ref = payload.get("ref").asText();
				String beforeSha = payload.get("before").asText();
				String afterSha = payload.get("after").asText();
				
				logger.info("Processing push event for project {}: {} -> {}", 
						project.getPath(), beforeSha, afterSha);
				
				if (ref.startsWith("refs/heads/")) {
					String branch = StringUtils.substringAfter(ref, "refs/heads/");
					
					// Handle branch deletion
					if (afterSha.equals("0000000000000000000000000000000000000000")) {
						logger.info("Branch {} deleted in GitHub repository {}", branch, project.getPath());
						// TODO: Handle branch deletion in OneDev
						return;
					}
					
					// Handle new commits
					JsonNode commits = payload.get("commits");
					if (commits != null && commits.isArray()) {
						for (JsonNode commit : commits) {
							String commitSha = commit.get("id").asText();
							String commitMessage = commit.get("message").asText();
							
							// Sync commit to OneDev if needed
							syncService.syncCommitFromGitHub(project, commitSha, commitMessage, branch);
						}
					}
				}
				
			} catch (Exception e) {
				logger.error("Error processing push event for project " + project.getPath(), e);
			}
		});
	}
	
	public void handlePullRequestEvent(Project project, JsonNode payload) {
		transactionManager.run(() -> {
			try {
				String action = payload.get("action").asText();
				JsonNode prNode = payload.get("pull_request");
				
				Long prNumber = prNode.get("number").asLong();
				String title = prNode.get("title").asText();
				String body = prNode.get("body").asText(null);
				String state = prNode.get("state").asText();
				
				logger.info("Processing pull request event: {} #{} for project {}", 
						action, prNumber, project.getPath());
				
				PullRequest existingPr = pullRequestManager.find(project, prNumber);
				
				switch (action) {
					case "opened":
						if (existingPr == null) {
							// Create new pull request in OneDev
							syncService.createPullRequestFromGitHub(project, prNode);
						}
						break;
						
					case "closed":
					case "reopened":
						if (existingPr != null) {
							// Update pull request status
							syncService.updatePullRequestFromGitHub(existingPr, prNode);
						}
						break;
						
					case "edited":
						if (existingPr != null) {
							// Update pull request details
							syncService.updatePullRequestFromGitHub(existingPr, prNode);
						}
						break;
						
					case "synchronize":
						if (existingPr != null) {
							// Handle new commits to PR
							syncService.syncPullRequestCommitsFromGitHub(existingPr, prNode);
						}
						break;
				}
				
			} catch (Exception e) {
				logger.error("Error processing pull request event for project " + project.getPath(), e);
			}
		});
	}
	
	public void handleIssueEvent(Project project, JsonNode payload) {
		transactionManager.run(() -> {
			try {
				String action = payload.get("action").asText();
				JsonNode issueNode = payload.get("issue");
				
				Long issueNumber = issueNode.get("number").asLong();
				String title = issueNode.get("title").asText();
				String body = issueNode.get("body").asText(null);
				String state = issueNode.get("state").asText();
				
				logger.info("Processing issue event: {} #{} for project {}", 
						action, issueNumber, project.getPath());
				
				Issue existingIssue = issueManager.find(project, issueNumber);
				
				switch (action) {
					case "opened":
						if (existingIssue == null) {
							// Create new issue in OneDev
							syncService.createIssueFromGitHub(project, issueNode);
						}
						break;
						
					case "closed":
					case "reopened":
						if (existingIssue != null) {
							// Update issue state
							syncService.updateIssueFromGitHub(existingIssue, issueNode);
						}
						break;
						
					case "edited":
						if (existingIssue != null) {
							// Update issue details
							syncService.updateIssueFromGitHub(existingIssue, issueNode);
						}
						break;
						
					case "assigned":
					case "unassigned":
						if (existingIssue != null) {
							// Update issue assignments
							syncService.updateIssueAssignmentsFromGitHub(existingIssue, issueNode);
						}
						break;
						
					case "labeled":
					case "unlabeled":
						if (existingIssue != null) {
							// Update issue labels
							syncService.updateIssueLabelsFromGitHub(existingIssue, issueNode);
						}
						break;
				}
				
			} catch (Exception e) {
				logger.error("Error processing issue event for project " + project.getPath(), e);
			}
		});
	}
	
	public void handleIssueCommentEvent(Project project, JsonNode payload) {
		transactionManager.run(() -> {
			try {
				String action = payload.get("action").asText();
				JsonNode issueNode = payload.get("issue");
				JsonNode commentNode = payload.get("comment");
				
				Long issueNumber = issueNode.get("number").asLong();
				Issue issue = issueManager.find(project, issueNumber);
				
				if (issue == null) {
					logger.warn("Issue #{} not found in project {}", issueNumber, project.getPath());
					return;
				}
				
				logger.info("Processing issue comment event: {} for issue #{} in project {}", 
						action, issueNumber, project.getPath());
				
				switch (action) {
					case "created":
						syncService.createIssueCommentFromGitHub(issue, commentNode);
						break;
						
					case "edited":
					case "deleted":
						syncService.updateIssueCommentFromGitHub(issue, commentNode, action);
						break;
				}
				
			} catch (Exception e) {
				logger.error("Error processing issue comment event for project " + project.getPath(), e);
			}
		});
	}
	
	public void handleBranchTagEvent(Project project, JsonNode payload, String eventType) {
		transactionManager.run(() -> {
			try {
				String refType = payload.get("ref_type").asText();
				String ref = payload.get("ref").asText();
				
				logger.info("Processing {} event: {} {} for project {}", 
						eventType, refType, ref, project.getPath());
				
				if ("create".equals(eventType)) {
					syncService.handleBranchTagCreate(project, refType, ref, payload);
				} else if ("delete".equals(eventType)) {
					syncService.handleBranchTagDelete(project, refType, ref);
				}
				
			} catch (Exception e) {
				logger.error("Error processing " + eventType + " event for project " + project.getPath(), e);
			}
		});
	}
	
	public void handleRepositoryEvent(Project project, JsonNode payload) {
		transactionManager.run(() -> {
			try {
				String action = payload.get("action").asText();
				JsonNode repoNode = payload.get("repository");
				
				logger.info("Processing repository event: {} for project {}", action, project.getPath());
				
				switch (action) {
					case "edited":
						// Update project description, settings, etc.
						syncService.updateProjectFromGitHub(project, repoNode);
						break;
						
					case "archived":
					case "unarchived":
						syncService.updateProjectArchiveStatus(project, "archived".equals(action));
						break;
						
					case "privatized":
					case "publicized":
						syncService.updateProjectVisibility(project, "privatized".equals(action));
						break;
				}
				
			} catch (Exception e) {
				logger.error("Error processing repository event for project " + project.getPath(), e);
			}
		});
	}
}