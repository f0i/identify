export const IDENTITY_PROVIDER = "https://login.f0i.de";

export const GSI = {
  client_id:
    "376650571127-vpotkr4kt7d76o8mki09f7a2vopatdp6.apps.googleusercontent.com",
  authURL: "https://accounts.google.com/o/oauth2/v2/auth",
  authScope: "openid profile email",
  configURL: "https://accounts.google.com/gsi/fedcm.json",
};

export const GOOGLE = {
  authority: "https://accounts.google.com/",
};

export const ZITADEL = {
  authority: "https://identify-ci5vmz.us1.zitadel.cloud",
  client_id: "327788236128717664",
  redirect_uri: IDENTITY_PROVIDER + "/callback.html",
};

export const AUTH0 = {
  domain: "identify.uk.auth0.com",
  clientId: "oUmJhfEd58KnHhaPhInnIAWFREw8MPoJ",
};

export const GITHUB = {
  authorizationUrl: "https://github.com/login/oauth/authorize",
  tokenUrl: "https://github.com/login/oauth/access_token",
  userInfoEndpoint: "https://api.github.com/user",
  clientId: "Ov23liMbdP36K0AIWTgl",
  redirect: IDENTITY_PROVIDER + "/pkce-callback.html",
};

export const X = {
  authorizationUrl: "https://x.com/i/oauth2/authorize",
  tokenUrl: "https://api.x.com/2/oauth2/token",
  userInfoEndpoint: "https://api.x.com/2/users/me",
  clientId: "c1Y3cWhOekU1SFlwVkJCNlFmbWU6MTpjaQ",
  redirect: IDENTITY_PROVIDER + "/pkce-callback.html",
};

export const APPLE = {
  client_id: "<TODO>",
  authority: "https://appleid.apple.com",
  response_type: "code",
  scope: "openid email name",
  redirect_uri: IDENTITY_PROVIDER + "/callback.html",
};

export const LINKED_IN = {
  client_id: "<TODO>",
  authority: "https://www.linkedin.com/oauth/",
  scope: "oppenid pfrofile email",
  redirect_uri: IDENTITY_PROVIDER + "/callback.html",
};

export type GoogleConfig = typeof GSI;
export type Auth0Config = typeof AUTH0;
export type ZitadelConfig = typeof ZITADEL;
export type GithubConfig = typeof GITHUB;
export type XConfig = typeof X;
export type AppleConfig = typeof APPLE;

export type OIDCConfig = {
  client_id: string;
  authority: string;
  scope: string;
  response_type: "code" | "id_token";
  fedCM_config_url?: string;
};

export type AuthConfig =
  | GoogleConfig
  | Auth0Config
  | ZitadelConfig
  | GithubConfig
  | XConfig
  | OIDCConfig;

export type PKCEConfig = GithubConfig | XConfig;

export function getGoogleConfig(config: AuthConfig): GoogleConfig {
  if ("client_id" in config) return config as GoogleConfig;
  throw "Invalid config";
}

export function getAuth0Config(config: AuthConfig): Auth0Config {
  if ("domain" in config && "clientId" in config) return config as Auth0Config;
  throw "Invalid config";
}

export function getZitadelConfig(config: AuthConfig): ZitadelConfig {
  if (
    "authority" in config &&
    "client_id" in config &&
    "redirect_uri" in config
  )
    return config as ZitadelConfig;
  throw "Invalid config";
}

export function getOIDCConfig(config: AuthConfig): OIDCConfig {
  if (
    "authority" in config &&
    "client_id" in config &&
    "redirect_uri" in config &&
    "scope" in config &&
    "response_type" in config
  )
    return config as OIDCConfig;
  throw "Invalid config";
}

export function getPKCEConfig(config: AuthConfig): PKCEConfig {
  if (
    "authorizationUrl" in config &&
    "tokenUrl" in config &&
    "userInfoEndpoint" in config &&
    "clientId" in config
  ) {
    return config as PKCEConfig;
  }
  throw "Invalid config";
}

export function getGithubConfig(config: AuthConfig): GithubConfig {
  if (
    "authorizationUrl" in config &&
    "tokenUrl" in config &&
    "userInfoEndpoint" in config &&
    "clientId" in config
  ) {
    return config as GithubConfig;
  }
  throw "Invalid config";
}

export function getXConfig(config: AuthConfig): XConfig {
  if (
    "authorizationUrl" in config &&
    "tokenUrl" in config &&
    "userInfoEndpoint" in config &&
    "clientId" in config &&
    "redirect" in config
  ) {
    return config as XConfig;
  }
  throw "Invalid config";
}
