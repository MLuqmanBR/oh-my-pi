import type { OAuthController } from "./oauth/types";
import type { ProviderDefinition } from "./types";

const PROVIDER_ID = "llama.cpp";

export const LLAMA_CPP_LOCAL_TOKEN = "llama-cpp-local";

export async function loginLlamaCpp(options: OAuthController): Promise<string> {
	if (!options.onPrompt) {
		throw new Error(`${PROVIDER_ID} login requires onPrompt callback`);
	}

	const apiKey = await options.onPrompt({
		message: "Optional: Paste llama.cpp API key (to customize endpoint URL, set LLAMA_CPP_BASE_URL env var)",
		placeholder: LLAMA_CPP_LOCAL_TOKEN,
		allowEmpty: true,
	});

	if (options.signal?.aborted) {
		throw new Error("Login cancelled");
	}

	const trimmed = apiKey.trim();
	return trimmed || LLAMA_CPP_LOCAL_TOKEN;
}

export const llamaCppProvider = {
	id: "llama.cpp",
	name: "llama.cpp (Local OpenAI-compatible)",
	login: loginLlamaCpp,
} as const satisfies ProviderDefinition;
