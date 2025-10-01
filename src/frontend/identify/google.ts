import { GoogleConfig } from "../auth-config";

declare global {
  interface Window {
    google: any;
  }
}

export async function initGsi(
  config: GoogleConfig,
  nonce: string,
  buttonId: string,
  showPrompt: boolean = true,
): Promise<string> {
  await loadGoogleSignInClient();

  return new Promise((resolve, _reject) => {
    window.google.accounts.id.initialize({
      ...config,
      callback: (token: { credential: string }) => resolve(token.credential),
      nonce: nonce,
    });

    const el = document.getElementById(buttonId)!;
    if (!el) console.trace("Google sign in button not found: #" + buttonId);

    window.google.accounts.id.renderButton(el, {
      theme: "outline",
      size: "large",
    });

    if (showPrompt) {
      window.google.accounts.id.prompt();
    }
  });
}

function loadGoogleSignInClient(): Promise<void> {
  return new Promise((resolve, reject) => {
    // Check if already loaded
    if (document.getElementById("google-signin-client")) {
      resolve();
      return;
    }

    const script = document.createElement("script");
    script.src = "https://accounts.google.com/gsi/client";
    script.id = "google-signin-client";
    script.async = true;
    script.defer = true;

    script.onload = () => {
      resolve();
    };

    script.onerror = () => {
      reject(new Error("Failed to load Google Sign-In client script"));
    };

    document.head.appendChild(script);
  });
}
