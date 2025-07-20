package io.onedev.server.plugin.webhook.github;

import com.fasterxml.jackson.databind.JsonNode;
import io.onedev.server.OneDev;
import io.onedev.server.entitymanager.IssueCommentManager;
import io.onedev.server.entitymanager.IssueManager;
import io.onedev.server.entitymanager.PullRequestManager;
import io.onedev.server.entitymanager.UserManager;
import io.onedev.server.model.Issue;
import io.onedev.server.model.IssueComment;
import io.onedev.server.model.Project;
import io.onedev.server.model.PullRequest;
import io.onedev.server.model.User;
import io.onedev.server.model.support.LastActivity;
import org.joda.time.format.ISODateTimeFormat;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.inject.Inject;
import javax.inject.Singleton;
import java.util.Date;

@Singleton
public class GitHubSyncService {
	
	private static final Logger logger = LoggerFactory.getLogger(GitHubSyncService.class);
	
	private final IssueManager issueManager;
	private final IssueCommentManager issueCommentManager;
	private final PullRequestManager pullRequestManager;
	private final UserManager userManager;
	
	@Inject
	public GitHubSyncService(IssueManager issueManager, 
							IssueCommentManager issueCommentManager,
							PullRequestManager pullRequestManager,
							UserManager userManager) {
		this.issueManager = issueManager;
		this.issueCommentManager = issueCommentManager;
		this.pullRequestManager = pullRequestManager;
		this.userManager = userManager;
	}
	
	public void syncCommitFromGitHub(Project project, String commitSha, String commitMessage, String branch) {
		// Implementation for syncing commits
		logger.info("Syncing commit {} to project {} branch {}", commitSha, project.getPath(), branch);
		
		// TODO: Implement git operations to sync the commit
		// This would involve fetching from the GitHub repository and updating the OneDev repository
	}
	
	public void createIssueFromGitHub(Project project, JsonNode issueNode) {
		Issue issue = new Issue();
		issue.setProject(project);
		issue.setNumber(issueNode.get("number").asLong());
		issue.setTitle(issueNode.get("title").asText());
		issue.setDescription(issueNode.get("body").asText(null));
		issue.setNumberScope(project.getForkRoot());
		
		// Set state based on GitHub state
		if ("closed".equals(issueNode.get("state").asText())) {
			issue.setState("Closed"); // TODO: Use configured closed state
		} else {
			issue.setState("Open"); // TODO: Use configured open state
		}
		
		// Set submitter
		JsonNode userNode = issueNode.get("user");
		if (userNode != null) {
			User submitter = findOrCreateUserFromGitHub(userNode);
			issue.setSubmitter(submitter);
		} else {
			issue.setSubmitter(userManager.getUnknown());
		}
		
		// Set dates
		Date createdAt = parseGitHubDate(issueNode.get("created_at").asText());
		issue.setSubmitDate(createdAt);
		
		LastActivity lastActivity = new LastActivity();
		lastActivity.setDescription("Opened");
		lastActivity.setDate(createdAt);
		lastActivity.setUser(issue.getSubmitter());
		issue.setLastActivity(lastActivity);
		
		issueManager.create(issue);
		logger.info("Created issue #{} in project {}", issue.getNumber(), project.getPath());
	}
	
	public void updateIssueFromGitHub(Issue issue, JsonNode issueNode) {
		// Update title and description
		issue.setTitle(issueNode.get("title").asText());
		issue.setDescription(issueNode.get("body").asText(null));
		
		// Update state
		String githubState = issueNode.get("state").asText();
		if ("closed".equals(githubState)) {
			issue.setState("Closed"); // TODO: Use configured closed state
		} else {
			issue.setState("Open"); // TODO: Use configured open state
		}
		
		issueManager.update(issue);
		logger.info("Updated issue #{} in project {}", issue.getNumber(), issue.getProject().getPath());
	}
	
	public void updateIssueAssignmentsFromGitHub(Issue issue, JsonNode issueNode) {
		// TODO: Implement assignment sync
		logger.info("Updating assignments for issue #{} in project {}", 
				issue.getNumber(), issue.getProject().getPath());
	}
	
