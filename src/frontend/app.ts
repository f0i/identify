import { AuthClient } from "@dfinity/auth-client";
import { canisterId, createActor } from "../declarations/backend";

declare global {
  interface Window {
    google: any;
  }
}

var authRequest: any = null;

async function initGsi() {
  window.google.accounts.id.initialize({
    client_id:
      "376650571127-vpotkr4kt7d76o8mki09f7a2vopatdp6.apps.googleusercontent.com",
    callback: handleCredentialResponse,
  });

  window.google.accounts.id.renderButton(
    document.getElementById("g_id_signin") as HTMLElement,
    { theme: "outline", size: "large" },
  );

  window.google.accounts.id.prompt();
}

async function checkAuth() {
  const status = document.getElementById("login-status")!;
  const login = document.getElementById("demo-login")!;
  const logout = document.getElementById("demo-logout")!;
  const authClient = await AuthClient.create();
  if (await authClient.isAuthenticated()) {
    console.log("Already authenticated!", authClient.getIdentity());
    authClient.getIdentity();
    // Handle authenticated state (e.g., show user dashboard)
    status.innerText = "Authenticated ...";
    const isDev = process.env.DFX_NETWORK !== "ic";
    const host = isDev ? "http://localhost:4943" : "https://icp-api.io";

    const backend = createActor(canisterId, {
      agentOptions: { host, identity: authClient.getIdentity() },
    });
    status.innerText = await backend
      .getPrincipal()
      .catch((e: any): string => "" + e);
    login.style.display = "none";
    logout.style.display = "inline-block";
  } else {
    status.innerText = "Not authenticated";
    login.style.display = "inline-block";
    logout.style.display = "none";
  }
}

async function initAuth() {
  const authClient = await AuthClient.create({
    idleOptions: {
      idleTimeout: 1000 * 60 * 60 * 24 * 7, // set to 7 days
      disableDefaultIdleCallback: true, // disable the default reload behavior
    },
  });

  // Check if the user is already authenticated
  if (await authClient.isAuthenticated()) {
    console.log("Already authenticated!");
    // Handle authenticated state (e.g., show user dashboard)
  } else {
    // If not authenticated, authenticate with ICgsi
    await authClient.login({
      identityProvider: "https://login.f0i.de",
      onSuccess: () => {
        console.log("Successfully authenticated!");
        checkAuth();
        // Handle successful authentication (e.g., redirect to your app)
      },
      onError: (error) => {
        console.error("Authentication failed", error);
        checkAuth();
        // Handle authentication failure
      },
    });
  }
}

async function resetAuth() {
  const authClient = await AuthClient.create();
  authClient.logout().finally(checkAuth);
}

window.onload = () => {
  console.log("onload: opener:", window.opener);

  if (window.opener) {
    initGsi();

    window.addEventListener("message", (event) => {
      console.log("message", event, "origin", window.location.origin);
      if (event.origin === window.location.origin) {
        console.log("setting data", event.data);
        authRequest = event.data;
      }
    });

    const msg = { kind: "authorize-ready" };
    window.opener.postMessage(msg, "*");
  } else {
    const demo = document.getElementById("demo")!;
    demo.style.display = "block";
    const login = document.getElementById("demo-login")!;
    login.addEventListener("click", initAuth);
    const logout = document.getElementById("demo-logout")!;
    logout.addEventListener("click", resetAuth);
  }

  checkAuth();
};

function handleCredentialResponse(response: any) {
  const idToken = response.credential;
  console.log(response);

  // decode payload
  const payload = JSON.parse(atob(idToken.split(".")[1]));
  const status = document.getElementById("login-status")!;

  const isDev = process.env.DFX_NETWORK !== "ic";
  const host = isDev ? "http://localhost:4943" : "https://icp-api.io";

  const backend = createActor(canisterId, { agentOptions: { host } });

  console.log("payload:", payload, payload.sub);
  backend
    .prepareDelegation(payload.sub, 123454321)
    .then((prepRes) => {
      console.log("prepareDelegation response:", prepRes);
      if (!authRequest?.sessionPublicKey) throw "Session key not set";
      return backend.getDelegations(
        idToken,
        authRequest.sessionPublicKey,
        31n * 24n * 60n * 60n * 1_000_000_000n,
      );
    })
    .then((authRes) => {
      console.log("getDelegation response:", authRes);
      if ("ok" in authRes) {
        // TODO: send response and close window
        console.log("authRes", authRes.ok);
        status.innerText = "Login completed";
        const msg = authRes.ok.auth;
        window.opener.postMessage(msg, "*");
      }
    })
    .catch((err) => {
      status.innerText = err.toString();
    });
}
