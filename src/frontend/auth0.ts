import { createAuth0Client } from "@auth0/auth0-spa-js";
import { AUTH0 } from "./auth-config";

window.onload = async () => {
  let auth0Client = await createAuth0Client({
    ...AUTH0,
    authorizationParams: { nonce: "asdftestnonce" },
  });

  // Handle callback from Auth0
  if (
    window.location.search.includes("code=") &&
    window.location.search.includes("state=")
  ) {
    const res = await auth0Client.handleRedirectCallback();
    console.log("Auth0 callback handled:", res);
    window.history.replaceState({}, document.title, "/auth0.html");
  }

  // Check if user is authenticated
  console.log("check isAuthenticated()");
  if (await auth0Client.isAuthenticated()) {
    console.log("call getIdTokenClaims()");
    auth0Client.getIdTokenClaims().then((claims) => {
      if (!claims)
        throw new Error(
          "Authentication errror: Authentication provider Auth0 did not return ID token",
        );
      console.log("Auth0 ID Token Claims:", claims.nonce, claims);
    });
  }

  // Connect signin function to login button
  const signin = async () => {
    await auth0Client.loginWithRedirect({
      authorizationParams: {
        redirect_uri: window.location.origin + "/auth0.html",
        nonce: "testnonce1234567890",
      },
    });
  };
  const login = document.getElementById("auth0-login")!;
  login.addEventListener("click", () => signin());
};
