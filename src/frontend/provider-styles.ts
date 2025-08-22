// provider-styles.ts

import { ProviderKey } from "./identify/delegation";

export const getProviderStyles = (provider: ProviderKey) => {
  switch (provider) {
    case "google":
      return {
        backgroundColor: "#f2f2f2",
        color: "#000000",
      };
    case "auth0":
      return {
        backgroundColor: "#eb5424",
        color: "white",
      };
    case "zitadel":
      return {
        backgroundColor: "#528265",
        color: "white",
      };
    case "github":
      return {
        backgroundColor: "#333",
        color: "white",
      };
    case "x":
      return {
        backgroundColor: "#000000",
        color: "white",
      };
    default:
      return {
        // Default styles
        backgroundColor: "#4CAF50",
        color: "white",
      };
  }
};
