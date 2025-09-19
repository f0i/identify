import Result "mo:core/Result";
import Time "mo:core/Time";
import Map "mo:core/Map";
import { phash } "mo:map/Map";
import Set "mo:map/Set";
import RSA "RSA";
import Delegation "Delegation";
import Principal "mo:core/Principal";
import Nat "mo:core/Nat";
import Nat8 "mo:core/Nat8";
import Http "Http";
import Stats "Stats";
import { setTimer; recurringTimer } = "mo:core/Timer";
import AuthProvider "AuthProvider";
import { trap } "mo:core/Runtime";
import Array "mo:core/Array";
import Text "mo:core/Text";
import User "User";
import Identify "Identify";
import Whitelist "Whitelist";

shared ({ caller = initializer }) persistent actor class Main() = this {
  let owner = initializer;
  let backend = Principal.fromActor(this);

  type Duration = Time.Duration;
  type User = User.User;

  /// Minimum time between updating oAuth keys from provider.
  /// Thisl will limit the amoutn of requests when invalid key-ids are used,
  /// but could also case users to not be able to sign in for some minutes, if the key just updated.
  transient let _MIN_FETCH_ATTEMPT_TIME = #minutes(10);
  /// Minimum time between successful fetch attempts
  transient let _MIN_FETCH_TIME = #hours(6);
  /// Interval to automatically update keys
  transient let KEY_UPDATE_INTERVAL = #hours(48);

  type Time = Time.Time;
  type Provider = AuthProvider.Provider;
  type Result<T> = Result.Result<T, Text>;
  type PrepRes = Identify.PrepRes;

  var stats = Stats.new(1000);
  Stats.log(stats, "deploied new backend version.");

  let identify = Identify.init(backend, owner);

  /// Verify the token and prepare a delegation.
  /// The delegation can be fetched using an query call to getDelegation.
  public shared func prepareDelegation(
    provider : Provider,
    token : Text,
    origin : Text,
    sessionKey : [Nat8],
    expireIn : Nat,
    targets : ?[Principal],
  ) : async PrepRes {
    Stats.logBalance(stats, "prepareDelegationSig");

    let res = await* Identify.prepareDelegation(identify, provider, token, origin, sessionKey, expireIn, targets, transformKeys);

    let #ok(data) = res else return res;
    if (data.isNew) Stats.inc(stats, "signup", origin);
    Stats.inc(stats, "signin", origin);

    return res;
  };

  // Check PKCE sign in and prepare delegation
  public shared func prepareDelegationPKCE(
    provider : Provider,
    code : Text,
    verifier : Text,
    origin : Text,
    sessionKey : [Nat8],
    expireIn : Nat,
    targets : ?[Principal],
  ) : async PrepRes {
    Stats.logBalance(stats, "prepareDelegationPKCE");

    let res = await* Identify.prepareDelegationPKCE(identify, provider, code, verifier, origin, sessionKey, expireIn, targets, transform);

    let #ok(data) = res else return res;
    if (data.isNew) Stats.inc(stats, "signup", origin);
    Stats.inc(stats, "signin", origin);

    return res;
  };

  // Get the previously prepared delegation
  public shared query func getDelegation(
    provider : Provider,
    origin : Text,
    sessionKey : [Nat8],
    expireAt : Time,
    targets : ?[Principal],
  ) : async Result.Result<{ auth : Delegation.AuthResponse }, Text> {
    // The log statements will only show up if this function is called as an update call
    Stats.logBalance(stats, "getDelegations");

    let res = Identify.getDelegation(identify, provider, origin, sessionKey, expireAt, targets);

    return res;
  };

  // Transform http request by sorting keys by key ID
  public query func transformKeys(raw : Http.TransformArgs) : async Http.TransformResult {
    Http.transformKeys(raw);
  };

  // Transform http request without changing anything
  public query func transform(raw : Http.TransformArgs) : async Http.TransformResult {
    Http.transform(raw);
  };

  /// Whitelist provides helper functions to limit access to user data
  var whitelist = Whitelist.empty();
  Whitelist.addApp(
    whitelist,
    "Bitcoin Gift Cards",
    Principal.fromText("yvip2-dqaaa-aaaah-aq3qq-cai"),
    ["https://btc-gift-cards.com", "https://y4leg-vyaaa-aaaah-aq3ra-cai.icp0.io"],
  );
  Whitelist.addApp(
    whitelist,
    "Bitcoin Gift Cards Demo",
    Principal.fromText("meg25-7aaaa-aaaah-arcfa-cai"),
    ["https://mdh4j-syaaa-aaaah-arcfq-cai.icp0.io"],
  );

  /// Get an email address for a principal
  /// This function can only be called from whitelisted principals, usually the backend canister of an app
  public shared query ({ caller }) func getEmail(principal : Principal, origin : Text) : async ?Text {
    Stats.logBalance(stats, "getEmail");

    let ?user = Identify.getUser(identify, principal) else return null;

    // Optional: use whitelist to limit access to user data to specific apps.
    if (not Whitelist.isWhitelisted(whitelist, caller, origin, user.origin)) {
      // trap("Permission denied for origin " # origin);
    };
    return user.email;
  };

  /// Get an email address for a principal
  /// This function can only be called from whitelisted principals, usually the backend canister of an app
  public shared query ({ caller }) func getUser(principal : Principal, origin : Text) : async ?User {
    Stats.logBalance(stats, "getUser");
    let ?user = Identify.getUser(identify, principal) else return null;

    // Optional: use whitelist to limit access to user data to specific apps.
    if (not Whitelist.isWhitelisted(whitelist, caller, origin, user.origin)) {
      // trap("Permission denied for origin " # origin);
    };
    return ?user;
  };

  /// Get principal and some user info of the caller
  public shared query ({ caller }) func getPrincipal() : async Principal {
    Stats.logBalance(stats, "getPrincipal");
    return caller;
  };

  /// Get cycle balance of the backend canister
  public shared query func getBalance() : async {
    val : Nat;
    text : Text;
  } {
    let val = Stats.cycleBalanceStart();
    let text = Stats.formatNat(val, "C");
    return { val; text };
  };

  /// Get information about the app
  public shared query func getStats() : async [Text] {
    Stats.logBalance(stats, "getStats");
    let appCount = Nat.toText(Stats.getSubCount(stats, "signup")) # " apps connected";
    let keyCount = Nat.toText(Map.size(identify.users)) # " identities created";
    let loginCount = Nat.toText(Stats.getSubSum(stats, "signin")) # " sign ins";
    return [appCount, keyCount, loginCount];
  };

  /// Show the latest key IDs
  public shared query func showKeyIds() : async Text {
    let g = Array.map(googleConfig.keys, func(k : RSA.PubKey) : Text = k.kid) |> Text.join(", ", _.vals());
    let a = Array.map(auth0Config.keys, func(k : RSA.PubKey) : Text = k.kid) |> Text.join(", ", _.vals());
    let z = Array.map(zitadelConfig.keys, func(k : RSA.PubKey) : Text = k.kid) |> Text.join(", ", _.vals());
    return debug_show [g, a, z];
  };

  // Pre-fetch keys to verify JWT keys.
  private func fetchAllKeys() : async () {
    // Key updates are logged using Debug.print. You can check by calling `dfx canister logs --ic backend`
    ignore await* Identify.prefetchKeys(identify, transformKeys);
  };

  /// Update keys now and every 2 days
  ignore setTimer<system>(#seconds(1), fetchAllKeys);
  ignore recurringTimer<system>(KEY_UPDATE_INTERVAL, fetchAllKeys);

  /// Sample configurations
  type OAuth2Config = AuthProvider.OAuth2Config;
  type OIDCConfig = AuthProvider.OAuth2Config;

  transient let googleConfig : OAuth2Config = {
    name = "Google";
    provider = #google;
    auth = #jwt({
      clientId = "376650571127-vpotkr4kt7d76o8mki09f7a2vopatdp6.apps.googleusercontent.com";
      keysUrl = "https://www.googleapis.com/oauth2/v3/certs";
      preFetch = true;
      authority = null;
      fedCMConfigUrl = null;
      responseType = #code;
      scope = ?"openid email profile";
    });
    var keys : [RSA.PubKey] = [];
    var fetchAttempts = Stats.newAttemptTracker();
  };

  transient let auth0Config : OAuth2Config = {
    name = "Auth0";
    provider = #auth0;
    auth = #jwt({
      clientId = "oUmJhfEd58KnHhaPhInnIAWFREw8MPoJ";
      keysUrl = "https://identify.uk.auth0.com/.well-known/jwks.json";
      preFetch = true;
      authority = null;
      fedCMConfigUrl = null;
      responseType = #code;
      scope = ?"openid email profile";
    });
    var keys : [RSA.PubKey] = [];
    var fetchAttempts = Stats.newAttemptTracker();
  };

  transient let zitadelConfig : OAuth2Config = {
    name = "Zitadel";
    provider = #zitadel;
    auth = #jwt({
      clientId = "327788236128717664";
      keysUrl = "https://identify-ci5vmz.us1.zitadel.cloud/oauth/v2/keys";
      preFetch = false;
      authority = null;
      fedCMConfigUrl = null;
      responseType = #code;
      scope = ?"openid email profile";
    });
    var keys : [RSA.PubKey] = [];
    var fetchAttempts = Stats.newAttemptTracker();
  };

  transient let githubConfig : OAuth2Config = {
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

  transient let xConfig : OAuth2Config = {
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

  Identify.addProvider(identify, googleConfig, owner);
  Identify.addProvider(identify, auth0Config, owner);
  Identify.addProvider(identify, zitadelConfig, owner);
  Identify.addProvider(identify, xConfig, owner);
  Identify.addProvider(identify, githubConfig, owner);

  public shared ({ caller }) func addProvider(name : Text, params : AuthProvider.AuthParams) : async Result<()> {
    // Permission check.
    // Permission is also checked inside the addProvider function.
    // Checking here again is optional, but I prefer to exit as soon as possible.
    if (not Principal.isController(caller)) trap("Permission denied");
    if (caller == owner) trap("Permission denied");
    // Create and add the configuration
    let config = {
      provider = #generic(name);
      name = name;
      auth = params;
      var keys : [RSA.PubKey] = [];
      var fetchAttempts = Stats.newAttemptTracker();
    };
    Identify.addProviderFetch(identify, config, caller);
    return #ok;
  };

};
