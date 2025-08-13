import { UserManager, WebStorageStateStore } from "oidc-client-ts";
import { ZITADEL, ZitadelConfig } from "./auth-config";

export async function initZitadel(
  zitadelConfig: ZitadelConfig,
  nonce: string,
  buttonId: string,
  autoSignIn: boolean = false,
): Promise<string> {
  return new Promise(async (resolve, _reject) => {
    const options = {
      ...zitadelConfig,
      response_type: "code",
      scope: "openid profile email",
      // Optional: store session in localStorage instead of sessionStorage
      userStore: new WebStorageStateStore({ store: window.localStorage }),
    };
    console.log(options);
    const userManager = new UserManager(options);

    async function signinPopup() {
      const user = await userManager.signinPopup({ nonce });
      console.log("Access token:", user.access_token);
      console.log("ID token:", user.id_token);
      if (!user.id_token) {
        throw "Failed to sing in with Zitadel: missing ID Token";
      }
      resolve(user.id_token);
    }

    const login = document.getElementById(buttonId)!;
    login.addEventListener("click", () => signinPopup());
  });
}

//window.onload = () => {
//  console.log("onload");
//  const login = document.getElementById("zitadel-login")!;
//  login.addEventListener("click", () => signinPopup());
//};
