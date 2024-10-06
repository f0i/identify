import { JSON } "mo:serde";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Time "mo:base/Time";
import Nat "mo:base/Nat";
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

  public type JWT = {
    header : Header;
    payload : Payload;
    signature : Text;
  };

  public func decode(token : Text, pubKeys : [RSA.PubKey], now : Time.Time) : Result.Result<JWT, Text> {
    assert (pubKeys.size() > 0);
    let nowS = now / 1_000_000_000;
    let iter = Text.split(token, #char('.'));

    let ?header64 = iter.next() else return #err("no header found");
    let ?payload64 = iter.next() else return #err("no payload found");
    let ?signature64 = iter.next() else return #err("no singnature found");
    let null = iter.next() else return #err("excess data in token");

    // decode header
    let headerJSON = switch (Base64.decodeText(header64)) {
      case (#ok data) data;
      case (#err err) return #err("could not decode header: " # err);
    };
    let headerBlob = switch (JSON.fromText(headerJSON, null)) {
      case (#ok data) data;
      case (#err err) return #err("could not decode header: " # err # " " # headerJSON);
    };
    let ?header : ?Header = from_candid (headerBlob) else return #err("missing fields in header " # headerJSON);
    if (header.typ != "JWT") return #err("invalid JWT header: typ must be JWT");

    // select RSA key
    let ?pubKey = Array.find(pubKeys, func(k : RSA.PubKey) : Bool = (k.kid == header.kid)) else return #err("no matching key found");
    if (pubKey.kty != "RSA") return #err("invalid key: kty must be RSA");
    if (pubKey.alg != "RS256") return #err("invalid key: alg must be RS256");
    if (pubKey.use != "sig") return #err("invalid key: use must be sig");

    // decode payload
    let payloadJSON = switch (Base64.decodeText(payload64)) {
      case (#ok data) data;
      case (#err err) return #err("could not decode payload: " # err);
    };
    let payloadBlob = switch (JSON.fromText(payloadJSON, null)) {
      case (#ok data) data;
      case (#err err) return #err("could not decode payload: " # err # " >" # payloadJSON # "<");
    };
    let ?payload : ?Payload = from_candid (payloadBlob) else return #err("missing fields in payload " # payloadJSON);

    if (payload.iat > nowS) return #err("JWT creation time " # Nat.toText(payload.iat) # " invalid");
    //TODO! re-enable
    //if (payload.exp < nowS) return #err("JWT is expired at " # Nat.toText(payload.exp));

    // check signature
    let hash : Blob = Sha256.fromBlob(#sha256, Text.encodeUtf8(header64 # "." # payload64));
    switch (RSA.verifySig(hash, signature64, pubKey)) {
      case (#ok) {};
      case (#err err) return #err(err);
    };

    return #ok({ header; payload; signature = signature64 });
  };
};
