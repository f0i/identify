import { UserManager } from "oidc-client-ts";

const userManager = new UserManager({
  authority: "https://identify-ci5vmz.us1.zitadel.cloud",
  client_id: "327788236128717664",
  redirect_uri: "https://login.f0i.de/callback.html",
});

userManager.signinPopupCallback().catch(console.error);
