import { UserManager } from "oidc-client-ts";
import { ZITADEL } from "./auth-config";

const userManager = new UserManager(ZITADEL);

userManager.signinPopupCallback().catch(console.error);
