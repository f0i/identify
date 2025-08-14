export type PkceAuthData = { code: string; state?: string };

function dec2hex(dec: number) {
  return ("0" + dec.toString(16)).substr(-2);
}

function generateRandomString(length: number) {
  const array = new Uint32Array(length / 2);
  window.crypto.getRandomValues(array);
  return Array.from(array, dec2hex).join("");
}

export async function generateCodeChallenge(
  code_verifier: string,
): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(code_verifier);
  const hashBuffer = await window.crypto.subtle.digest("SHA-256", data);
  return base64urlencode(hashBuffer);
}

function base64urlencode(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer);
  let str = "";
  for (let i = 0; i < bytes.length; i++) {
    str += String.fromCharCode(bytes[i]);
  }
  return btoa(str).replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
}

