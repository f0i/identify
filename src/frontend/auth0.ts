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
  let prompt: "none" | "login" = "login"; // Always prompt for interactive login if triggered
  let auth0Client = await createAuth0Client({
    ...auth0Config,
    authorizationParams: { nonce, prompt },
  });
  const signin = async (): Promise<string> => {
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
    return claims.__raw;
  };

  const attachButton = (): Promise<string> => {
    const login = document.getElementById(buttonId);
    if (login) {
      console.log("Adding listner to login button", login);
      return new Promise((resolve, reject) => {
        login.addEventListener("click", () => signin().then(resolve, reject));
      });
    } else {
      throw "Login button not found";
    }
  };

  if (autoSignIn) {
    try {
      return await signin();
    } catch (e) {
      // TODO: check if error message should be shown
      statusCallback({ status: "error", message: `${e}` });
    }
  }
  while (true) {
    try {
      statusCallback({ status: "ready", message: "" });
      return await attachButton();
    } catch (e) {
      // TODO: check if error is recoverable
      throw e;
    }
  }
}
