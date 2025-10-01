import { canisterId, createActor } from "../declarations/backend";
import { unwrapProvider } from "./identify/utils";

export const IDENTITY_PROVIDER = "https://login.f0i.de";

export const GSI = {
  auth_type: "google",
  name: "Google",
  client_id:
    "376650571127-vpotkr4kt7d76o8mki09f7a2vopatdp6.apps.googleusercontent.com",
  authURL: "https://accounts.google.com/o/oauth2/v2/auth",
  authScope: "openid profile email",
  configURL: "https://accounts.google.com/gsi/fedcm.json",
};

export const ZITADEL = {
  authority: "https://identify-ci5vmz.us1.zitadel.cloud",
  client_id: "327788236128717664",
};

export const AUTH0 = {
  domain: "identify.uk.auth0.com",
  clientId: "oUmJhfEd58KnHhaPhInnIAWFREw8MPoJ",
};

export const GITHUB: PKCEConfig = {
  auth_type: "PKCE",
  name: "Google",
  authorization_url: "https://github.com/login/oauth/authorize",
  token_url: "https://github.com/login/oauth/access_token",
  user_info_endpoint: "https://api.github.com/user",
  client_id: "Ov23liMbdP36K0AIWTgl",
};

export const X: PKCEConfig = {
  auth_type: "PKCE",
  name: "X",
  authorization_url: "https://x.com/i/oauth2/authorize",
  token_url: "https://api.x.com/2/oauth2/token",
  user_info_endpoint: "https://api.x.com/2/users/me",
  client_id: "c1Y3cWhOekU1SFlwVkJCNlFmbWU6MTpjaQ",
};

export const APPLE = {
  auth_type: "apple",
  name: "Apple",
  client_id: "<TODO>",
  authority: "https://appleid.apple.com",
  authorization_url: "https://appleid.apple.com/auth/authorize",
  response_type: "code",
  scope: "openid email name",
};

export const LINKED_IN: OIDCConfig = {
  auth_type: "OIDC",
  name: "LinkedIn",
  client_id: "<TODO>",
  authority: "https://www.linkedin.com/oauth/",
  authorization_url: "https://www.linkedin.com/oauth/v2/authorization",
  scope: "openid profile email",
  response_type: "code",
};

export type GoogleConfig = typeof GSI;
export type Auth0Config = typeof AUTH0;
export type ZitadelConfig = typeof ZITADEL;
export type GithubConfig = PKCEConfig;
export type XConfig = typeof X;
export type AppleConfig = typeof APPLE;

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
};

const getProviderConfigs = async (): Promise<AuthConfig[]> => {
  const isDev = process.env.DFX_NETWORK !== "ic";
  const host = isDev ? "http://localhost:4943" : "https://icp-api.io";
  const backend = createActor(canisterId, { agentOptions: { host } });
  const providers = await backend.getProviders();
  console.log("Loaded provider configurations:", providers);
  const providerConfigs: AuthConfig[] = providers.map(unwrapProvider);
  return providerConfigs;
};
let providersPromise = getProviderConfigs(); // TODO: retry on error

export const getProvider = async (name: string): Promise<AuthConfig> => {
  let providers: AuthConfig[] = await providersPromise;
  for (const provider of providers) {
    if (provider.name.toLowerCase() === name.toLowerCase()) return provider;
  }
  console.error("Provider not found:", name, "available:", providers);
  throw "Provider not found: " + name;
};

export function getOIDCConfig(config: AuthConfig): OIDCConfig {
  if (config.auth_type === "OIDC") return config as OIDCConfig;
  throw "Invalid config";
}

export function getPKCEConfig(config: AuthConfig): PKCEConfig {
  if (config.auth_type === "PKCE") return config as PKCEConfig;
  throw "Invalid config";
}
