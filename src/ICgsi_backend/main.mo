import Text "mo:base/Text";
import Debug "mo:base/Debug";

actor Main {

  // Helper function to decode Base64URL
  func decodeBase64Url(encoded : Text) : ?[Nat8] {
    let fixed = Text.replace(encoded, "-", "+");
    let fixed = Text.replace(fixed, "_", "/");

    let paddingLength = (4 - (Text.size(fixed) % 4)) % 4;
    let padded = fixed # Text.replicate("=", paddingLength);

    Base64.decode(padded);
  };

  // Helper function to parse JSON from Text
  func parseJson(jsonStr : Text) : ?JSON.Value {
    switch (JSON.parse(jsonStr)) {
      case (?json) {
        return ?json;
      };
      case _ { return null };
    };
  };

  // Function to parse the JWT token
  public query func parseJwt(jwt : Text) : ?Text {
    let parts = Text.split(jwt, ".");

    // Ensure JWT has three parts (header, payload, signature)
    if (Array.size(parts) != 3) {
      return null;
    };

    let payloadBase64 = parts[1];

    // Decode the Base64URL payload
    let decodedPayloadBytes = decodeBase64Url(payloadBase64);

    switch decodedPayloadBytes {
      case (?bytes) {
        let jsonStr = Text.fromBlob(bytes);
        // Parse the JSON payload
        switch (parseJson(jsonStr)) {
          case (?jsonValue) {
            // Extract specific fields from the payload (like email, name, etc.)
            switch (jsonValue) {
              case ({ "email" : ?email; "name" : ?name }) {
                return ?("Email: " # email # ", Name: " # name);
              };
              case _ { return null };
            };
          };
          case _ { return null };
        };
      };
      case _ { return null };
    };
  };
};
