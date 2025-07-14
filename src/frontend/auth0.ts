import { createAuth0Client } from "@auth0/auth0-spa-js";
import { AUTH0 } from "./auth-config";

export async function initAuth0(
  auth0Config: { clientId: string; domain: string },
  nonce: string,
  buttonId: string,
  autoSignIn: boolean = false,
): Promise<{ credential: string }> {
  return new Promise(async (resolve, _reject) => {
    // prompt "none" will try to sliently sign in, "login" will always prompt for re-authentication
    let prompt: "none" | "login" = autoSignIn ? "none" : "login";
    let auth0Client = await createAuth0Client({
      ...auth0Config,
      authorizationParams: { nonce, prompt },
    });

    const checkAuth = async () => {
      if (await auth0Client.isAuthenticated()) {
        //console.log("client is authenticated");
        auth0Client.getIdTokenClaims().then((claims) => {
          if (!claims) {
            throw new Error(
              "Authentication errror: Authentication provider Auth0 did not return an ID token",
            );
          }
          //console.log("Auth0 ID Token Claims:", claims);
          resolve({ credential: claims.__raw });
        });
      }
    };

    if (autoSignIn) {
      await checkAuth();
    } else if (await auth0Client.isAuthenticated()) {
      console.log("User was signed in, but autoSignIn is disabled.");
    }
    // Connect signin function to login button
    const signin = async () => {
      await auth0Client.loginWithPopup({
        authorizationParams: {
          redirect_uri: window.location.href,
          nonce,
          prompt,
        },
      });

      await checkAuth();
    };
    const login = document.getElementById(buttonId)!;
    login.addEventListener("click", () => signin());
  });
}

/// Example usage:
window.onload = async () => {
  const token = await initAuth0(AUTH0, "test-nonce", "auth0-login", false);
  console.log("auth0 token:", token);
};
