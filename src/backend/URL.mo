import Char "mo:core/Char";
import Text "mo:core/Text";
import Blob "mo:core/Blob";
import Hex "mo:hex";

module {

  public func urlEncode(input : Text) : Text {
    var out = "";
    for (c in input.chars()) {
      let code = Char.toNat32(c);
      let char = Char.toText(c);
      if (
        (code >= 97 and code <= 122) or // a-z
        (code >= 48 and code <= 57) or // 0-9
        (code >= 64 and code <= 90) or // A-Z
        (code == 45) or // -
        (code == 46) or // .
        (code == 95) or // _
        (code == 126) // ~
      ) {
        out #= char;
      } else {
        let encoded = Text.encodeUtf8(char) |> Blob.toArray(_);
        let urlEncoded = Hex.toTextFormat(encoded, Hex.URL);
        out #= urlEncoded;
      };
    };
    out;
  };

};
