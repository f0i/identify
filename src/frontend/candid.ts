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
  // --- DOM Elements for Combined Functionality ---
  const stringInput = document.getElementById(
    "stringInput",
  ) as HTMLTextAreaElement;
  const combinedHexInput = document.getElementById(
    "combinedHexInput",
  ) as HTMLTextAreaElement;
  const resultContainer = document.getElementById(
    "resultContainer",
  ) as HTMLDivElement;
  const copyButton = document.getElementById("copyButton") as HTMLButtonElement;
  const copyStatus = document.getElementById(
    "copyStatus",
  ) as HTMLParagraphElement;

  /**
   * Converts a string containing byte escape sequences (e.g., '\02', '\6b')
   * into a pure hexadecimal string.
   * @param inputString The string with escape sequences.
   * @returns The resulting hexadecimal string.
   */
  function convertStringToHex(inputString: string): string {
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
   * Performs the Candid decoding given a hex string and displays the result.
   * @param hexString The hex string to decode.
   */
  function performCandidDecode(hexString: string) {
    let decodedResult: DecodeResult | null = null;
    try {
      const cleanHex = hexString.replace(/\s/g, "");

      if (cleanHex.length === 0) {
        // Clear results if input is empty
        resultContainer.innerHTML = "";
        return;
      }

      if (cleanHex.length % 2 !== 0) {
        decodedResult = {
          error: {
            msg: "Hex string has an odd number of characters. Each byte requires two hex characters.",
            index: Math.floor(cleanHex.length / 2),
          },
        };
        displayResult(decodedResult);
        return;
      }

      const bytes = new Uint8Array(cleanHex.length / 2);
      for (let i = 0; i < cleanHex.length; i += 2) {
        const byteValue = parseInt(cleanHex.substring(i, i + 2), 16);
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
   * Renders the decoding result (decoded data or error) into the DOM.
   * @param {DecodeResult} result - The result object from decodeCandid.
   */
  function displayResult(result: DecodeResult) {
    resultContainer.innerHTML = ""; // Clear previous results

    // Only display "Decoding Result" header if there's an actual result (not just empty input)
    if ("ok" in result || "error" in result) {
      const h2 = document.createElement("h2");
      h2.className = "text-2xl font-bold text-gray-800 mb-4";
      h2.textContent = "Decoding Result:";
      resultContainer.appendChild(h2);
    }

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

  // --- Event Listener for String Input (Automatic Hex Conversion) ---
  stringInput.addEventListener("input", () => {
    const inputString = stringInput.value;
    const hex = convertStringToHex(inputString);
    combinedHexInput.value = hex;
    // Trigger Candid decoding automatically when string input changes
    performCandidDecode(hex);
    copyStatus.textContent = ""; // Clear previous copy status
  });

  // --- Event Listener for Combined Hex Input (Automatic Candid Decoding) ---
  combinedHexInput.addEventListener("input", () => {
    const hexString = combinedHexInput.value;
    performCandidDecode(hexString);
    copyStatus.textContent = ""; // Clear previous copy status
  });

  // --- Event Listener for Copy to Clipboard ---
  copyButton.addEventListener("click", () => {
    combinedHexInput.select();
    combinedHexInput.setSelectionRange(0, 99999); // For mobile devices

    try {
      const success = document.execCommand("copy");
      if (success) {
        copyStatus.textContent = "Copied to clipboard!";
      } else {
        copyStatus.textContent = "Failed to copy.";
      }
    } catch (err) {
      console.error("Failed to copy text:", err);
      copyStatus.textContent = "Failed to copy (browser issue).";
    }

    setTimeout(() => {
      copyStatus.textContent = "";
    }, 3000);
  });

  // Initial decode if there's any pre-filled value
  if (combinedHexInput.value) {
    performCandidDecode(combinedHexInput.value);
  }
});
