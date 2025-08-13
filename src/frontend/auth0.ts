import { createAuth0Client } from "@auth0/auth0-spa-js";
import { Auth0Config } from "./auth-config";

export async function initAuth0(
  auth0Config: Auth0Config,
  nonce: string,
  buttonId: string,
  autoSignIn: boolean = true,
): Promise<string> {
  console.log("Auth0: initAuth0 called with autoSignIn:", autoSignIn);
  return new Promise(async (resolve, reject) => {
    let prompt: "none" | "login" = "login"; // Always prompt for interactive login if triggered
    let auth0Client = await createAuth0Client({
      ...auth0Config,
      authorizationParams: { nonce, prompt },
    });
    const signin = async (): Promise<boolean> => {
      console.log("Auth0: signin called");

      await auth0Client.loginWithPopup({
        authorizationParams: {
          redirect_uri: window.location.href,
          nonce,
          prompt,
        },
      });
      console.log("Auth0: loginWithPopup successful.");
      const claims = await auth0Client.getIdTokenClaims();
      if (!claims) {
        console.error("Auth0: No claims after popup login");
        throw new Error(
          "Authentication error: Auth0 did not return an ID token after popup.",
        );
      }
      console.log("Auth0: Claims obtained after popup, resolving with token.");
      resolve(claims.__raw);
      return true; // Indicate success
    };

    // --- Core Logic for Auto-triggering ---
    try {
      await signin();
    } catch (e: any) {
      if (
        !e.toString().startsWith("Unable to open a popup for loginWithPopup")
      ) {
        throw e;
      }
      console.log("Auth0: Popup failed. Attaching listener to button.", e);
      // If autoSignIn is false, attach listener to button for manual trigger
      const login = document.getElementById(buttonId);
      if (login) {
        console.log("Adding listner to login button", login);
        login.addEventListener("click", () => signin());
      } else {
        console.error("Login button not found");
        throw e;
      }
    }
  });
}

