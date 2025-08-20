import { AuthClient } from "@dfinity/auth-client";
import { canisterId, createActor } from "../declarations/backend";
import { showElement } from "./identify/dom";
import {
  AUTH0,
  GITHUB,
  GSI,
  IDENTITY_PROVIDER,
  X,
  ZITADEL,
} from "./auth-config"; // Added

const ALL_PROVIDERS = [
  { name: "Google", id: "google", config: GSI },
  { name: "Auth0", id: "auth0", config: AUTH0 },
  { name: "Zitadel", id: "zitadel", config: ZITADEL },
  { name: "GitHub", id: "github", config: GITHUB },
  { name: "X", id: "x", config: X },
];

// Initialize the demo application
export function initDemo(identityProvider: string) {
  showElement("demo", true);
  const providerButtonsContainer = document.getElementById("provider-buttons")!; // Get container

  ALL_PROVIDERS.forEach(provider => {
    const button = document.createElement("button");
    button.innerText = `Sign in with ${provider.name}`;
    button.addEventListener("click", () => initAuth(IDENTITY_PROVIDER + "?provider=" + provider.id));
    providerButtonsContainer.appendChild(button);
  });

  const logout = document.getElementById("demo-logout")!;
  logout.addEventListener("click", resetAuth);

  innerText("demo-build-time", process.env.BUILD_TIME!);
  innerText("demo-network", process.env.DFX_NETWORK!);
  const isDev = process.env.DFX_NETWORK !== "ic";
  const host = isDev ? "http://localhost:4943" : "https://icp-api.io";
  innerText("demo-api", host);

  checkAuth();
}

// Log in
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
      identityProvider: identityProvider,
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

// Log out
async function resetAuth() {
  const authClient = await AuthClient.create();
  authClient.logout().finally(checkAuth);
  updateListById("log", []);
  innerText("login-status", "Logged out");
}

// Check authentication status, get principal and load statistics
async function checkAuth() {
  const authClient = await AuthClient.create();
  if (await authClient.isAuthenticated()) {
    console.log("Already authenticated!", authClient.getIdentity());
    innerText("login-status", "Authenticated...");
    const isDev = process.env.DFX_NETWORK !== "ic";
    const host = isDev ? "http://localhost:4943" : "https://icp-api.io";

    const backend = createActor(canisterId, {
      agentOptions: { host, identity: authClient.getIdentity() },
    });
    const msg = await backend.getPrincipal().catch((e: any): string => "" + e);

    innerText("login-status", msg);

    updateListById(
      "log",
      await backend.getStats().catch((e: any): string[] => ["Error: " + e]),
    );

    showElement("provider-buttons", false); // Hide provider buttons
    showElement("demo-logout", true);
  } else {
    innerText("demo-status", "Status: not authenticated");
    showElement("provider-buttons", true); // Show provider buttons
    showElement("demo-logout", false);
  }
}

// Set list items
function updateListById(ulId: string, items: string[]): void {
  const ul = document.getElementById(ulId);
  if (!ul) {
    console.error(`No <ul> element found with id: ${ulId}`);
    return;
  }
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
}

// Set text content of an element
function innerText(id: string, text: string) {
  const el = document.getElementById(id);
  if (el) {
    el.innerText = text;
  } else {
    console.log("Element not found", id, "to set innerText", text);
  }
}


