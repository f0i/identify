import { UserManager, WebStorageStateStore } from "oidc-client-ts";
import { ZITADEL } from "./auth-config";

const options = {
  ...ZITADEL,
  response_type: "code",
  scope: "openid profile email",
  // Optional: store session in localStorage instead of sessionStorage
  userStore: new WebStorageStateStore({ store: window.localStorage }),
};
console.log(options);
const userManager = new UserManager(options);

export async function signinPopup() {
  try {
    const user = await userManager.signinPopup();
    console.log("Access token:", user.access_token);
    console.log("ID token:", user.id_token);
  } catch (err) {
    console.error("Signin failed", err);
  }
}

window.onload = () => {
  console.log("onload");
  const login = document.getElementById("zitadel-login")!;
  login.addEventListener("click", () => signinPopup());
};
