import { Principal } from "@dfinity/principal";

declare global {
  interface Window {
    google: any;
  }
}

export async function initGsi(
  clientId: string,
  nonce: string,
): Promise<{ credential: string }> {
  return new Promise((resolve, _reject) => {
    window.google.accounts.id.initialize({
      client_id: clientId,
      callback: resolve,
      nonce: nonce,
    });

    window.google.accounts.id.renderButton(
      document.getElementById("icgsi-google-btn")!,
      { theme: "outline", size: "large" },
    );

    window.google.accounts.id.prompt();
  });
}
