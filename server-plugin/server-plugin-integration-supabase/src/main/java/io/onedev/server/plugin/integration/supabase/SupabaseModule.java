package io.onedev.server.plugin.integration.supabase;

import io.onedev.commons.loader.AbstractPluginModule;

public class SupabaseModule extends AbstractPluginModule {

	public static final String NAME = "Supabase Integration";
	
	@Override
	protected void configure() {
		super.configure();
		bind(SupabaseService.class);
		bind(SupabaseAuthService.class);
		bind(SupabaseRealtimeService.class);
		contribute(SupabaseEndpoint.class);
	}
}