package io.onedev.server.plugin.webhook.github;

import io.onedev.commons.loader.AbstractPluginModule;

public class GitHubWebhookModule extends AbstractPluginModule {

	public static final String NAME = "GitHub Webhook Integration";
	
	@Override
	protected void configure() {
		super.configure();
		bind(GitHubWebhookHandler.class);
		contribute(GitHubWebhookEndpoint.class);
	}
}