// This is the entrypoint of the application.
// Depending on the way the page is opened,
// it will either show the login form
// or a minimal demo application to try out the login provider.

import { initDemo } from "./demo";
import { initIdentify } from "./identify";
import { showElement } from "./identify/dom";

import { createInfoFooter } from "./components/InfoFooter";

window.onload = () => {
  const params = new URLSearchParams(document.location.search);
  let providerKey = params.get("provider") || "google";

  console.log("onload: opener:", window.opener);
  if (window.opener) {
    initIdentify(providerKey);
  } else {
    initDemo();
  }

  const infoFooterContainer = document.getElementById("info-footer-container");
  if (infoFooterContainer) {
    const infoFooter = createInfoFooter();
    infoFooterContainer.appendChild(infoFooter);
  }



};

/*
// Debug helper to send all console messages to the opener
// ONLY FOR DEBUGGING! This might leak information!
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
