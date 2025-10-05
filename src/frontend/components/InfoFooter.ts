import template from "./InfoFooter.html";
import { showElement } from "../identify/dom";

declare global {
  interface Window {
    showInfo: (sectionId: string) => void;
  }
}

export function createInfoFooter(): HTMLElement {
  const templateElement = document.createElement("template");
  templateElement.innerHTML = template;
  const infoFooter = templateElement.content.firstChild as HTMLElement;

  infoFooter.querySelector("#version")!.textContent = process.env.BUILD_TIME!;

  window.showInfo = (sectionId: string) => {
    const active = !document
      .getElementById(sectionId)
      ?.classList.contains("hidden");
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
        history.replaceState(
          null,
          "",
          document.location.pathname + document.location.search,
        ),
      );
    }
  };

  const links = infoFooter.querySelectorAll(".footer a");
  links.forEach((link) => {
    link.addEventListener("click", (event) => {
      event.preventDefault();
      const sectionId = (event.target as HTMLAnchorElement).hash.substring(1);
      window.showInfo(sectionId);
    });
  });

  return infoFooter;
}
