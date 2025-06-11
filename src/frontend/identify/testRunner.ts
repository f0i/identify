import { CandidDecoder } from "./candid_decoder"; // Import from the decoder logic file
import { testCases, TestCase } from "./candid_decoder.test"; // Import test cases

// This function is duplicated from App.tsx to ensure it's available in the Node.js context
// Function to convert string with byte escapes (e.g., \01, \x0a) and hex to Uint8Array
function parseInputToBytes(input: string): Uint8Array {
  let processedHex = input
    .replace(/\\x([0-9a-fA-F]{2})/g, (match, hex) => hex) // Handle \xHH
    .replace(/\\([0-9a-fA-F]{2})/g, (match, hex) => hex); // Handle \HH (e.g., \01, \6c)

  // Handle "DIDL" text magic number at the beginning
  if (processedHex.startsWith("DIDL") && !processedHex.startsWith("4449444c")) {
    processedHex = "4449444c" + processedHex.substring("DIDL".length); // Convert "DIDL" to hex
  }

  let hexString = "";
  for (let i = 0; i < processedHex.length; i++) {
    const char = processedHex[i];
    if (char.match(/[0-9a-fA-F]/)) {
      hexString += char;
    } else if (char.charCodeAt(0) >= 32 && char.charCodeAt(0) <= 126) {
      // For printable ASCII characters not part of a hex escape, convert to hex
      hexString += char.charCodeAt(0).toString(16).padStart(2, "0");
    }
    // Ignore other characters (e.g., whitespace, control characters, non-hex escapes)
  }

  // Ensure hexString is an even length for byte parsing
  if (hexString.length % 2 !== 0) {
    hexString = "0" + hexString; // Pad with a leading zero if odd
  }

  const bytes = new Uint8Array(
    hexString.match(/.{1,2}/g)!.map((byte) => parseInt(byte, 16)),
  );
  return bytes;
}

function runAllTests(): void {
  console.log("Running Candid Decoder Tests...");
  let passedCount = 0;
  let failedCount = 0;
  let warningCount = 0;

  testCases.forEach((test: TestCase, index: number) => {
    try {
      const bytesArray = parseInputToBytes(test.inputHex);
      const decoder = new CandidDecoder(bytesArray);
      const actualOutput = decoder.decode();
      const actualOutputString = JSON.stringify(actualOutput, (key, value) =>
        typeof value === "bigint" ? value.toString() + "n" : value,
      );

      if (test.expectedOutput !== undefined) {
        const expectedOutputString = JSON.stringify(
          test.expectedOutput,
          (key, value) =>
            typeof value === "bigint" ? value.toString() + "n" : value,
        );
        if (actualOutputString === expectedOutputString) {
          console.log(`✅ PASS: ${test.name}`);
          passedCount++;
        } else {
          console.error(`❌ FAIL: ${test.name}`);
          console.error(`   Expected: ${expectedOutputString}`);
          console.error(`   Got:      ${actualOutputString}`);
          failedCount++;
        }
      } else if (test.expectedError) {
        console.error(
          `❌ FAIL: ${test.name} - Expected error, but decoding succeeded.`,
        );
        console.error(`   Output: ${actualOutputString}`);
        failedCount++;
      } else {
        console.warn(
          `⚠️ WARNING: ${test.name} - No expected output or error defined.`,
        );
        warningCount++;
      }
    } catch (e: any) {
      if (test.expectedError) {
        if (e.message.includes(test.expectedError)) {
          console.log(`✅ PASS (Error): ${test.name} - ${e.message}`);
          passedCount++;
        } else {
          console.error(`❌ FAIL (Error Mismatch): ${test.name}`);
          console.error(`   Expected error: "${test.expectedError}"`);
          console.error(`   Got error:      "${e.message}"`);
          failedCount++;
        }
      } else {
        console.error(`❌ FAIL: ${test.name} - Unexpected error: ${e.message}`);
        failedCount++;
      }
    }
  });

  console.log("\n--- Test Summary ---");
  console.log(`Total: ${testCases.length}`);
  console.log(`Passed: ${passedCount}`);
  console.log(`Failed: ${failedCount}`);
  console.log(`Warnings: ${warningCount}`);

  if (failedCount > 0) {
    process.exit(1); // Exit with a non-zero code if tests failed
  }
}

// Run the tests when the script is executed
runAllTests();
