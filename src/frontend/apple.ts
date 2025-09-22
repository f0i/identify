import { AppleConfig } from "./auth-config";
import { StatusUpdate } from "./identify/icrc";

declare global {
  interface Window {
    AppleID: any;
  }
}

export async function initApple(
  appleConfig: AppleConfig,
  nonce: string,
  buttonId: string,
  autoSignIn: boolean = true,
  statusCallback: (update: StatusUpdate) => void,
): Promise<string> {
  await loadAppleClient();

  window.AppleID.auth.init({
    clientId: appleConfig.client_id,
    scope: "name email",
    redirectURI: appleConfig.redirect_uri,
    usePopup: true,
    nonce,
  });

  const signin = async (): Promise<string> => {
    console.log("Apple: signin called");
    const response = await window.AppleID.auth.signIn();
    const idToken = response.authorization.id_token;
    if (!idToken) {
      throw new Error(
        "Authentication error: Apple did not return an ID token.",
      );
    }
    console.log("Apple: got id_token via popup.");
    return idToken;
  };

  const attachButton = (): Promise<string> => {
    const login = document.getElementById(buttonId);
    if (login) {
      console.log("Apple: attaching listener to login button", login);
      return new Promise((resolve, reject) => {
        login.addEventListener("click", () => signin().then(resolve, reject));
      });
    } else {
      throw new Error("Login button not found");
    }
  };

  if (autoSignIn) {
    try {
      return await signin();
    } catch (e) {
      statusCallback({ status: "error", message: `${e}` });
    }
  }

  while (true) {
    try {
      statusCallback({ status: "ready", message: "" });
      return await attachButton();
    } catch (e) {
      // TODO: check if error is not recoverable
      throw e;
    }
  }
}

function loadAppleClient(): Promise<void> {
  return new Promise((resolve, reject) => {
    if (document.getElementById("apple-signin-client")) {
      resolve();
      return;
    }
    const script = document.createElement("script");
    script.src =
      "https://appleid.cdn-apple.com/appleauth/static/jsapi/appleid/1/en_US/appleid.auth.js";
    script.id = "apple-signin-client";
    script.async = true;
    script.defer = true;

    script.onload = () => resolve();
    script.onerror = () =>
      reject(new Error("Failed to load Apple Sign-In client script"));

    document.head.appendChild(script);
  });
}
