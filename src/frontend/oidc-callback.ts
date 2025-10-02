window.onload = () => {
  const paramsHash = new URLSearchParams(window.location.hash.slice(1));
  const id_token = paramsHash.get("id_token");
  const codeHash = paramsHash.get("code");
  const stateHash = paramsHash.get("state");

  const params = new URLSearchParams(window.location.search);
  const code = params.get("code");
  const state = params.get("state"); // Not strictly needed for PKCE, but good practice

  if (id_token) {
    window.opener.postMessage(
      { type: "oidc_auth_success", id_token, state: stateHash },
      window.origin,
    );
    window.close();
  } else if (code) {
    window.opener.postMessage(
      { type: "oidc_auth_code", code, state },
      window.origin,
    );
    window.close();
  } else {
    window.opener.postMessage(
      { type: "oidc_auth_error", error: "Authorization code not found" },
      window.origin,
    );
    window.close();
  }
};
