import { AuthClient } from "@dfinity/auth-client";
import { canisterId, createActor } from "../declarations/backend";
import { showElement } from "./identify/dom";
import { IDENTITY_PROVIDER } from "./auth-config"; // Added
import { unwrapOpt } from "./identify/utils";
import { populateProviderButtons } from "./components/ProviderButtons";
import { createUserCard } from "./components/UserCard";

const ALL_PROVIDERS = [
  { name: "Google", key: "google" },
  { name: "Auth0", key: "auth0" },
  { name: "Zitadel", key: "zitadel" },
  { name: "GitHub", key: "github" },
  { name: "X", key: "x" },
  { name: "LinkedIn", key: "linkedin" },
];

// Initialize the demo application
export function initDemo() {
  showElement("demo", true);
  const providerButtonsContainer = document.getElementById("provider-buttons")!;

  populateProviderButtons(providerButtonsContainer, {
    providers: ALL_PROVIDERS,
    onProviderClick: (providerKey) => {
      initAuth(IDENTITY_PROVIDER + "?provider=" + providerKey);
    },
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
  innerText("login-status", "Logged out");
}

// Check authentication status, get principal and load statistics
async function checkAuth() {
  // Show spinner, hide user card and actions
  showElement("spinner", true);
  showElement("user-card-container", false);
  showElement("demo-actions", false);

  const authClient = await AuthClient.create();
  if (await authClient.isAuthenticated()) {
    console.log("Already authenticated!", authClient.getIdentity());
    innerText("login-status", "Authenticated...");
    const isDev = process.env.DFX_NETWORK !== "ic";
    const host = isDev ? "http://localhost:4943" : "https://icp-api.io";

    const backend = createActor(canisterId, {
      agentOptions: { host, identity: authClient.getIdentity() },
    });
    const principal = await backend.getPrincipal().catch(() => undefined);
    const userInfo = principal
      ? unwrapOpt(await backend.getUser(principal, origin).catch(() => []))
      : undefined;
    console.log("userInfo", userInfo);

    const userCardContainer = document.getElementById("user-card-container");
    if (userCardContainer && userInfo) {
      userCardContainer.innerHTML = "";
      const userCard = createUserCard({
        user: { ...userInfo, principal: principal?.toString() },
      });
      userCardContainer.appendChild(userCard);
      showElement(userCard, true);
      showElement(userCardContainer, true);
    } else if (userCardContainer) {
      showElement(userCardContainer, false);
    }

    // Update status
    innerText("login-status", "Authenticated successfully!");

    // Show user card and actions
    showElement("user-card-container", true);
    showElement("demo-actions", true);
    showElement("demo-logout", true);
    showElement("provider-buttons", false); // Hide provider buttons

    // Update logs
    updateStats("log", await backend.getStats().catch((e: any): any => {}));

    // Show info and logs sections
    showElement("demo-info", true);
    showElement("demo-logs", true);
  } else {
    // Not authenticated
    showElement("user-card-container", false);
    showElement("demo-actions", true);
    showElement("provider-buttons", true); // Show provider buttons
    showElement("demo-logout", false);
    innerText("login-status", "Status: Not authenticated. Please sign in.");
    showElement("demo-info", false);
    showElement("demo-logs", false);
  }
  // Hide spinner
  showElement("spinner", false);
}

// Update stats list
function updateStats(
  ulId: string,
  stats: {
    appCount: number;
    keyCount: number;
    loginCount: number;
  },
): void {
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
  Object.entries(stats).forEach(([key, value]) => {
    const li = document.createElement("li");
    li.textContent = `${key}: ${value}`;
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
