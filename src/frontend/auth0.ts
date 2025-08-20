import { createAuth0Client } from "@auth0/auth0-spa-js";
import { Auth0Config } from "./auth-config";
import { StatusUpdate } from "./identify/icrc";

export async function initAuth0(
  auth0Config: Auth0Config,
  nonce: string,
  buttonId: string,
  autoSignIn: boolean = true,
  statusCallback: (update: StatusUpdate) => void,
): Promise<string> {
  return new Promise(async (resolve, _reject) => {
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

    const attachButton = () => {
      const login = document.getElementById(buttonId);
      if (login) {
        console.log("Adding listner to login button", login);
        login.addEventListener("click", () => signin());
      } else {
        console.error("Login button not found");
      }
    };

    if (autoSignIn) {
      try {
        await signin();
      } catch (e: any) {
        console.log("Singin attempt failed:", e.toString());
        if (e.toString().indexOf("Unable to open a popup") >= 0) {
          console.log("popup failed, enable the button.");
          statusCallback({
            status: "ready",
            message: "",
          });
          attachButton();
        } else {
          throw e;
        }
      }
    } else {
      // only attetch
      attachButton();
    }
  });
}
