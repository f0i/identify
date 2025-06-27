// candid.ts
// Import the decodeCandid function from candidDecoder.ts.
// Make sure candidDecoder.ts is in the same directory or accessible via this path.
import {
  createNameLookup,
  decodeCandid,
  DecodeResult,
} from "./identify/candidDecoder";
import { fieldNames } from "./identify/candidFieldNames";
import { JSONstringify } from "./identify/utils";

document.addEventListener("DOMContentLoaded", () => {
  // --- DOM Elements ---
  const unifiedInput = document.getElementById(
    "unifiedInput",
  ) as HTMLTextAreaElement;
  const hexOutput = document.getElementById("hexOutput") as HTMLTextAreaElement;
  const escapedStringOutput = document.getElementById(
    "escapedStringOutput",
  ) as HTMLTextAreaElement;
  const base64Output = document.getElementById(
    "base64Output",
  ) as HTMLTextAreaElement;
  const resultContainer = document.getElementById(
    "resultContainer",
  ) as HTMLDivElement;

  /**
   * Converts a string containing byte escape sequences (e.g., '\02', '\6b')
   * into a pure hexadecimal string.
   * @param inputString The string with escape sequences.
   * @returns The resulting hexadecimal string.
   */
  function convertEscapedStringToHex(inputString: string): string {
    let hexResult = "";
    const encoder = new TextEncoder(); // Used for accurate UTF-8 byte representation

    for (let i = 0; i < inputString.length; i++) {
      const char = inputString[i];
      if (char === "\\" && i + 2 < inputString.length) {
        // Check if it's a two-character hex escape sequence like \XX
        const hexChars = inputString.substring(i + 1, i + 3);
        // Ensure the next two characters are valid hex digits
        if (/^[0-9a-fA-F]{2}$/.test(hexChars)) {
          // This is a byte escape sequence, append the hex characters directly
          hexResult += hexChars.toUpperCase();
          i += 2; // Skip the two hex characters after '\'
        } else {
          // Not a valid hex escape sequence, treat '\' as a literal character
          // Convert '\' to its UTF-8 hex byte representation
          const encodedBytes = encoder.encode(char);
          for (const byte of encodedBytes) {
            hexResult += byte.toString(16).padStart(2, "0").toUpperCase();
          }
        }
      } else {
        // For all other characters (including non-escape sequences and valid '\' characters),
        // get their UTF-8 byte representation and convert to hex.
        const encodedBytes = encoder.encode(char);
        for (const byte of encodedBytes) {
          hexResult += byte.toString(16).padStart(2, "0").toUpperCase();
        }
      }
    }
    return hexResult;
  }

  /**
   * Converts a hex string to an escaped string.
   * @param hexString The hex string to convert.
   * @returns The escaped string.
   */
  function convertHexToEscapedString(hexString: string): string {
    let escapedString = "";
    for (let i = 0; i < hexString.length; i += 2) {
      const byte = parseInt(hexString.substring(i, i + 2), 16);
      if (byte >= 32 && byte <= 126 && byte !== 92) {
        // Printable ASCII character (excluding backslash)
        escapedString += String.fromCharCode(byte);
      } else {
        // Non-printable or backslash, convert to \xXX escape sequence
        escapedString += `\\${byte.toString(16).padStart(2, "0").toLowerCase()}`;
      }
    }
    return escapedString;
  }

  /**
   * Converts a hex string to a Base64 string.
   * @param hexString The hex string to convert.
   * @returns The Base64 string.
   */
  function convertHexToBase64(hexString: string): string {
    if (hexString.length === 0) return "";
    const bytes = new Uint8Array(hexString.length / 2);
    for (let i = 0; i < hexString.length; i += 2) {
      bytes[i / 2] = parseInt(hexString.substring(i, i + 2), 16);
    }
    return btoa(String.fromCharCode(...bytes));
  }

  /**
   * Converts a Base64 string to a hex string.
   * @param base64String The Base64 string to convert.
   * @returns The hex string.
   */
  function convertBase64ToHex(base64String: string): string {
    if (base64String.length === 0) return "";
    try {
      const binaryString = atob(base64String);
      let hexResult = "";
      for (let i = 0; i < binaryString.length; i++) {
        const byte = binaryString.charCodeAt(i);
        hexResult += byte.toString(16).padStart(2, "0").toUpperCase();
      }
      return hexResult;
    } catch (e) {
      console.error("Invalid Base64 string:", e);
      return ""; // Return empty string or handle error appropriately
    }
  }

  /**
   * Detects the input type (Hex, Escaped String, or Base64) and converts it to hex.
   * @param input The raw user input.
   * @returns The converted hex string, or null if the format is unrecognized.
   */
  function determineAndConvertToHex(input: string): string | null {
    const trimmedInput = input.trim();
    if (trimmedInput.length === 0) return null;

    // 1. Check for Hex String (even length, only hex characters)
    if (/^[0-9a-fA-F]+$/.test(trimmedInput) && trimmedInput.length % 2 === 0) {
      // Potentially a hex string. Check if it decodes cleanly from base64 first as a heuristic
      // This is to differentiate hex from base64 that might *look* like hex
      try {
        const base64Decoded = atob(trimmedInput);
        if (base64Decoded.length > 0 && trimmedInput.length % 4 === 0) {
          // If it successfully decodes from base64 and is a valid base64 length,
          // it's more likely base64.
          // This is a heuristic, not foolproof.
          // For now, prioritize hex detection if it strictly looks like hex.
          // A more robust solution might involve trying both and seeing which one yields a valid Candid decode.
        }
      } catch (e) {
        // Not valid base64, so it's more likely hex
      }
      return trimmedInput.toUpperCase(); // Assume it's hex if it passes the regex
    }

    // 2. Check for Escaped String (starts with "DIDL" or contains backslashes)
    if (trimmedInput.startsWith("DIDL") || trimmedInput.includes("\\")) {
      return convertEscapedStringToHex(trimmedInput);
    }

    // 3. Check for Base64 String (try decoding)
    // Base64 strings usually have a length divisible by 4, and use A-Z, a-z, 0-9, +, /, =
    if (
      /^[A-Za-z0-9+/=]+$/.test(trimmedInput) &&
      trimmedInput.length % 4 === 0
    ) {
      try {
        const hex = convertBase64ToHex(trimmedInput);
        // A simple check: if converting to hex results in a non-empty string, it's likely valid Base64
        if (hex.length > 0) {
          return hex;
        }
      } catch (e) {
        // Not a valid Base64 string
      }
    }

    // If none of the above, it's an unrecognized format or incomplete input.
    return null;
  }

  /**
   * Performs the Candid decoding given a hex string and displays the result.
   * Also updates the hex, escaped string, and Base64 output fields.
   * @param hexString The hex string to decode.
   */
  function processInput(input: string) {
    let decodedResult: DecodeResult | null = null;
    let hexToDecode: string | null = null;
    let conversionError: string | null = null;

    // Clear previous results container content
    resultContainer.innerHTML = "";

    if (input.trim().length === 0) {
      displayEmptyInputMessage(); // Show specific message for empty input
      return;
    }

    // Attempt to convert the input to hex
    try {
      hexToDecode = determineAndConvertToHex(input);
      if (hexToDecode === null) {
        conversionError =
          "Unrecognized input format. Please enter valid Hex, Escaped String, or Base64.";
      } else if (hexToDecode.length % 2 !== 0) {
        conversionError =
          "Hex string has an odd number of characters. Each byte requires two hex characters.";
      } else if (!/^[0-9a-fA-F]*$/.test(hexToDecode)) {
        conversionError = "Invalid hex characters detected after conversion.";
      }
    } catch (e: any) {
      conversionError = `Error during input conversion: ${e.message || e}`;
    }

    if (conversionError) {
      displayError(conversionError);
      return;
    }

    // Populate conversion outputs if we have valid hexToDecode
    if (hexToDecode) {
      hexOutput.value = hexToDecode;
      escapedStringOutput.value = convertHexToEscapedString(hexToDecode);
      base64Output.value = convertHexToBase64(hexToDecode);
    } else {
      // This case should ideally be caught by conversionError, but as a fallback
      displayError(
        "Could not convert input to a valid hex format for decoding.",
      );
      return;
    }

    try {
      const bytes = new Uint8Array(hexToDecode.length / 2);
      for (let i = 0; i < hexToDecode.length; i += 2) {
        const byteValue = parseInt(hexToDecode.substring(i, i + 2), 16);
        if (isNaN(byteValue)) {
          decodedResult = {
            error: {
              msg: `Invalid hex character sequence at position ${i}. Please use only 0-9, a-f, A-F.`,
              index: i / 2,
            },
          };
          displayResult(decodedResult);
          return;
        }
        bytes[i / 2] = byteValue;
      }

      decodedResult = decodeCandid(bytes, fieldNames);
      displayResult(decodedResult);
    } catch (e: any) {
      const error =
        e instanceof Error
          ? e.message
          : "An unknown error occurred in the UI logic.";
      decodedResult = {
        error: {
          msg: `An unexpected JavaScript error occurred in the UI: ${error}`,
          index: 0,
        },
      };
      displayResult(decodedResult);
    }
  }

  /**
   * Displays an error message in the result container.
   * @param message The error message to display.
   */
  function displayError(message: string) {
    resultContainer.innerHTML = ""; // Clear previous results
    const errorDiv = document.createElement("div");
    errorDiv.className =
      "bg-red-100 border border-red-400 text-red-700 px-6 py-4 rounded-lg relative shadow-inner";
    errorDiv.innerHTML = `
          <strong class="font-bold">Error!</strong>
          <span class="block sm:inline ml-2">${message}</span>
      `;
    resultContainer.appendChild(errorDiv);
  }

  /**
   * Displays a message when the input field is empty.
   */
  function displayEmptyInputMessage() {
    resultContainer.innerHTML = ""; // Clear previous results
    const messageDiv = document.createElement("div");
    messageDiv.className =
      "bg-blue-100 border border-blue-400 text-blue-700 px-6 py-4 rounded-lg relative shadow-inner";
    messageDiv.innerHTML = `
          <p class="text-center">Enter data (Hex, Escaped String, or Base64) to see the decoding result and conversions.</p>
      `;
    resultContainer.appendChild(messageDiv);
  }

  /**
   * Renders the decoding result (decoded data or error) into the DOM.
   * @param {DecodeResult} result - The result object from decodeCandid.
   */
  function displayResult(result: DecodeResult) {
    resultContainer.innerHTML = ""; // Clear previous results

    if ("error" in result) {
      const errorDiv = document.createElement("div");
      errorDiv.className =
        "bg-red-100 border border-red-400 text-red-700 px-6 py-4 rounded-lg relative shadow-inner";
      errorDiv.innerHTML = `
                <strong class="font-bold">Error!</strong>
                <span class="block sm:inline ml-2">${result.error.msg}</span>
                ${result.error.index !== null ? `<p class="mt-3 text-sm">Error occurred at byte index: <code class="font-mono bg-red-200 px-2 py-1 rounded-md text-red-800">${result.error.index}</code></p>` : ""}
            `;
      if (result.error.data !== undefined) {
        const partialDataP = document.createElement("p");
        partialDataP.className = "mt-4 font-semibold text-red-800";
        partialDataP.textContent = "Partial Decoded Data (if any):";
        errorDiv.appendChild(partialDataP);

        const pre = document.createElement("pre");
        pre.className =
          "bg-red-50 p-4 rounded-lg mt-2 text-sm overflow-auto max-h-60 border border-red-200";
        pre.textContent = JSONstringify(result.error.data, 2);
        errorDiv.appendChild(pre);
      }
      resultContainer.appendChild(errorDiv);
    } else if ("ok" in result) {
      // Only display success if data is not null
      const successDiv = document.createElement("div");
      successDiv.className =
        "bg-green-100 border border-green-400 text-green-700 px-6 py-4 rounded-lg relative shadow-inner";
      successDiv.innerHTML = `
                <strong class="font-bold">Success!</strong>
                <span class="block sm:inline ml-2">Candid data successfully decoded.</span>
                <p class="mt-4 font-semibold text-green-800">Decoded JSON:</p>
            `;
      const pre = document.createElement("pre");
      pre.className =
        "bg-green-50 p-4 rounded-lg mt-2 text-sm overflow-auto max-h-96 border border-green-200";
      pre.textContent = JSONstringify(result.ok, 2);
      successDiv.appendChild(pre);
      resultContainer.appendChild(successDiv);
    }
  }

  // --- Event Listener for Unified Input ---
  unifiedInput.addEventListener("input", () => {
    processInput(unifiedInput.value);
  });

  // Initial processing if there's any pre-filled value
  if (unifiedInput.value) {
    processInput(unifiedInput.value);
  } else {
    // If initially empty, display the empty input message
    displayEmptyInputMessage();
  }
});
