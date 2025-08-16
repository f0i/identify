export type PkceAuthData = { code: string; verifier: string; state?: string };

function dec2hex(dec: number) {
  const out = dec.toString(16);
  return out.length == 1 ? "0" + out : out;
}

function generateRandomString(length: number) {
  const array = new Uint32Array(length / 2);
  window.crypto.getRandomValues(array);
  return Array.from(array, dec2hex).join("");
}

export async function generateChallenge(
  sessionKey: Uint8Array,
): Promise<{ verifier: string; challenge: string }> {
  // add random string to the session key.
  // The total length of the verifier must not be more than 128 chars
  const verifier = await sha256Hex(sessionKey);

  console.log(
    "Using verifier:",
    verifier,
    "and code:",
    await generateCodeChallenge(verifier),
  );
  return {
    verifier,
    challenge: await generateCodeChallenge(verifier),
  };
}

async function generateCodeChallenge(code_verifier: string): Promise<string> {
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

async function sha256Hex(input: Uint8Array): Promise<string> {
  // Compute SHA-256 hash
  const hashBuffer = await crypto.subtle.digest("SHA-256", input);
  // Convert buffer to byte array
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  // Convert each byte to hex and join
  const hashHex = hashArray
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  return hashHex;
}

