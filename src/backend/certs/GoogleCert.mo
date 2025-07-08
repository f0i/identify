import Text "mo:base/Text";
import Array "mo:base/Array";
import Char "mo:base/Char";
import Debug "mo:base/Debug";

module {
  /// Strategy to select which keys to keep from the Google certificate response.
  /// When keys are rotated, it can happen that the responses differ based on the location of the replica performing the http outcall.
  /// This is usually when a new key is added or an old one is removed, but not propageted to all global google endpoints.
  /// Using this strategy allows to ignore a secific key based on the index.
  public type IgnoreKey = {
    #keepAll;
    #ignoreNofM : (Nat, Nat); // remove one key at index n if there are at least m keys
  };

  /// Sort keys and fields from the certificate response body.
  /// The received JSON data can be in any order, so this function will turn them into a deterministic order.
  /// This is required to reach consensus on the http response data across all replicas.
  public func transformBody(body : Text, ignoreKey : IgnoreKey) : Text {
    let lines = Text.split(body, #char '\n');
    var buffer = Array.init<Text>(6, "");
    var keys = Array.init<Text>(7, "");
    var keyIndex = 0;
    var lineNo = 0;
    label lineLoop for (line in lines) {
      lineNo += 1;
      var entry = Text.trim(line, #predicate(func(c) = Char.isWhitespace(c) or c == ','));
      if (lineNo == 1) {
        if (entry != "{") Debug.trap("Invalid response line 1");
      } else if (lineNo == 2) {
        if (entry != "\"keys\": [") Debug.trap("Invalid response line 2");
      } else if (Text.startsWith(entry, #text "\"kid\": ")) {
        buffer[0] := entry;
      } else if (Text.startsWith(entry, #text "\"n\": ")) {
        buffer[1] := entry;
      } else if (Text.startsWith(entry, #text "\"e\": ")) {
        buffer[2] := entry;
      } else if (Text.startsWith(entry, #text "\"use\": ")) {
        buffer[3] := entry;
      } else if (Text.startsWith(entry, #text "\"alg\": ")) {
        buffer[4] := entry;
      } else if (Text.startsWith(entry, #text "\"kty\": ")) {
        buffer[5] := entry;
      } else if (Text.startsWith(entry, #text "}") and buffer[0] != "") {
        keys[keyIndex] := "{" # Text.join(", ", buffer.vals()) # "}";
        buffer := Array.init<Text>(6, "");
        keyIndex += 1;
        if (keyIndex >= keys.size()) break lineLoop;
      };
    };

    let sorted = Array.sort<Text>(Array.filter(Array.freeze(keys), func(t : Text) : Bool = t != ""), Text.compare);
    let final = switch (ignoreKey) {
      case (#keepAll) sorted;
      case (#ignoreNofM((n, m))) {
        assert (n < m);
        assert (m >= 2); // less then 2 would never return any keys
        if (Array.size(sorted) < m) {
          sorted;
        } else {
          Array.tabulate(m - 1 : Nat, func(i : Nat) : Text = if (i < n) sorted[i] else sorted[i + 1]);
        };
      };
    };

    return "{ \"keys\": [\n" # Text.join(",\n", final.vals()) # "\n]}";
  };
};
