import { getProviderStyles } from "./provider-styles";
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
import { Principal } from "@dfinity/candid/lib/cjs/idl";

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

  ALL_PROVIDERS.forEach((provider) => {
    const button = document.createElement("button");
    const styles = getProviderStyles(provider.id);
    Object.assign(button.style, styles);

    const content = document.createElement("div");
    content.style.display = "flex";
    content.style.alignItems = "center";

    const icon = document.createElement("img");
    icon.src = `img/icons/${provider.id}.${provider.id === "zitadel" ? "png" : "svg"}`;
    icon.style.width = "24px";
    icon.style.height = "24px";
    icon.style.marginRight = "10px";
    content.appendChild(icon);

    const text = document.createElement("span");
    text.innerText = `Sign in with ${provider.name}`;
    content.appendChild(text);

    button.appendChild(content);

    button.addEventListener("click", () =>
      initAuth(IDENTITY_PROVIDER + "?provider=" + provider.id),
    );
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
  // Show spinner, hide everything else
  showElement("spinner", true);
  showElement("user-card", false);
  showElement("provider-buttons", false);
  showElement("demo-logout", false);

  const authClient = await AuthClient.create();
  if (await authClient.isAuthenticated()) {
    console.log("Already authenticated!", authClient.getIdentity());
    innerText("login-status", "Authenticated...");
    const isDev = process.env.DFX_NETWORK !== "ic";
    const host = isDev ? "http://localhost:4943" : "https://icp-api.io";

    const backend = createActor(canisterId, {
      agentOptions: { host, identity: authClient.getIdentity() },
    });
    const principal = await backend
      .getPrincipal()
      .catch((e: any): undefined => undefined);
    const userInfo = principal
      ? await backend
          .getUser(principal, origin)
          .catch((e: any): undefined => undefined)
      : [];

    // Populate user card
    const userCard = document.getElementById("user-card");
    const userIcon = document.getElementById("user-icon") as HTMLImageElement;
    const userName = document.getElementById("user-name");
    const userEmail = document.getElementById("user-email");
    const userId = document.getElementById("user-id"); // Get user ID element
    const userPrincipal = document.getElementById("user-principal");

    if (
      userIcon &&
      userInfo &&
      userInfo.length > 0 &&
      userInfo[0].avatar_url &&
      userInfo[0].avatar_url.length > 0
    ) {
      userIcon.src = userInfo[0].avatar_url[0] ?? "";
      showElement("user-icon", true);
    } else if (userIcon) {
      showElement("user-icon", false); // Hide if no valid picture
    }

    if (
      userName &&
      userInfo &&
      userInfo.length > 0 &&
      userInfo[0].name &&
      userInfo[0].name.length > 0
    ) {
      userName.innerText = userInfo[0].name[0] ?? "";
      showElement("user-name", true);
    } else if (userName) {
      showElement("user-name", false); // Hide if no name
    }

    if (
      userEmail &&
      userInfo &&
      userInfo.length > 0 &&
      userInfo[0].email &&
      userInfo[0].email.length > 0
    ) {
      userEmail.innerText = userInfo[0].email[0] ?? "";
      showElement("user-email", true);
    } else if (userEmail) {
      showElement("user-email", false); // Hide if no email
    }

    if (userId && userInfo && userInfo.length > 0 && userInfo[0].id) {
      userId.innerText = `User ID: ${userInfo[0].id}`;
      showElement("user-id", true);
    } else if (userId) {
      showElement("user-id", false); // Hide if no ID
    }

    if (userPrincipal) {
      userPrincipal.innerText = `Principal: ${principal}`;
      showElement("user-principal", true);
    } else if (userPrincipal) {
      showElement("user-principal", false); // Hide if no principal
    }

    // Populate additional user info
    const additionalUserInfoDiv = document.getElementById(
      "additional-user-info",
    );
    if (additionalUserInfoDiv && userInfo && userInfo.length > 0) {
      additionalUserInfoDiv.innerHTML = ""; // Clear previous content

      const excludedKeys = [
        "id",
        "avatar_url",
        "name",
        "email",
        "createdAt",
        "origin",
        "principal", // Exclude principal as it's handled separately
      ];

      for (const key in userInfo[0]) {
        if (userInfo[0].hasOwnProperty(key) && !excludedKeys.includes(key)) {
          let value = (userInfo as any)[0][key];
          let displayValue = "";
          let shouldDisplay = true;

          if (Array.isArray(value)) {
            if (value.length > 0) {
              displayValue = value[0];
            } else {
              shouldDisplay = false; // Hide if array is empty
            }
          } else if (typeof value === "object" && value !== null) {
            // Handle provider object specifically
            if (key === "provider") {
              const providerName = Object.keys(value)[0];
              if (providerName) {
                displayValue = providerName;
              } else {
                shouldDisplay = false;
              }
            } else {
              displayValue = JSON.stringify(value);
            }
          } else {
            displayValue = value;
          }

          if (
            shouldDisplay &&
            displayValue !== "N/A" &&
            displayValue !== "" &&
            displayValue !== "null" &&
            displayValue !== "undefined"
          ) {
            const p = document.createElement("p");
            p.style.margin = "5px 0";
            p.style.fontSize = "0.85em";
            p.style.color = "#777";

            let displayKey = key.replace(/_/g, " ");
            // Capitalize first letter of each word
            displayKey = displayKey
              .split(" ")
              .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
              .join(" ");

            if (displayKey === "Provider Created At") {
              displayKey = "Created At";
            }

            p.innerHTML = `<strong>${displayKey}:</strong> ${displayValue}`;
            additionalUserInfoDiv.appendChild(p);
          }
        }
      }
    }

    showElement("user-card", true); // Show user card

    // Revert login-status to original message or clear it
    innerText("login-status", "Authenticated..."); // Or clear it: innerText("login-status", "");

    updateListById(
      "log",
      await backend.getStats().catch((e: any): string[] => ["Error: " + e]),
    );

    showElement("provider-buttons", false); // Hide provider buttons
    showElement("demo-logout", true);
  } else {
    // Hide user card when not authenticated
    showElement("user-card", false);
    innerText("demo-status", "Status: not authenticated");
    showElement("provider-buttons", true); // Show provider buttons
    showElement("demo-logout", false);
  }
  // Hide spinner
  showElement("spinner", false);
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
