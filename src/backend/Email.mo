import Text "mo:base/Text";
import Char "mo:base/Char";
import Result "mo:base/Result";
module {
  public func normalizeGmail(gmail : Text) : Result.Result<Text, Text> {
    // Convert the email to lowercase
    let domain = "@gmail.com";
    let lower = Text.toLowercase(gmail);
    let trimmed = Text.trim(lower, #predicate(Char.isWhitespace));
    // remove @gmail.com
    let ?localPart = Text.stripEnd(trimmed, #text domain) else return #err("not a " # domain # " address");
    // remove everything after a "+" and remove dots
    let ?noPlus = Text.split(localPart, #char '+').next() else return #err("could not parse email address");
    let withoutDots = Text.replace(noPlus, #char('.'), "");

    label check for (c in Text.toIter(withoutDots)) {
      let i = Char.toNat32(c);
      // a-z
      if (i >= 97 and i <= 122) continue check;
      // 0-9
      if (i >= 48 and i <= 57) continue check;
      return #err("Invalid email address (must not contain '" # Char.toText(c) # "')");
    };

    return #ok(withoutDots # domain);
  };
};
