import { getAuth0Config, getGithubConfig, getXConfig } from "./auth-config";

window.onload = () => {
  const params = new URLSearchParams(window.location.search);
  const code = params.get("code");
  const state = params.get("state"); // Not strictly needed for PKCE, but good practice

  if (code) {
    // Send the code and state back to the opener
    window.opener.postMessage(
      { type: "pkce_auth_success", code, state },
      "*",
    );
    window.close();
  } else {
    window.opener.postMessage(
      { type: "pkce_auth_error", error: "Authorization code not found" },
      "*",
    );
    window.close();
  }
};
