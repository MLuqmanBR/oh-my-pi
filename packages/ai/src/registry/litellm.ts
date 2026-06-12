import type { OAuthController, OAuthLoginCallbacks } from "./oauth/types";
import type { ProviderDefinition } from "./types";

const AUTH_URL = "https://docs.litellm.ai/docs/proxy/deploy";

/**
 * Login to LiteLLM.
 *
 * Opens browser to LiteLLM setup docs, prompts user to paste their API key.
 * Returns the API key directly (not OAuthCredentials - this isn't OAuth).
 */
export async function loginLiteLLM(options: OAuthController): Promise<string> {
	if (!options.onPrompt) {
		throw new Error("LiteLLM login requires onPrompt callback");
	}

	options.onAuth?.({
		url: AUTH_URL,
		instructions: "Run LiteLLM proxy (default http://localhost:4000/v1), then copy your master key or virtual key",
	});

	const apiKey = await options.onPrompt({
		message: "Paste your LiteLLM API key (optional, leave empty for local no-auth)",
		placeholder: "sk-...",
		allowEmpty: true,
	});

	if (options.signal?.aborted) {
		throw new Error("Login cancelled");
	}

	const trimmed = apiKey.trim();
	return trimmed || "litellm-local";
}

export const litellmProvider = {
	id: "litellm",
	name: "LiteLLM",
	login: (cb: OAuthLoginCallbacks) => loginLiteLLM(cb),
} as const satisfies ProviderDefinition;
