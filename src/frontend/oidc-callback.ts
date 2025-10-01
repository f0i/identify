window.onload = () => {
  const params = new URLSearchParams(window.location.hash.slice(1));
  const id_token = params.get("id_token");
  const state = params.get("state");

  if (id_token) {
    window.opener.postMessage(
      { type: "oidc_auth_success", id_token, state },
      window.origin,
    );
    window.close();
  } else {
    window.opener.postMessage(
      { type: "pkce_auth_error", error: "Authorization code not found" },
      window.origin,
    );
    window.close();
  }
};
