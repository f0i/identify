export const IDENTITY_PROVIDER = "https://login.f0i.de";

export const ZITADEL = {
  authority: "https://identify-ci5vmz.us1.zitadel.cloud",
  client_id: "327788236128717664",
  redirect_uri: "https://login.f0i.de/callback.html",
};

export const AUTH0 = {
  domain: "identify.uk.auth0.com",
  clientId: "oUmJhfEd58KnHhaPhInnIAWFREw8MPoJ",
};

export const GSI = {
  // TODO:? consider loading clientID from the backend to make configuration easier
  client_id:
    "376650571127-vpotkr4kt7d76o8mki09f7a2vopatdp6.apps.googleusercontent.com",
};

export type GoogleConfig = typeof GSI;
export type Auth0Config = typeof AUTH0;
export type ZitadelConfig = typeof ZITADEL;

export type AuthConfig = GoogleConfig | Auth0Config | ZitadelConfig;

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
