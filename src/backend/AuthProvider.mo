import Http "Http";
import RSA "RSA";
import Stats "Stats";
import Time "mo:core/Time";
import Result "mo:core/Result";
import Text "mo:core/Text";
import Debug "mo:core/Debug";
import Error "mo:core/Error";
import Array "mo:core/Array";
import Nat "mo:core/Nat";
import Order "mo:base/Order";
import { JSON } "mo:serde";

module {
  type Result<T> = Result.Result<T, Text>;
  type GetKey = (Text) -> async* Result<RSA.PubKey>;
  type Time = Time.Time;
  type Order = Order.Order;

  public type Provider = {
    #google;
    #zitadel;
    #auth0;
    #github;
    #x;
    #generic : Text;
  };

  public func providerName(provider : Provider) : Text {
    switch (provider) {
      case (#google) "Google";
      case (#zitadel) "Zitadel";
      case (#auth0) "Auth0";
      case (#github) "GitHub";
      case (#x) "X";
      case (#generic(key)) "SignInWith" # key;
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
    /// OpenID Connect params
    #jwt : {
      clientId : Text;
      keysUrl : Text; // TODO: rename to jwks_uri
      preFetch : Bool;
      authority : ?Text;
      fedCMConfigUrl : ?Text;
      responseType : { #code; #id_token };
      scope : ?Text;
    };
    /// PKCE params
    #pkce : {
      authorizationUrl : Text;
      tokenUrl : Text;
      userInfoEndpoint : Text;
      clientId : Text;
      redirectUri : Text;
      clientSecret : ?Text;
    };
  };

  /// Configuration values fetched from .well-known/openid-configuration
  public type PartialAuthConf = {
    jwks_uri : Text;
  };

  public type OAuth2Config = {
    provider : Provider;
    name : Text;
    auth : AuthParams;
    var keys : [RSA.PubKey];
    var fetchAttempts : Stats.AttemptTracker;
  };

  public func compare(self : OAuth2Config, other : OAuth2Config) : Order {
    let name = Text.compare(self.name, other.name);
    if (name != #equal) return name;
    let provider = Text.compare(providerName(self.provider), providerName(other.provider));
    if (provider != #equal) return provider;
    // compare other fields
    return Text.compare(debug_show self, debug_show other);
  };

  public func compareProvider(self : OAuth2Config, other : OAuth2Config) : Order {
    return Text.compare(providerName(self.provider), providerName(other.provider));
  };

  type TransformFn = Http.TransformFn;

  public func shouldPrefetch(config : OAuth2Config) : Bool {
    let #jwt(conf) = config.auth else return false;
    return conf.preFetch;
  };

  public func fetchKeys(config : OAuth2Config, transformKeys : TransformFn) : async* Result<[RSA.PubKey]> {
    let attempts = config.fetchAttempts;
    attempts.count += 1;
    attempts.lastAttempt := Time.now();

    let #jwt(params) = config.auth else return #err("Not a JWT config");

    Debug.print("fetching keys from " # params.keysUrl);
    try {
      let fetched = await Http.getRequest(params.keysUrl, [], 5000, transformKeys, true);

      config.keys := RSA.deserializeKeys(fetched.data);

      attempts.count := 0;
      attempts.lastSuccess := Time.now();

      return #ok(config.keys);
    } catch (e) {
      return #err("Failed to fetch keys for " # config.name # ": " # Error.message(e));
    };
  };

  func fetchConfig(authority : Text, transform : TransformFn) : async* Result<PartialAuthConf> {
    if (not Text.endsWith(authority, #char('/'))) {
      return #err("Invalid configuration: authority must end with '/': " # authority);
    };

    let url = authority # ".well-known/openid-configuration";
    try {
      let fetched = await Http.getRequest(url, [], 5000, transform, true);

      let dataBlob = switch (JSON.fromText(fetched.data, null)) {
        case (#ok data) data;
        case (#err err) return #err("could not parse keys: " # err);
      };
      let ?data : ?PartialAuthConf = from_candid (dataBlob) else return #err("missing fields in " # fetched.data);

      return #ok(data);
    } catch (e) {
      return #err("Failed to fetch configuration from " # url);
    };
  };

  /// Returns a function that can be used to fetch a public key by its key ID.
  ///
  /// The returned function takes a `Text` key ID and returns a Result containing
  /// either the matching RSA public key or an error message.
  public func getKeyFn(config : OAuth2Config, transform : TransformFn) : (Text) -> async* Result<RSA.PubKey> {
    return func(keyID : Text) : async* Result<RSA.PubKey> {
      await* getKey(config, transform, keyID);
    };
  };

  /// Fetches a specific RSA public key by its key ID.
  /// If a key with the given ID is present locally, it will return that one.
  /// Otherwise this function will attempt to fetch the keys for this configuration, and then check again.
  /// Re-fetching is limited to every 10 minutes if the fetch attempt failed, or 30 minutes if it was successful
  public func getKey(config : OAuth2Config, transform : TransformFn, keyID : Text) : async* Result<RSA.PubKey> {
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
      let fetchRes = await* fetchKeys(config, transform);
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

};
