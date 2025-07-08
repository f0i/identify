/// This test is copied from https://github.com/edjcase/motoko_base_x
/// Additional checks have been added to compare with our custom Base64 decoder implementation
import { test } "mo:test";
import Debug "mo:base/Debug";
import Runtime "mo:new-base/Runtime";
import Blob "mo:new-base/Blob";
import BaseX "mo:base-x-encoder";
import Base64 "../src/backend/Base64";

test(
  "to/fromBase64",
  func() {
    let testCases : [{
      input : Blob;
      outputFormat : BaseX.Base64OutputFormat;
      expected : Text;
    }] = [
      {
        input = "\48\49\50\51\52\53\54\55\56\57";
        outputFormat = #standard({ includePadding = true });
        expected = "SElQUVJTVFVWVw==";
      },
      {
        input = "\48\49\50\51\52\53\54\55\56\57";
        outputFormat = #url({ includePadding = false });
        expected = "SElQUVJTVFVWVw";
      },
      {
        input = "\48\49\50\51\52\53\54\55";
        outputFormat = #standard({ includePadding = true });
        expected = "SElQUVJTVFU=";
      },
      {
        input = "\48\49\50\51\52\53\54\55";
        outputFormat = #url({ includePadding = false });
        expected = "SElQUVJTVFU";
      },
      {
        input = "\FC\03\3F";
        outputFormat = #standard({ includePadding = true });
        expected = "/AM/";
      },
      {
        input = "\FC\03\3F";
        outputFormat = #url({ includePadding = false });
        expected = "_AM_";
      },
      {
        input = "\01";
        outputFormat = #standard({ includePadding = true });
        expected = "AQ==";
      },
      {
        input = "\01";
        outputFormat = #url({ includePadding = false });
        expected = "AQ";
      },
      {
        input = "\01\02";
        outputFormat = #standard({ includePadding = true });
        expected = "AQI=";
      },
      {
        input = "\01\02";
        outputFormat = #url({ includePadding = false });
        expected = "AQI";
      },
      {
        input = "\FB\FF\FF";
        outputFormat = #standard({ includePadding = true });
        expected = "+///";
      },
      {
        input = "\FB\FF\FF";
        outputFormat = #url({ includePadding = false });
        expected = "-___";
      },
      {
        input = "\AA\55\FF";
        outputFormat = #standard({ includePadding = true });
        expected = "qlX/";
      },
      {
        input = "\AA\55\FF";
        outputFormat = #url({ includePadding = false });
        expected = "qlX_";
      },
      {
        // Empty string
        input = "";
        outputFormat = #standard({ includePadding = true });
        expected = "";
      },
      {
        // Single character (requires double padding)
        input = "A";
        outputFormat = #standard({ includePadding = true });
        expected = "QQ==";
      },
      {
        // Single character URI-safe (no padding)
        input = "A";
        outputFormat = #url({ includePadding = false });
        expected = "QQ";
      },
      {
        // Two characters (requires single padding)
        input = "BC";
        outputFormat = #standard({ includePadding = true });
        expected = "QkM=";
      },
      {
        // Two characters URI-safe (no padding)
        input = "BC";
        outputFormat = #url({ includePadding = false });
        expected = "QkM";
      },
      {
        // Three characters (no padding required)
        input = "DEF";
        outputFormat = #standard({ includePadding = true });
        expected = "REVG";
      },
      {
        // Special characters
        input = "!@#$%";
        outputFormat = #standard({ includePadding = true });
        expected = "IUAjJCU=";
      },
      {
        // Binary data with zeros
        input = "\00\01\02\03";
        outputFormat = #standard({ includePadding = true });
        expected = "AAECAw==";
      },
      {
        // UTF-8 characters (corrected)
        input = "→★♠";
        outputFormat = #standard({ includePadding = true });
        expected = "4oaS4piF4pmg";
      },
      {
        // Longer text string
        input = "Base64 encoding test 123!";
        outputFormat = #url({ includePadding = false });
        expected = "QmFzZTY0IGVuY29kaW5nIHRlc3QgMTIzIQ";
      },

      {
        // Mixed case alphanumeric with punctuation
        input = "Hello, World! 123";
        outputFormat = #standard({ includePadding = true });
        expected = "SGVsbG8sIFdvcmxkISAxMjM=";
      },
      {
        // Special characters that require URI-safe encoding
        input = "~!@#$%^&*()_+{}|:<>?";
        outputFormat = #url({ includePadding = false });
        expected = "fiFAIyQlXiYqKClfK3t9fDo8Pj8";
      },
      {
        // Multi-byte UTF-8 characters
        input = "日本語";
        outputFormat = #standard({ includePadding = true });
        expected = "5pel5pys6Kqe";
      },
      {
        // Mix of ASCII and UTF-8
        input = "ABC中文DEF";
        outputFormat = #url({ includePadding = false });
        expected = "QUJD5Lit5paHREVG";
      },
      {
        // Binary data with pattern
        input = "\01\02\03\04\05\06\07\08";
        outputFormat = #standard({ includePadding = true });
        expected = "AQIDBAUGBwg=";
      },
      {
        // String length that produces 1 padding character
        input = "12345";
        outputFormat = #standard({ includePadding = true });
        expected = "MTIzNDU=";
      },
      {
        // Repeating characters
        input = "AAAABBBBCCCC";
        outputFormat = #url({ includePadding = false });
        expected = "QUFBQUJCQkJDQ0ND";
      },
      {
        // Includes null bytes and other control characters
        input = "\00\01\10\11\20\21";
        outputFormat = #standard({ includePadding = true });
        expected = "AAEQESAh";
      },
      {
        // Characters that map to different values in base64
        input = "+/=";
        outputFormat = #standard({ includePadding = true });
        expected = "Ky89";
      },
      {
        // Same characters in URI-safe mode
        input = "+/=";
        outputFormat = #url({ includePadding = false });
        expected = "Ky89";
      }

    ];
    for (testCase in testCases.vals()) {
      let actual = BaseX.toBase64(testCase.input.vals(), testCase.outputFormat);
      if (actual != testCase.expected) {
        Debug.trap(
          "toBase64 Failure\nValue: " # debug_show (testCase.input) # "\nOutputFormat: " # debug_show (testCase.outputFormat) # "\nExpected: " # testCase.expected # "\nActual:   " # actual
        );
      };
      switch (BaseX.fromBase64(actual)) {
        case (#err(e)) Runtime.trap("Failed to decode base64 value: " # actual # ". Error: " # e);
        case (#ok(actualReverse)) {
          let actualReverseBlob = Blob.fromArray(actualReverse);
          if (actualReverseBlob != testCase.input) {
            Runtime.trap("fromBase64 Failure\nValue: " # debug_show (actual) # "\nOutputFormat: " # debug_show (testCase.outputFormat) # "\nExpected: " # debug_show (testCase.input) # "\nActual:   " # debug_show (actualReverseBlob));
          };
        };
      };

      // Addditional test for Base64 from f0i/identify
      switch (Base64.decode(actual # "=")) {
        case (#ok(decoded)) {
          let decodedBlob = Blob.fromArray(decoded);
          if (decodedBlob != testCase.input) {
            Runtime.trap("f0i/identify - Base64 decode mismatch\nExpected: " # debug_show (testCase.input) # "\nActual:   " # debug_show (decodedBlob));
          };
        };
        case (#err(e)) Runtime.trap("f0i/identify - Failed to decode base64 value: " # actual # ". Error: " # e);
      };
    };
  },
);
