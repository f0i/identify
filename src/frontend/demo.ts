import { AuthClient } from "@dfinity/auth-client";
import { canisterId, createActor } from "../declarations/backend";

function updateListById(ulId: string, items: string[]): void {
  const ul = document.getElementById(ulId);

  if (ul) {
    // Remove all previous children
    while (ul.firstChild) {
      ul.removeChild(ul.firstChild);
    }

    // Add new list items
    items.forEach((item) => {
      const li = document.createElement("li");
      li.textContent = item;
      ul.appendChild(li);
    });
  } else {
    console.error(`No <ul> element found with id: ${ulId}`);
  }
}

export function initDemo(identityProvider: string) {
  const demo = document.getElementById("demo")!;
  demo.style.display = "block";
  const login = document.getElementById("demo-login")!;
  login.addEventListener("click", () => initAuth(identityProvider));
  const logout = document.getElementById("demo-logout")!;
  logout.addEventListener("click", resetAuth);

  checkAuth();
}

async function initAuth(identityProvider: string) {
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
    // If not authenticated, authenticate
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
    updateListById(
      "log",
      await backend.getStats().catch((e: any): string[] => ["Error: " + e]),
    );
    login.style.display = "none";
    logout.style.display = "inline-block";
  } else {
    status.innerText = "Status: not authenticated";
    login.style.display = "inline-block";
    logout.style.display = "none";
  }
}
