import Result "mo:core/Result";
import Time "mo:core/Time";
import Map "mo:core/Map";
import { phash } "mo:map/Map";
import Set "mo:map/Set";
import Jwt "JWT";
import RSA "RSA";
import Delegation "Delegation";
import Principal "mo:core/Principal";
import Nat "mo:core/Nat";
import Nat8 "mo:core/Nat8";
import CertifiedData "mo:core/CertifiedData";
import Http "Http";
import Stats "Stats";
import CanisterSignature "CanisterSignature";
import Hex "mo:hex";
import { setTimer; recurringTimer } = "mo:core/Timer";
import AuthProvider "AuthProvider";
import { trap } "mo:core/Runtime";
import Debug "mo:core/Debug";
import Array "mo:core/Array";
import Blob "mo:core/Blob";
import Text "mo:core/Text";
import Order "mo:core/Order";
import User "User";
import PKCE "PKCE";
import Sha256 "mo:sha2/Sha256";

persistent actor class Main() = this {
  type Duration = Time.Duration;

  transient let toNanos = Time.toNanoseconds;

  /// Maximum session time before delegation expires
  transient let MAX_EXPIRATION_TIME = #days(31);
  /// Minimum session time before delegation expires
  transient let MIN_EXPIRATION_TIME = #minutes(2);
  /// Minimum time between updating oAuth keys from provider.
  /// Thisl will limit the amoutn of requests when invalid key-ids are used,
  /// but could also case users to not be able to sign in for some minutes, if the key just updated.
  transient let _MIN_FETCH_ATTEMPT_TIME = #minutes(10);
  /// Minimum time between successful fetch attempts
  transient let _MIN_FETCH_TIME = #hours(6);
  /// Max time between prepareDelegation and getDelegation calls
  transient let MAX_TIME_PER_LOGIN = #minutes(5);
  /// Interval to automatically update keys
  transient let KEY_UPDATE_INTERVAL = #hours(48);

  type Time = Time.Time;
  type Provider = AuthProvider.Provider;
  type Result<T> = Result.Result<T, Text>;

  type User = User.User;
  var users : Map.Map<Principal, User> = Map.empty();

  type AppInfo = { name : Text; origins : [Text] };
  var trustedApps : Map.Map<Principal, AppInfo> = Map.empty();

  var stats = Stats.new(1000);
  Stats.log(stats, "deploied new backend version.");

  type OAuth2ConnectConfig = AuthProvider.OAuth2ConnectConfig;
  transient let googleConfig : OAuth2ConnectConfig = {
    name = "Google";
    provider = #google;
    auth = #jwt({
      clientId = "376650571127-vpotkr4kt7d76o8mki09f7a2vopatdp6.apps.googleusercontent.com";
      keysUrl = "https://www.googleapis.com/oauth2/v3/certs";
    });
    var keys : [RSA.PubKey] = [];
    var fetchAttempts = Stats.newAttemptTracker();
  };

  transient let auth0Config : OAuth2ConnectConfig = {
    name = "Auth0";
    provider = #auth0;
    auth = #jwt({
      clientId = "oUmJhfEd58KnHhaPhInnIAWFREw8MPoJ";
      keysUrl = "https://identify.uk.auth0.com/.well-known/jwks.json";
    });
    var keys : [RSA.PubKey] = [];
    var fetchAttempts = Stats.newAttemptTracker();
  };

  transient let zitadelConfig : OAuth2ConnectConfig = {
    name = "Zitadel";
    provider = #zitadel;
    auth = #jwt({
      clientId = "327788236128717664";
      keysUrl = "https://identify-ci5vmz.us1.zitadel.cloud/oauth/v2/keys";
    });
    var keys : [RSA.PubKey] = [];
    var fetchAttempts = Stats.newAttemptTracker();
  };

  transient let githubConfig : OAuth2ConnectConfig = {
    name = "GitHub";
    provider = #github;
    auth = #pkce({
      authorizationUrl = "https://github.com/login/oauth/authorize";
      tokenUrl = "https://github.com/login/oauth/access_token";
      userInfoEndpoint = "https://api.github.com/user";
      clientId = "Ov23liMbdP36K0AIWTgl";
      redirectUri = "https://login.f0i.de/pkce-callback.html";
      clientSecret = ?"b58638c2d453de538bc72e5b3b3d4ca7f23b2faa";
    });
    var keys : [RSA.PubKey] = [];
    var fetchAttempts = Stats.newAttemptTracker();
  };

  transient let xConfig : OAuth2ConnectConfig = {
    name = "X";
    provider = #x;
    auth = #pkce({
      authorizationUrl = "https://x.com/i/oauth2/authorize";
      tokenUrl = "https://api.x.com/2/oauth2/token";
      userInfoEndpoint = "https://api.x.com/2/users/me?user.fields=created_at,description,entities,id,location,name,pinned_tweet_id,profile_image_url,protected,public_metrics,url,username,verified,withheld";
      clientId = "c1Y3cWhOekU1SFlwVkJCNlFmbWU6MTpjaQ";
      redirectUri = "https://login.f0i.de/pkce-callback.html";
      clientSecret = null;
    });
    var keys : [RSA.PubKey] = [];
    var fetchAttempts = Stats.newAttemptTracker();
  };

  // Reset trusted apps on each deployment
  trustedApps := Map.empty();
  transient let btcGiftCards = {
    name = "Bitcoin Gift Cards";
    origins = ["https://btc-gift-cards.com", "https://y4leg-vyaaa-aaaah-aq3ra-cai.icp0.io"];
  };
  Map.add(trustedApps, Principal.compare, Principal.fromText("yvip2-dqaaa-aaaah-aq3qq-cai"), btcGiftCards);
  transient let btcGiftCardsDemo = {
    name = "Bitcoin Gift Cards Demo";
    origins = ["https://mdh4j-syaaa-aaaah-arcfq-cai.icp0.io"];
  };
  Map.add(trustedApps, Principal.compare, Principal.fromText("meg25-7aaaa-aaaah-arcfa-cai"), btcGiftCardsDemo);

  // Transform http request by sorting keys by key ID
  public query func transformKeys(raw : Http.TransformArgs) : async Http.TransformResult {
    Http.transformKeys(raw);
  };

  // Transform http request without changing anything
  public query func transform(raw : Http.TransformArgs) : async Http.TransformResult {
    Http.transform(raw);
  };

  private func getProviderConfig(provider : Provider) : OAuth2ConnectConfig {
    switch (provider) {
      case (#google) return googleConfig;
      case (#auth0) return auth0Config;
      case (#zitadel) return zitadelConfig;
      case (#github) return githubConfig;
      case (#x) return xConfig;
    };
  };

  private func fetchAllKeys() : async () {
    ignore await fetchKeys(#google);
    ignore await fetchKeys(#auth0);
    ignore await fetchKeys(#zitadel);
  };

  /// Fetch keys for a specific provider.
  /// Returns the keyids that were fetched.
  private func fetchKeys(provider : Provider) : async Result<()> {
    let providerConfig = getProviderConfig(provider);
    let res = await AuthProvider.fetchKeys(providerConfig, transformKeys);
    let providerName = AuthProvider.providerName(provider);
    switch (res) {
      case (#ok(keys)) {
        let keyIDs = Array.map(keys, func(k : RSA.PubKey) : Text = k.kid);
        Debug.print(
          Nat.toText(keys.size()) # " keys loaded for " # providerName # " (" # Text.join(", ", keyIDs.vals()) # ")"
        );
        return #ok;
      };
      case (#err(err)) {
        Debug.print(err);
        return #err(err);
      };
    };
  };

  type PrepRes = Result<{ pubKey : [Nat8]; expireAt : Time }>;

  transient let sigStore = CanisterSignature.newStore(Principal.fromActor(this));

  /// Verify the token and prepare a delegation.
  /// The delegation can be fetched using an query call to getDelegation.
  public shared func prepareDelegation(provider : Provider, token : Text, origin : Text, sessionKey : [Nat8], expireIn : Nat, targets : ?[Principal]) : async PrepRes {
    Stats.logBalance(stats, "prepareDelegationSig");

    // load Provider config
    let providerConfig = getProviderConfig(provider);
    let #jwt(authConfig) = providerConfig.auth else return #err(providerConfig.name # " does not support JWT based sing in");

    // check preconditions
    if (providerConfig.keys.size() == 0) return #err("Keys not loaded for " # providerConfig.name);
    if (expireIn > toNanos(MAX_EXPIRATION_TIME)) return #err("Expiration time to long");
    if (expireIn < toNanos(MIN_EXPIRATION_TIME)) return #err("Expiration time to short");
    let now = Time.now();
    let expireAt = now + expireIn;

    let nonce = ?Hex.toText(sessionKey);
    // Time of JWT token from google must not be more than 5 minutes in the future
    let getKeys = AuthProvider.getKeyFn(providerConfig, transformKeys);
    let jwt = switch (await* Jwt.decode(token, getKeys, now, #minutes(5), [authConfig.clientId], nonce)) {
      case (#err(err)) {
        Stats.log(stats, "getDelegations failed: invalid token from " # origin);
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
    let pubKey = CanisterSignature.prepareDelegation(sigStore, userKeySeed, sessionKey, now, MAX_TIME_PER_LOGIN, expireAt, targets);
    Map.add(pkceSignIns, compareKey, sessionKey, signInInfo); // Use user_data_from_pkce.id for sub

    // store user data
    let principal = CanisterSignature.pubKeyToPrincipal(pubKey);

    let newUser = User.fromJWT(origin, provider, jwt); // New line

    let user : User = switch (Map.get(users, Principal.compare, principal)) {
      case (?old) {
        User.update(old, origin, provider, newUser); // Changed
      };
      case (null) {
        Stats.inc(stats, "signup", origin);
        newUser;
      };
    };
    Map.add(users, Principal.compare, principal, user);
    Stats.inc(stats, "signin", origin);

    return #ok({
      pubKey;
      expireAt;
    });
  };

  public shared query func getDelegation(provider : Provider, origin : Text, sessionKey : [Nat8], expireAt : Time, targets : ?[Principal]) : async Result.Result<{ auth : Delegation.AuthResponse }, Text> {
    // The log statements will only show up if this function is called as an update call
    Stats.logBalance(stats, "getDelegations");

    // If called as an update call, the getCertificate function returns null
    if (CertifiedData.getCertificate() == null) return #err("This function must only be called using query calls");

    // check if user prepared a delegation
    let ?signInInfo = Map.get(pkceSignIns, compareKey, sessionKey) else return #err("Delegation not prepared. Call prepareDelegation or prepareDelegationPKCE first.");

    // verify token
    if (expireAt < Time.now()) return #err("Expired");
    if (origin != signInInfo.origin) return #err("Invalid origin");
    if (provider != signInInfo.provider) return #err("Invalid provider");

    let userKeySeed = AuthProvider.getUserKeySeed(signInInfo);
    let auth = CanisterSignature.getDelegation(sigStore, userKeySeed, sessionKey, expireAt, targets);

    Map.add(pkceSignIns, compareKey, sessionKey, signInInfo); // Use user_data_from_pkce.id for sub

    return #ok({ auth });
  };

  type SignInInfo = AuthProvider.SignInInfo;
  transient var pkceSignIns = Map.empty<[Nat8], SignInInfo>();

  public shared func prepareDelegationPKCE(provider : Provider, code : Text, verifier : Text, origin : Text, sessionKey : [Nat8], expireIn : Nat, targets : ?[Principal]) : async PrepRes {
    Stats.logBalance(stats, "prepareDelegationPKCE");

    // load Provider config
    let providerConfig = getProviderConfig(provider);
    let #pkce(_authConfig) = providerConfig.auth else return #err(providerConfig.name # " does not support JWT based sing in");

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
    Map.add(pkceSignIns, compareKey, sessionKey, signInInfo); // Use user_data_from_pkce.id for sub

    // This is adding a signature to the sigTree and storing its hash in certified data.
    let userKeySeed = AuthProvider.getUserKeySeed(signInInfo);
    let pubKey = CanisterSignature.prepareDelegation(sigStore, userKeySeed, sessionKey, now, MAX_TIME_PER_LOGIN, expireAt, targets);

    // store user data
    let principal = CanisterSignature.pubKeyToPrincipal(pubKey);

    let user : User = switch (Map.get(users, Principal.compare, principal)) {
      case (?old) {
        User.update(old, origin, provider, newUser);
      };
      case (null) {
        Stats.inc(stats, "signup", origin);
        newUser;
      };
    };
    Map.add(users, Principal.compare, principal, user);
    Stats.inc(stats, "signin", origin);

    return #ok({
      pubKey;
      expireAt;
    });
  };

  public shared query func checkEmail(principal : Principal, email : Text) : async Bool {
    Stats.logBalance(stats, "checkEmail");
    let ?actual = Map.get(users, Principal.compare, principal) else return false;
    return ?email == actual.email;
  };

  /// Get an email address for a principal
  /// This function can only be called from whitelisted principals, usually the backend canister of an app
  public shared query ({ caller }) func getEmail(principal : Principal, origin : Text) : async ?Text {
    Stats.logBalance(stats, "getEmail");
    let ?appInfo = Map.get(trustedApps, Principal.compare, caller) else trap("Permission denied for caller " # Principal.toText(caller));
    for (o in appInfo.origins.vals()) {
      if (o == origin) {
        let ?user = Map.get(users, Principal.compare, principal) else return null;
        if (user.email_verified != ?true) return null;
        if (user.origin == origin) return user.email;
      };
    };
    // origin was not in appInfo.origions
    trap("Permission denied for origin " # origin);
  };

  /// Get an email address for a principal
  /// This function can only be called from whitelisted principals, usually the backend canister of an app
  public shared query ({ caller }) func getUser(principal : Principal, origin : Text) : async ?User {
    Stats.logBalance(stats, "getUser");
    //let ?appInfo = Map.get(trustedApps, Principal.compare, caller) else trap("Permission denied for caller " # Principal.toText(caller));
    //for (o in appInfo.origins.vals()) {
    //if (o == origin) {
    let ?user = Map.get(users, Principal.compare, principal) else return null;
    //if (user.origin == origin)
    return ?user;
    //};
    //};
    // origin was not in appInfo.origions
    //trap("Permission denied for origin " # origin);
  };

  /// Get principal and some user info of the caller
  public shared query ({ caller }) func getPrincipal() : async Principal {
    Stats.logBalance(stats, "getPrincipal");
    return caller;

    //let userInfo = switch (Map.get(users, Principal.compare, caller)) {
    //  case (?user) {
    //    "Signed in with " # AuthProvider.providerName(user.provider) # ". " #
    //    "User found: " # (debug_show user);
    //  };
    //  case (null) "User not found";
    //};

    //if (Principal.isAnonymous(caller)) return "Anonymous user (not signed in) " # Principal.toText(caller);
    //return "Principal " # Principal.toText(caller) # "\n" # userInfo;
  };

  /// Get cycle balance of the backend canister
  public shared query ({ caller }) func getBalance() : async {
    val : Nat;
    text : Text;
  } {
    if (not hasPermission(caller)) {
      trap("Permisison denied.");
    };
    let val = Stats.cycleBalanceStart();
    let text = Stats.formatNat(val, "C");
    return { val; text };
  };

  public shared query func getStats() : async [Text] {
    Stats.logBalance(stats, "getStats");
    let appCount = Nat.toText(Stats.getSubCount(stats, "signup")) # " apps connected";
    let keyCount = Nat.toText(Map.size(users)) # " identities created";
    let loginCount = Nat.toText(Stats.getSubSum(stats, "signin")) # " sign ins";
    return [appCount, keyCount, loginCount];
  };

  public shared query ({ caller }) func info() : async Text {
    if (not hasPermission(caller)) Stats.logBalance(stats, "getStats");

    let g = Array.map(googleConfig.keys, func(k : RSA.PubKey) : Text = k.kid) |> Text.join(", ", _.vals());
    let a = Array.map(auth0Config.keys, func(k : RSA.PubKey) : Text = k.kid) |> Text.join(", ", _.vals());
    let z = Array.map(zitadelConfig.keys, func(k : RSA.PubKey) : Text = k.kid) |> Text.join(", ", _.vals());
    return debug_show [g, a, z];
  };

  func compareKey(a : [Nat8], b : [Nat8]) : Order.Order = Array.compare(a, b, Nat8.compare);

  var mods : Set.Set<Principal> = Set.new();
  public shared ({ caller }) func addMod(user : Principal) : async Result.Result<(), Text> {
    Stats.logBalance(stats, "addMod");
    if (not Principal.isController(caller)) return #err("Permisison denied.");
    Set.add(mods, phash, user);
    #ok;
  };
  private func hasPermission(user : Principal) : Bool {
    if (Principal.isController(user)) return true;
    if (Set.has(mods, phash, user)) return true;
    return false;
  };

  // Update keys now and every 2 days
  ignore setTimer<system>(#seconds(1), fetchAllKeys);
  ignore recurringTimer<system>(KEY_UPDATE_INTERVAL, fetchAllKeys);

};
