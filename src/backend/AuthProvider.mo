import Http "Http";
import RSA "RSA";
import Stats "Stats";
import Time "mo:core/Time";
import Result "mo:core/Result";
import Text "mo:core/Text";
import Option "mo:core/Option";
import Debug "mo:core/Debug";
import Error "mo:core/Error";
import Array "mo:core/Array";
import Jwt "JWT";

module {
  type Result<T> = Result.Result<T, Text>;
  type GetKey = (Text) -> async* Result<RSA.PubKey>;
  type Time = Time.Time;

  public type Provider = {
    #google;
    #zitadel;
    #auth0;
    #github;
    #x;
  };

  public func providerName(provider : Provider) : Text {
    switch (provider) {
      case (#google) "Google";
      case (#zitadel) "Zitadel";
      case (#auth0) "Auth0";
      case (#github) "GitHub";
      case (#x) "X";
    };
  };

  public type SignInInfo = {
    provider : Provider;
    sub : Text;
    origin : Text;
    signin : Time;
  };

  public func getUserKeySeed(signInInfo : SignInInfo) : Text {
    providerName(signInInfo.provider) # " " # signInInfo.origin # " " # signInInfo.sub;
  };

  public type AuthParams = {
    #jwt : {
      clientId : Text;
      keysUrl : Text;
    };
    #pkce : {
      authorizationUrl : Text;
      tokenUrl : Text;
      userInfoEndpoint : Text;
      clientId : Text;
      redirectUri : Text;
      clientSecret : ?Text;
    };
  };

  public type OAuth2ConnectConfig = {
    provider : Provider;
    name : Text;
    auth : AuthParams;
    var keys : [RSA.PubKey];
    var fetchAttempts : Stats.AttemptTracker;
  };

  type TransformFn = Http.TransformFn;

  public func fetchKeys(config : OAuth2ConnectConfig, transform : TransformFn) : async Result<[RSA.PubKey]> {
    let attempts = config.fetchAttempts;
    attempts.count += 1;
    attempts.lastAttempt := Time.now();

    let #jwt(params) = config.auth else return #err("Not a JWT config");

    Debug.print("fetching keys from " # params.keysUrl);
    try {
      let fetched = await Http.getRequest(params.keysUrl, [], 5000, transform, true);

      config.keys := RSA.deserializeKeys(fetched.data);

      attempts.count := 0;
      attempts.lastSuccess := Time.now();
      return #ok(config.keys);
    } catch (e) {
      return #err("Failed to fetch keys for " # config.name # ": " # Error.message(e));
    };
  };

  public func getKeyFn(config : OAuth2ConnectConfig, transform : TransformFn) : (Text) -> async* Result<RSA.PubKey> {
    return func(keyID : Text) : async* Result<RSA.PubKey> {
      await* getKey(config, transform, keyID);
    };
  };

  public func getKey(config : OAuth2ConnectConfig, transform : TransformFn, keyID : Text) : async* Result<RSA.PubKey> {
    let optKey = Array.find(config.keys, func(k : RSA.PubKey) : Bool = (k.kid == keyID));
    switch (optKey) {
      case (?key) return #ok(key);
      case (null) {};
    };
    // Key not found, fetch current keys
    let attempts = config.fetchAttempts;
    if (attempts.lastSuccess > (Time.now() - Time.toNanoseconds(#minutes(30)))) return #err("key not found in current keys");
    if (attempts.lastAttempt > (Time.now() - Time.toNanoseconds(#minutes(10)))) return #err("key not found");
    Debug.print("Key not found for " # config.name # ": " # keyID);
    // Update keys
    do {
      let fetchRes = await fetchKeys(config, transform);
      switch (fetchRes) {
        case (#ok(keys)) {
          if (keys.size() == 0) return #err("No keys available");
        };
        case (#err(err)) { return #err(err) };
      };
      let optKey = Array.find(config.keys, func(k : RSA.PubKey) : Bool = (k.kid == keyID));
      switch (optKey) {
        case (?key) return #ok(key);
        case (null) { return #err("key id not found in up to date keys") };
      };
    };
  };

  type Identifier = {
    servie : Text;
    id : Text;
    email : ?Text;
    email_verified : Bool;
  };

  public func getIdentifier(provider : Provider, jwt : Jwt.JWT) : Result<Identifier> {
    switch (provider) {
      case (#google) {
        return #ok({
          servie = "google";
          id = jwt.payload.sub;
          email = jwt.payload.email;
          email_verified = Option.get(jwt.payload.email_verified, false);
        });
      };
      case (#zitadel) {
        if (jwt.payload.amr == ?["pwd"]) {
          return #ok({
            servie = "zitadel";
            id = jwt.payload.sub;
            email = jwt.payload.email; // TODO: check if email address is available
            email_verified = Option.get(jwt.payload.email_verified, false);
          });
        } else {
          return #err("Unsupported authentication method in zitadel: " # (debug_show jwt.payload.amr));
        };
      };
      case (#auth0) {
        let sub = jwt.payload.sub;
        let subParts = Text.split(sub, #char('|'));
        let ?auth = subParts.next() else return #err("Invalid Id token: missing dat in subject field " # sub);
        let ?userId = subParts.next() else return #err("Invalid Id token: missing user id in subject field " # sub);
        let null = subParts.next() else return #err("Invalid ID token: excess data in subject field " # sub);

        if (auth == "github" or auth == "google-oauth2") {
          return #ok({
            servie = auth;
            id = userId;
            email = jwt.payload.email;
            email_verified = Option.get(jwt.payload.email_verified, false);
          });
        } else {
          return #err("Unsupported sub format in auth0: " # jwt.payload.sub);
        };
      };
      case (_) #err("Identifier not implemented for provider " # providerName(provider));
    };
  };

  public func getVerifiedEmail(provider : Provider, jwt : Jwt.JWT) : ?Text {
    let #ok(data) = getIdentifier(provider, jwt) else return null;
    if (not data.email_verified) return null;
    return data.email;
  }

};
