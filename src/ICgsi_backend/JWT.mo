import { JSON } "mo:serde";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Base64 "Base64";
import Sha256 "mo:sha2/Sha256";
import RSA "./RSA";

module {
  public type Header = {
    alg : Text;
    typ : Text; // optional but recomended
    kid : Text; // optional but needed for our usecase
    cty : ?Text;
    jku : ?Text;
    x5t : ?Text;
    x5c : ?Text;
    crit : ?Text;
  };

  public type Payload = {
    iss : Text;
    sub : Text;
    aud : Text;
    exp : Nat;
    iat : Nat;
    jti : Text;
    email : Text;
    name : Text;
  };

  public func decode(token : Text, pubKeys : [RSA.PubKey]) : Result.Result<Text, Text> {
    assert (pubKeys.size() > 0);
    let iter = Text.split(token, #char('.'));

    let ?header64 = iter.next() else return #err("no header found");
    let ?payload64 = iter.next() else return #err("no payload found");
    let ?signature64 = iter.next() else return #err("no singnature found");
    let null = iter.next() else return #err("excess data in token");

    // decode header
    let headerJSON = switch (Base64.URLEncoding.decodeTextToText(header64)) {
      case (#ok data) data;
      case (#err err) return #err("could not decode header: " # err);
    };
    let headerBlob = switch (JSON.fromText(headerJSON, null)) {
      case (#ok data) data;
      case (#err err) return #err("could not decode header: " # err);
    };
    let ?header : ?Header = from_candid (headerBlob) else return #err("missing fields in header " # headerJSON);
    if (header.typ != "JWT") return #err("invalid JWT header: typ must be JWT");

    // select RSA key
    let ?pubKey = Array.find(pubKeys, func(k : RSA.PubKey) : Bool = (k.kid == header.kid)) else return #err("no matching key found");
    if (pubKey.kty != "RSA") return #err("invalid key: kty must be RSA");
    if (pubKey.alg != "RS256") return #err("invalid key: alg must be RS256");
    if (pubKey.use != "sig") return #err("invalid key: use must be sig");

    // decode payload
    let payloadJSON = switch (Base64.URLEncoding.decodeTextToText(payload64)) {
      case (#ok data) data;
      case (#err err) return #err("could not decode header: " # err);
    };
    let payloadBlob = switch (JSON.fromText(payloadJSON, null)) {
      case (#ok data) data;
      case (#err err) return #err("could not decode header: " # err);
    };
    let ?payload : ?Payload = from_candid (payloadBlob) else return #err("missing fields in payload " # payloadJSON);

    // check signature
    let hash : Blob = Sha256.fromBlob(#sha256, Text.encodeUtf8(header64 # "." # payload64));
    let check = RSA.verifySig(hash, signature64, pubKey);

    return #ok(debug_show (header) # debug_show (payload) # debug_show (check));
  };
};
