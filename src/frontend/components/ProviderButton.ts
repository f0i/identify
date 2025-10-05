import { getProviderStyles } from "../provider-styles";
import template from "./ProviderButton.html";

export interface Provider {
  name: string;
  key: string;
}

interface ProviderButtonProps {
  provider: Provider;
  onClick: () => void;
}

export function createProviderButton({ provider, onClick }: ProviderButtonProps): HTMLButtonElement {
  const templateElement = document.createElement('template');
  templateElement.innerHTML = template;
  const button = templateElement.content.firstChild as HTMLButtonElement;

  const styles = getProviderStyles(provider.key);
  Object.assign(button.style, styles);

  const icon = button.querySelector(".provider-icon") as HTMLImageElement;
  icon.src = `img/icons/${provider.key}.${provider.key === "zitadel" ? "png" : "svg"}`;

  const text = button.querySelector(".provider-name") as HTMLSpanElement;
  text.innerText = `Sign in with ${provider.name}`;

  button.addEventListener("click", onClick);

  return button;
}