	public void updateIssueLabelsFromGitHub(Issue issue, JsonNode issueNode) {
		// TODO: Implement label sync
		logger.info("Updating labels for issue #{} in project {}", 
				issue.getNumber(), issue.getProject().getPath());
	}
	
	public void createIssueCommentFromGitHub(Issue issue, JsonNode commentNode) {
		IssueComment comment = new IssueComment();
		comment.setIssue(issue);
		comment.setContent(commentNode.get("body").asText());
		
		// Set user
		JsonNode userNode = commentNode.get("user");
		if (userNode != null) {
			User user = findOrCreateUserFromGitHub(userNode);
			comment.setUser(user);
		} else {
			comment.setUser(userManager.getUnknown());
		}
		
		// Set date
		Date createdAt = parseGitHubDate(commentNode.get("created_at").asText());
		comment.setDate(createdAt);
		
		issueCommentManager.create(comment);
		logger.info("Created comment for issue #{} in project {}", 
				issue.getNumber(), issue.getProject().getPath());
	}
	
	public void updateIssueCommentFromGitHub(Issue issue, JsonNode commentNode, String action) {
		// TODO: Find and update existing comment
		logger.info("Processing comment {} for issue #{} in project {}", 
				action, issue.getNumber(), issue.getProject().getPath());
	}
	
	public void createPullRequestFromGitHub(Project project, JsonNode prNode) {
		// TODO: Implement pull request creation
		logger.info("Creating pull request #{} in project {}", 
				prNode.get("number").asLong(), project.getPath());
	}
	
	public void updatePullRequestFromGitHub(PullRequest pullRequest, JsonNode prNode) {
		// TODO: Implement pull request updates
		logger.info("Updating pull request #{} in project {}", 
				pullRequest.getNumber(), pullRequest.getTargetProject().getPath());
	}
	
	public void syncPullRequestCommitsFromGitHub(PullRequest pullRequest, JsonNode prNode) {
		// TODO: Implement PR commit sync
		logger.info("Syncing commits for pull request #{} in project {}", 
				pullRequest.getNumber(), pullRequest.getTargetProject().getPath());
	}
	
	public void handleBranchTagCreate(Project project, String refType, String ref, JsonNode payload) {
		logger.info("Handling {} create: {} in project {}", refType, ref, project.getPath());
		// TODO: Implement branch/tag creation handling
	}
	
	public void handleBranchTagDelete(Project project, String refType, String ref) {
		logger.info("Handling {} delete: {} in project {}", refType, ref, project.getPath());
		// TODO: Implement branch/tag deletion handling
	}
	
	public void updateProjectFromGitHub(Project project, JsonNode repoNode) {
		// Update project description
		String description = repoNode.get("description").asText(null);
		if (description != null) {
			project.setDescription(description);
		}
		
		logger.info("Updated project {} from GitHub repository", project.getPath());
	}
	
	public void updateProjectArchiveStatus(Project project, boolean archived) {
		// TODO: Implement project archiving
		logger.info("Setting archive status for project {}: {}", project.getPath(), archived);
	}
	
	public void updateProjectVisibility(Project project, boolean isPrivate) {
		// TODO: Implement project visibility changes
		logger.info("Setting visibility for project {}: {}", project.getPath(), 
				isPrivate ? "private" : "public");
	}
	
	private User findOrCreateUserFromGitHub(JsonNode userNode) {
		String login = userNode.get("login").asText();
		String email = userNode.get("email").asText(null);
		
		// Try to find user by email first
		if (email != null) {
			User user = userManager.findByVerifiedEmailAddress(email);
			if (user != null) {
				return user;
			}
		}
		
		// Try to find by login/username
		User user = userManager.findByName(login);
		if (user != null) {
			return user;
		}
		
		// Return unknown user if not found
		// In a production system, you might want to create new users automatically
		// or have a more sophisticated user mapping mechanism
		return userManager.getUnknown();
	}
	
	private Date parseGitHubDate(String dateString) {
		try {
			return ISODateTimeFormat.dateTimeNoMillis().parseDateTime(dateString).toDate();
		} catch (Exception e) {
			logger.warn("Error parsing GitHub date: {}", dateString);
			return new Date();
		}
	}
}