import type { OAuthController, OAuthLoginCallbacks } from "./oauth/types";
import type { ProviderDefinition } from "./types";

const PROVIDER_ID = "omniroute";

async function loginOmniRoute(options: OAuthController): Promise<string> {
	if (!options.onPrompt) {
		throw new Error(`${PROVIDER_ID} login requires onPrompt callback`);
	}

	const apiKey = await options.onPrompt({
		message: "Paste your OmniRoute key (optional, set OMNIROUTE_BASE_URL env var to change the endpoint)",
		placeholder: "omniroute-...",
		allowEmpty: true,
	});

	if (options.signal?.aborted) {
		throw new Error("Login cancelled");
	}

	const trimmed = apiKey.trim();
	return trimmed || "omniroute-local";
}

export const omnirouteProvider = {
	id: "omniroute",
	name: "OmniRoute (Local OpenAI-compatible)",
	login: (cb: OAuthLoginCallbacks) => loginOmniRoute(cb),
} as const satisfies ProviderDefinition;
