/*
 * Replace window.open params in @auth0-spa-js to open the sign in window in a new tab instead of a popup window.
 * This makes it more consistent with other popups during the authentication flow.
 */

import fs from "fs";

const path =
  "node_modules/@auth0/auth0-spa-js/dist/auth0-spa-js.production.esm.js";

// Read the file
let source = fs.readFileSync(path, "utf8");

// Check if the patch is already applied
if (source.includes('"_blank"')) {
  console.log("✅ Patch already applied. Skipping.");
  process.exit(0);
}

// Regex to match the whole window.open(...) call
const regex = /window\.open\(e, [^)]*\)/g;

// Find all matches
const matches = [...source.matchAll(regex)];

if (matches.length === 0) throw "❌ window.open(...) not found!";
if (matches.length > 1) throw "❌ Found more than one window.open(...)!";

const match = matches[0];
const originalLength = match[0].length;

// Compute how many spaces to pad before closing )
const replacementCore = 'window.open(e,"_blank"';
const paddingSpaces = originalLength - replacementCore.length - 1; // -1 for ')'

if (paddingSpaces < 0) throw "❌ Replacement is longer than the original.";

// Build the padded replacement
const replacement = `${replacementCore}${" ".repeat(paddingSpaces)})`;

// Do the replacement
source = source.replace(regex, replacement);

// Write back the file
fs.writeFileSync(path, source);

console.log("✅ Patch applied successfully.");