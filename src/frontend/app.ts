// This is the entrypoint of the application.
// Depending on the way the page is opened,
// it will either show the login form
// or a minimal demo application to try out the login provider.

import {
  AUTH0,
  GITHUB,
  GSI,
  IDENTITY_PROVIDER,
  X,
  ZITADEL,
} from "./auth-config";
import { initDemo } from "./demo";
import { initIdentify } from "./identify";
import { showElement } from "./identify/dom";

window.onload = () => {
  const params = new URLSearchParams(document.location.search);
  let provider = params.get("provider") || "google";

  console.log("onload: opener:", window.opener);
  if (window.opener) {
    switch (provider) {
      case "google":
        initIdentify(provider, GSI);
        break;
      case "auth0":
        initIdentify(provider, AUTH0);
        break;
      case "zitadel":
        initIdentify(provider, ZITADEL);
        break;
      case "x":
        initIdentify(provider, X);
        break;
      case "github":
        initIdentify(provider, GITHUB);
        break;
      default:
        console.error(
          "Invalid provider " + provider + ". Falling back to google.",
        );
        initIdentify("google", GSI);
        break;
    }
  } else {
    initDemo(IDENTITY_PROVIDER + "?provider=" + provider);
  }

  document.getElementById("version")!.innerText = process.env.BUILD_TIME!;
  try {
    showInfo(document.location.hash.substring(1));
  } catch (e) {
    // ignore
  }
};

(window as any).showInfo = (sectionId: string) => {
  const active = !document.getElementById(sectionId)?.classList.contains("hidden");
  // Hide all sections
  showElement("help", false);
  showElement("security", false);
  showElement("about", false);
  // Show the selected section
  showElement("info", !active);
  showElement(sectionId, !active);
  // remove the hash from the URL if element was active
  if (active) {
    setTimeout(() =>
      history.replaceState(null, "", document.location.pathname + document.location.search),
    );
  }
}

/*
(function pipeAllConsoleToOpener() {
  if (!window.opener) return;

  const methods = ["log", "info", "warn", "error", "debug"] as const;

  for (const method of methods) {
    const original = console[method];
    console[method] = (...args: unknown[]) => {
      try {
        window.opener?.postMessage({ type: `popup-${method}`, args }, "*");
      } catch (err) {
        original("Failed to postMessage to opener:", err);
      }
      original.apply(console, args);
    };
  }
})();
*/
