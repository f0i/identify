import { JSON } "mo:serde";
import Result "mo:core/Result";
import Text "mo:core/Text";
import Array "mo:core/Array";
import Time "mo:core/Time";
import Nat "mo:core/Nat";
import Runtime "mo:core/Runtime";
import Base64 "Base64";
import Sha256 "mo:sha2/Sha256";
import RSA "./RSA";
import TimeFormat "TimeFormat";

module {
  type Time = Time.Time;
  type Duration = Time.Duration;

  /// Data sturcture of a decoded JWT token's header.
  public type Header = {
    alg : Text; // algorithm used (e.g. RS256 for RSA with SHA256)
    typ : Text; // type (e.g. JWT) optional but recomended
    kid : Text; // key ID, optional but needed for our usecase
    cty : ?Text; // content type
    jku : ?Text; // JWK Set URL
    x5t : ?Text; // X.509 certificate thumbprint
    x5c : ?Text; // X.509 certificate chain
    crit : ?Text; // criticla extensions
  };

  /// Data sturcture of a decoded JWT token's payload
  public type Payload = {
    iss : Text; // issuer
    sub : Text; // subject (Google user ID, )
    aud : [Text]; // audience (Google client ID)
    exp : Nat; // expiration time in seconds since Unix epoch
    iat : Nat; // issued at time
    jti : ?Text; // JWT token ID
    sid : ?Text; // OIDC Session ID
    email : ?Text; // user email
    email_verified : ?Bool; // email verified by auth provider
    name : ?Text; // user full name
    nonce : ?Text; // nonce (used here to link the session key)
    amr : ?[Text]; // authentication methods references
    picture : ?Text; // profile picture
    locale : ?Text; // Locale
  };

  /// Data sturcture of a decoded JWT token's payload
  private type PayloadAlt = {
    iss : Text; // issuer
    sub : Text; // subject (Google user ID, )
    aud : Text; // audience (Google client ID)
    exp : Nat; // expiration time in seconds since Unix epoch
    iat : Nat; // issued at time
    jti : ?Text; // JWT token ID
    sid : ?Text; // OIDC Session ID
    email : ?Text; // user email
    email_verified : ?Bool; // email verified by auth provider
    name : ?Text; // user full name
    nonce : ?Text; // nonce (used here to link the session key)
    amr : ?[Text] // authentication methods references
    picture : ?Text; // profile picture
    locale : ?Text; // Locale
  };

  /// Data sturcture of a decoded JWT token
  public type JWT = {
    header : Header;
    payload : Payload;
    signature : Text;
  };

  /// Decode and validate a JWT token.
  /// The payload of the token is required to contain at least values from `Header` and `Payload`.
  ///
  /// **Validation**
  ///
  /// The following validations are performed:
  ///
  /// - valid encoding without without excess data
  /// - presense of all required values in `Header` and `Payload`
  /// - The token has not expired (`now` is smaller then `header.exp`)
  /// - The token was not issued in the future (specifically not more than `issuedToleranceS` seconds in the future)
  /// - The token was issued by one of the authorized keys (specified by their private key)
  /// - The public key is of `typ`: RSA with `alg`: `RS256` for `use`: `sig`.
  /// - Header field `typ` is `JWT`
  /// - Payload field `aud` must contain a string listed in audiences
  ///
  /// **Function arguments**
  ///
  /// - token: The JWT token to decode and validate.
  /// - pubKeys: Array of public keys. The JWT token must be signed with one of the corresponding private keys. Must contain at least one public key!
  /// - now: The current time in nanos as returned by `Time.now()`.
  /// - issuedToleranceS: Specifies how much in the future the token can be generated.
  ///   This is to avoid issues with server times being slightly out of sync.
  ///   This argument has no effect on the verification of the expiration time.
  /// - audiences: Array of values allowed for the `aud` attribute inside the payload. Must contain at least one audience string.
  ///
  /// **Return value**
  ///
  /// The function returns a Result type contining the decoded values from a valid JWT token or
  /// the an error result with the reason why the token could not be verified.
  public func decode(token : Text, pubKeys : [RSA.PubKey], now : Time, issuedTolerance : Duration, audiences : [Text], nonce : ?Text) : Result.Result<JWT, Text> {
    assert (pubKeys.size() > 0);
    assert (audiences.size() > 0);

    let nowS = now / 1_000_000_000;
    let issuedToleranceS = Time.toNanoseconds(issuedTolerance) / 1_000_000_000;
    let issuedBeforeS = nowS + issuedToleranceS;
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
    let ?pubKey = Array.find(pubKeys, func(k : RSA.PubKey) : Bool = (k.kid == header.kid)) else {
      let available = Array.map(pubKeys, func(k : RSA.PubKey) : Text = k.kid) |> Text.join(", ", _.vals());
      return #err("no matching key found for keyID " # header.kid # " (available keys: " # available # ")");
    };
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
    var res : ?Payload = from_candid (payloadBlob);
    if (res == null) {
      let ?payloadAlt : ?PayloadAlt = from_candid (payloadBlob) else return #err("missing fields in payload " # payloadJSON);
      res := ?fromPayloadAlt(payloadAlt);
    };
    let ?payload : ?Payload = res else Runtime.unreachable();

    // check nonce
    if (nonce != null and nonce != payload.nonce) return #err("invalid nonce in payload");
    // check audience
    if (not hasCommonEntry(audiences, payload.aud, Text.equal)) {
      return #err("audience is not whitelisted: " # Text.join(", ", payload.aud.vals()));
    };

    // check if token is valid at the current time
    if (payload.iat > issuedBeforeS) return #err("JWT creation time " # TimeFormat.secondsToText(payload.iat) # " invalid. IC time is " # TimeFormat.toText(now) # ".");
    if (nowS > payload.exp) return #err("JWT is expired at " # Nat.toText(payload.exp));

    // check signature
    let hash : Blob = Sha256.fromBlob(#sha256, Text.encodeUtf8(header64 # "." # payload64));
    switch (RSA.verifySig(hash, signature64, pubKey)) {
      case (#ok) {};
      case (#err err) return #err(err);
    };

    return #ok({ header; payload; signature = signature64 });
  };

  /// Checks if two arrays have at least one common entry based on a provided equality function.
  ///
  /// - arrA: The first array.
  /// - arrB: The second array.
  /// - equals: A function that determines if two elements of type T are equal.
  ///
  /// Returns true if a common entry is found, false otherwise.
  private func hasCommonEntry<T>(arrA : [T], arrB : [T], equals : (a : T, b : T) -> Bool) : Bool {
    Array.any(
      arrA,
      func(a : T) : Bool {
        Array.any(arrB, func(b : T) : Bool = equals(a, b));
      },
    );
  };

  /// Convert alternative payload to common format
  private func fromPayloadAlt(alt : PayloadAlt) : Payload {
    // wrap alt.aud in an array
    return {
      iss = alt.iss;
      sub = alt.sub;
      aud = [alt.aud];
      exp = alt.exp;
      iat = alt.iat;
      jti = alt.jti;
      sid = alt.sid;
      email = alt.email;
      email_verified = alt.email_verified;
      name = alt.name;
      nonce = alt.nonce;
      amr = alt.amr;
      picture = alt.picture;
      locale = alt.locale;
    };
  };

};
