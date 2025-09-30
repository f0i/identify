import List "mo:core/List";
import Runtime "mo:core/Runtime";
import Result "mo:core/Result";
import Array "mo:core/Array";
import Debug "mo:core/Debug";
import Nat "mo:core/Nat";
import Map "mo:core/Map";
import Time "mo:core/Time";
import Principal "mo:core/Principal";
import Text "mo:core/Text";
import Order "mo:core/Order";
import Blob "mo:core/Blob";
import Nat8 "mo:core/Nat8";
import CertifiedData "mo:core/CertifiedData";
import Sha256 "mo:sha2/Sha256";
import AuthProvider "AuthProvider";
import Http "Http";
import RSA "RSA";
import CanisterSignature "CanisterSignature";
import Delegation "Delegation";
import User "User";
import Hex "mo:hex";
import Jwt "JWT";
import PKCE "PKCE";

module {
  type List<T> = List.List<T>;
  type ProviderKey = AuthProvider.ProviderKey;
  type SignInInfo = AuthProvider.SignInInfo;
  type Result<T> = Result.Result<T, Text>;
  type Map<K, V> = Map.Map<K, V>;
  type Time = Time.Time;
  type User = User.User;
  type TransformFn = Http.TransformFn;
  public type OAuth2Config = AuthProvider.OAuth2Config;
  public type FrontendOAuth2Config = AuthProvider.FrontendOAuth2Config;
  let toNanos = Time.toNanoseconds;

  /// Maximum session time before delegation expires
  let MAX_EXPIRATION_TIME = #days(31);
  /// Minimum session time before delegation expires
  let MIN_EXPIRATION_TIME = #minutes(2);
  /// Max time between prepareDelegation and getDelegation calls
  let MAX_TIME_PER_LOGIN = #minutes(5);

  public type PrepRes = Result<{ pubKey : [Nat8]; expireAt : Time; isNew : Bool }>;

  public type Identify = {
    providers : List<AuthProvider.OAuth2Config>;
    owner : Principal;
    sigStore : CanisterSignature.SignatureStore;
    signIns : Map<[Nat8], SignInInfo>;
    users : Map<Principal, User>;
  };

  /// Initialize a new Identify state.
  /// Parameters:
  /// - backend: The principal of the canister that will be used to sign delegations.
  /// - owner: The principal of the user that is allowed to add and update providers.
  public func init(backend : Principal, owner : Principal) : Identify {
    return {
      providers = List.empty();
      owner;
      sigStore = CanisterSignature.newStore(backend);
      signIns = Map.empty<[Nat8], SignInInfo>();
      users = Map.empty<Principal, User>();
    };
  };

  /// Add a provider to the list of configured providers.
  /// This function can only be called by the owner (which is provided on init.)
  /// The config.provider must be unique, otherwise the previous one will be replaced
  public func addProvider(config : Identify, providerConfig : AuthProvider.OAuth2Config, caller : Principal) {
    if (caller != config.owner) Runtime.trap("Permission denied");

    switch (List.findIndex(config.providers, func(other : OAuth2Config) : Bool = AuthProvider.compareProvider(providerConfig, other) == #equal)) {
      case (null) {
        Debug.print("Adding provider " # providerConfig.name # " with config " # debug_show providerConfig);
        List.add(config.providers, providerConfig);
      };
      case (?index) {
        Debug.print("Replace provider " # providerConfig.name # " with config " # debug_show providerConfig);
        List.put(config.providers, index, providerConfig);
      };
    };

  };

  /// Add a provider to the list of configured providers.
  /// If a authority is provided, the configuration will be loaded from the configuration in GET <authnority>.well-known/openid-configuration.
  /// Parameters:
  /// - config: The Identify state.
  /// - provider: The provider configuration to add. If the auth field contains a authority, the configuration will be fetched from there.
  /// - caller: The principal of the caller. Must be the owner.
  public func addProviderFetch(config : Identify, provider : OAuth2Config, caller : Principal, transform : TransformFn) : async* Result<()> {
    if (caller != config.owner) Runtime.trap("Permission denied");

    var providerConfig : AuthProvider.OAuth2Config = provider;
    label doFetchConfig do {
      switch (provider.auth) {
        case (#jwt(conf)) {
          if (conf.keysUrl != "") break doFetchConfig;
          let authority = conf.authority;
          let partialAuth = switch (await* AuthProvider.fetchConfig(authority, transform)) {
            case (#ok(data)) data;
            case (#err(err)) return #err(err);
          };
          providerConfig := {
            provider = provider.provider;
            name = provider.name;
            auth = #jwt({
              conf with
              keysUrl = partialAuth.jwks_uri;
            });
            var keys = provider.keys;
            var fetchAttempts = provider.fetchAttempts;
          };
        };
        case (#pkce(_)) { break doFetchConfig };
      };
    };
    addProvider(config, providerConfig, caller);
    return #ok;
  };

  public func getConfig(config : Identify, provider : ProviderKey) : ?AuthProvider.OAuth2Config {
    for (config in List.values(config.providers)) {
      if (config.provider == provider) return ?config;
    };
    // not found
    return null;
  };

  public func prefetchKeys(identify : Identify, transformKeys : TransformFn) : async* [Result<[RSA.PubKey]>] {
    let results = List.empty<Result<[RSA.PubKey]>>();
    for (config in List.values(identify.providers)) {
      if (AuthProvider.shouldPrefetch(config)) {
        let res = await* fetchKeys(config, transformKeys);
        List.add(results, res);
      };
    };
    return List.toArray(results);
  };

  func fetchKeys(providerConfig : AuthProvider.OAuth2Config, transformKeys : Http.TransformFn) : async* Result<[RSA.PubKey]> {
    let res = await* AuthProvider.fetchKeys(providerConfig, transformKeys);

    // Debug messages
    switch (res) {
      case (#ok(keys)) {
        let keyIDs = Array.map(keys, func(k : RSA.PubKey) : Text = k.kid);
        Debug.print(
          Nat.toText(keys.size()) # " keys loaded for " # providerConfig.name # " (" # Text.join(", ", keyIDs.vals()) # ")"
        );
        return #ok(keys);
      };
      case (#err(msg)) {
        Debug.print(msg);
        return #err(msg);
      };
    };
  };

  public func prepareDelegation(
    identify : Identify,
    provider : ProviderKey,
    token : Text,
    origin : Text,
    sessionKey : [Nat8],
    expireIn : Nat,
    targets : ?[Principal],
    transformKeys : TransformFn,
  ) : async* PrepRes {
    let ?providerConfig = getConfig(identify, provider) else return #err("No configruration found for " # AuthProvider.providerName(provider));
    let #jwt(authConfig) = providerConfig.auth else return #err(providerConfig.name # " does not support JWT based sing in");

    // check preconditions
    if (expireIn > toNanos(MAX_EXPIRATION_TIME)) return #err("Expiration time to long");
    if (expireIn < toNanos(MIN_EXPIRATION_TIME)) return #err("Expiration time to short");
    let now = Time.now();
    let expireAt = now + expireIn;

    let nonce = ?Hex.toText(sessionKey);
    // Time of JWT token from google must not be more than 5 minutes in the future
    let getKeys = AuthProvider.getKeyFn(providerConfig, transformKeys);
    let jwt = switch (await* Jwt.decode(token, getKeys, now, #minutes(5), [authConfig.clientId], nonce)) {
      case (#err(err)) {
        return #err("failed to decode token: " # err);
      };
      case (#ok data) data;
    };

    let sub = jwt.payload.sub;
    // sign delegation
    let signInInfo : SignInInfo = {
      provider;
      sub;
      origin;
      signin = Time.now();
    };

    // This is adding a signature to the sigTree and storing its hash in certified data.
    let userKeySeed = AuthProvider.getUserKeySeed(signInInfo);
    let pubKey = CanisterSignature.prepareDelegation(identify.sigStore, userKeySeed, sessionKey, now, MAX_TIME_PER_LOGIN, expireAt, targets);
    Map.add(identify.signIns, compareKey, sessionKey, signInInfo); // Use user_data_from_pkce.id for sub

    // store user data
    let principal = CanisterSignature.pubKeyToPrincipal(pubKey);

    let newUser = User.fromJWT(origin, provider, jwt); // New line

    var isNew = false;
    let user : User = switch (Map.get(identify.users, Principal.compare, principal)) {
      case (?old) {
        User.update(old, origin, provider, newUser); // Changed
      };
      case (null) {
        isNew := true;
        newUser;
      };
    };
    Map.add(identify.users, Principal.compare, principal, user);

    return #ok({
      pubKey;
      expireAt;
      isNew;
    });
  };

  public func prepareDelegationPKCE(
    identify : Identify,
    provider : ProviderKey,
    code : Text,
    verifier : Text,
    origin : Text,
    sessionKey : [Nat8],
    expireIn : Nat,
    targets : ?[Principal],
    transform : TransformFn,
  ) : async* PrepRes {

    // load Provider config
    let ?providerConfig = getConfig(identify, provider) else return #err("No configruration found for " # AuthProvider.providerName(provider));
    let #pkce(_authConfig) = providerConfig.auth else return #err(providerConfig.name # " does not support PKCE based sing in");

    // check preconditions
    if (expireIn > toNanos(MAX_EXPIRATION_TIME)) return #err("Expiration time to long");
    if (expireIn < toNanos(MIN_EXPIRATION_TIME)) return #err("Expiration time to short");
    let now = Time.now();
    let expireAt = now + expireIn;

    if (sessionKey.size() < 30) return #err("Session key is too short. It is " # Nat.toText(sessionKey.size()) # " bytes.");

    let keyHash = Sha256.fromArray(#sha256, sessionKey);
    let nonce = Hex.toText(Blob.toArray(keyHash));
    if (not Text.startsWith(verifier, #text nonce)) return #err("Code verifier does not match the session key. " # verifier # " does not start with " # nonce);
    // Time of JWT token from google must not be more than 5 minutes in the future

    // Exchange code for token!
    let response = await PKCE.exchangeToken(providerConfig, code, verifier, transform);

    let token = switch (response) {
      case (#ok(bearer)) { bearer };
      case (#err(err)) {
        return #err("Failed to get the bearer auth token: " # err);
      };
    };

    let user_data_from_pkce = switch (await PKCE.getUserInfo(providerConfig, token, transform)) {
      // Pass origin
      case (#ok(data)) data;
      case (#err(err)) return #err("Could not get user info: " # err);
    };

    let newUser = User.fromPKCE(origin, provider, user_data_from_pkce);

    let signInInfo : SignInInfo = {
      provider;
      sub = newUser.id;
      origin;
      signin = Time.now();
    };
    Map.add(identify.signIns, compareKey, sessionKey, signInInfo); // Use user_data_from_pkce.id for sub

    // This is adding a signature to the sigTree and storing its hash in certified data.
    let userKeySeed = AuthProvider.getUserKeySeed(signInInfo);
    let pubKey = CanisterSignature.prepareDelegation(identify.sigStore, userKeySeed, sessionKey, now, MAX_TIME_PER_LOGIN, expireAt, targets);

    // store user data
    let principal = CanisterSignature.pubKeyToPrincipal(pubKey);

    var isNew = false;
    let user : User = switch (Map.get(identify.users, Principal.compare, principal)) {
      case (?old) {
        User.update(old, origin, provider, newUser);
      };
      case (null) {
        isNew := true;
        newUser;
      };
    };
    Map.add(identify.users, Principal.compare, principal, user);

    return #ok({
      pubKey;
      expireAt;
      isNew;
    });
  };

  public func getDelegation(
    identify : Identify,
    provider : ProviderKey,
    origin : Text,
    sessionKey : [Nat8],
    expireAt : Time,
    targets : ?[Principal],
  ) : Result.Result<{ auth : Delegation.AuthResponse }, Text> {

    // If called as an update call, the getCertificate function returns null
    if (CertifiedData.getCertificate() == null) return #err("This function must only be called using query calls");

    // check if user prepared a delegation
    let ?signInInfo = Map.get(identify.signIns, compareKey, sessionKey) else return #err("Delegation not prepared. Call prepareDelegation or prepareDelegationPKCE first.");

    // verify token
    if (expireAt < Time.now()) return #err("Expired");
    if (origin != signInInfo.origin) return #err("Invalid origin");
    if (provider != signInInfo.provider) return #err("Invalid provider");

    let userKeySeed = AuthProvider.getUserKeySeed(signInInfo);
    let auth = CanisterSignature.getDelegation(identify.sigStore, userKeySeed, sessionKey, expireAt, targets);

    Map.add(identify.signIns, compareKey, sessionKey, signInInfo); // Use user_data_from_pkce.id for sub

    return #ok({ auth });
  };

  /// Compare two Nat8 Arrays
  func compareKey(a : [Nat8], b : [Nat8]) : Order.Order = Array.compare(a, b, Nat8.compare);

  /// Get user information for a specific principal
  public func getUser(identify : Identify, principal : Principal) : ?User {
    Map.get(identify.users, Principal.compare, principal);
  };

  /// Get the list of provider configurations for the frontend
  public func getProviders(identify : Identify) : [FrontendOAuth2Config] {
    let providers = List.map<OAuth2Config, FrontendOAuth2Config>(identify.providers, AuthProvider.toFrontendConfig);
    return List.toArray(providers);
  };

};
