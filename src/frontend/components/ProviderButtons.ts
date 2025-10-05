import { createProviderButton, Provider } from "./ProviderButton";

interface ProviderButtonsProps {
  providers: Provider[];
  onProviderClick: (providerKey: string) => void;
}

export function populateProviderButtons(
  container: HTMLElement,
  { providers, onProviderClick }: ProviderButtonsProps
): void {
  container.innerHTML = ""; // Clear existing buttons
  providers.forEach((provider) => {
    const button = createProviderButton({
      provider,
      onClick: () => onProviderClick(provider.key),
    });
    container.appendChild(button);
  });
}