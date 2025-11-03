import { canisterId, createActor } from "../declarations/backend";
import { unwrapProvider } from "./identify/utils";

export const IDENTITY_PROVIDER = "https://odoc.login.f0i.de";

export type AuthConfig = OIDCConfig | PKCEConfig;

export type OIDCConfig = {
  auth_type: "OIDC";
  name: string;
  client_id: string;
  scope: string;
  authority: string;
  authorization_url: string;
  response_type: "code" | "id_token";
  fedCM_config_url?: string;
};

export type PKCEConfig = {
  auth_type: "PKCE";
  name: string;
  client_id: string;
  authorization_url: string;
  token_url: string;
  user_info_endpoint: string;
  scope: string;
};

export const isDev = !process.env.DFX_NETWORK?.startsWith("ic");

const getProviderConfigs = async (): Promise<AuthConfig[]> => {
  const host = isDev ? "http://localhost:4943" : "https://icp-api.io";
  const backend = createActor(canisterId, { agentOptions: { host } });
  const providers = await backend.getProviders();
  console.log("Loaded provider configurations:", providers);
  const providerConfigs: AuthConfig[] = providers.map(unwrapProvider);
  return providerConfigs;
};
let providersPromise = getProviderConfigs(); // TODO: retry on error

export const getProviderList = async (): Promise<
  Array<{ name: string; key: string }>
> => {
  const providers = await providersPromise;
  return providers.map((p) => ({
    name: p.name,
    key: p.name.toLowerCase(),
  }));
};

export const getProvider = async (name: string): Promise<AuthConfig> => {
  let providers: AuthConfig[] = await providersPromise;
  for (const provider of providers) {
    if (provider.name.toLowerCase() === name.toLowerCase()) return provider;
  }
  console.error("Provider not found:", name, "available:", providers);
  throw (
    "Provider not found: " +
    name +
    " (available: " +
    providers.map((p) => p.name) +
    ")"
  );
};

export function getOIDCConfig(config: AuthConfig): OIDCConfig {
  if (config.auth_type === "OIDC") return config as OIDCConfig;
  throw "Invalid config";
}

export function getPKCEConfig(config: AuthConfig): PKCEConfig {
  if (config.auth_type === "PKCE") return config as PKCEConfig;
  throw "Invalid config";
}
