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

async function initAuth() {
  const authClient = await AuthClient.create();

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
        // Handle successful authentication (e.g., redirect to your app)
      },
      onError: (error) => {
        console.error("Authentication failed", error);
        // Handle authentication failure
      },
    });
  }
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
  }
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

  // Send the token to the server for verification
  if (false) {
    fetch("/api/verify-token", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ token: idToken }),
    })
      .then((res) => res.json())
      .then((data) => {
        console.log("Server response:", data);
        if (data.success) {
          console.log("Login successful!");
        } else {
          console.log("Login failed!");
        }
      })
      .catch((error) => {
        console.error("Error:", error);
      });
  }
}
