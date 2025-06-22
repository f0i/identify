import { initDemo } from "./demo";
import { initICgsi } from "./icgsi";
import { showElement } from "./identify/dom";

const GSI_CLIENT_ID =
  "376650571127-vpotkr4kt7d76o8mki09f7a2vopatdp6.apps.googleusercontent.com";

const IDENTITY_PROVIDER = "https://login.f0i.de";

window.onload = () => {
  console.log("onload: opener:", window.opener);
  if (window.opener) {
    initICgsi(GSI_CLIENT_ID);
  } else {
    initDemo(IDENTITY_PROVIDER);
  }
  document.getElementById("version")!.innerText = process.env.BUILD_TIME!;
  try {
    (window as any).showInfo(document.location.hash.substring(1));
  } catch (e) {
    // ignore
  }
};

(window as any).showInfo = function (sectionId: string) {
  const active = document.getElementById(sectionId)!.style.display === "block";
  // Hide all sections
  showElement("help", false);
  showElement("security", false);
  showElement("about", false);
  // Show the selected section
  showElement("info", true);
  showElement(sectionId, !active);
  // remove the hash from the URL if element was active
  if (active) {
    setTimeout(() =>
      history.replaceState(null, "", document.location.pathname),
    );
  }
};

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
