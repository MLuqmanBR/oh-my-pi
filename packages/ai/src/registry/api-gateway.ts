import type { OAuthController, OAuthLoginCallbacks } from "./oauth/types";
import type { ProviderDefinition } from "./types";

const PROVIDER_ID = "api-gateway";

async function loginApiGateway(options: OAuthController): Promise<string> {
	if (!options.onPrompt) {
		throw new Error(`${PROVIDER_ID} login requires onPrompt callback`);
	}

	const apiKey = await options.onPrompt({
		message: "Paste your API Gateway key (optional, set API_GATEWAY_BASE_URL env var to change the endpoint)",
		placeholder: "api-gateway-...",
		allowEmpty: true,
	});

	if (options.signal?.aborted) {
		throw new Error("Login cancelled");
	}

	const trimmed = apiKey.trim();
	return trimmed || "api-gateway-local";
}

export const apiGatewayProvider = {
	id: "api-gateway",
	name: "API Gateway (Local OpenAI-compatible)",
	login: (cb: OAuthLoginCallbacks) => loginApiGateway(cb),
} as const satisfies ProviderDefinition;
