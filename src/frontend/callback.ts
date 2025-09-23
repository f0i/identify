import { OidcClientSettings, UserManager } from "oidc-client-ts";

const userManager = new UserManager({} as OidcClientSettings);

userManager.signinPopupCallback().catch(console.error);
