import { UserManager, WebStorageStateStore } from "oidc-client-ts";
import { ZitadelConfig } from "./auth-config";
import { StatusUpdate } from "./identify/icrc";

export async function initZitadel(
  zitadelConfig: ZitadelConfig,
  nonce: string,
  buttonId: string,
  autoSignIn: boolean = false,
  statusCallback: (update: StatusUpdate) => void,
): Promise<string> {
  const options = {
    ...zitadelConfig,
    response_type: "code",
    scope: "openid profile email",
    // Optional: store session in localStorage instead of sessionStorage
    userStore: new WebStorageStateStore({ store: window.localStorage }),
  };
  console.log(options);
  const userManager = new UserManager(options);

  async function signin() {
    const user = await userManager.signinPopup({ nonce });
    console.log("Access token:", user.access_token);
    console.log("ID token:", user.id_token);
    if (!user.id_token) {
      throw "Failed to sing in with Zitadel: missing ID Token";
    }
    return user.id_token;
  }

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
