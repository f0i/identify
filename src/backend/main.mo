import Result "mo:base/Result";
import Time "mo:new-base/Time";
import Map "mo:map/Map";
import { phash } "mo:map/Map";
import Set "mo:map/Set";
import Jwt "JWT";
import RSA "RSA";
import Delegation "Delegation";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import CertifiedData "mo:base/CertifiedData";
import Http "Http";
import Stats "Stats";
import Email "Email";
import HashTree "HashTree";
import CanisterSignature "CanisterSignature";
import Hex "Hex";
import { setTimer; recurringTimer } = "mo:base/Timer";
import AuthProvider "AuthProvider";
import Option "mo:new-base/Option";
import TimeFormat "TimeFormat";
import Ed25519 "Ed25519";

actor class Main() = this {
  type Duration = Time.Duration;
  let toNanos = Time.toNanoseconds;

  let MAX_EXPIRATION_TIME = #days(31);
  let MIN_EXPIRATION_TIME = #minutes(2);
  let MIN_FETCH_ATTEMPT_TIME = #minutes(10);
  let MIN_FETCH_TIME = #hours(6);
  // Max time between prepareDelegation and getDelegation calls
  let MAX_TIME_PER_LOGIN = #minutes(5);

  type HashTree = HashTree.HashTree;
  type Time = Time.Time;

  type User = { email : Text; sub : Text; origin : Text; createdAt : Time };
  stable var users : Map.Map<Principal, User> = Map.new();

  /// data from older versions
  stable var keyPairs : Map.Map<Text, Ed25519.KeyPair> = Map.new();
  stable var emails : Map.Map<Principal, Text> = Map.new();

  type AppInfo = { name : Text; origins : [Text] };
  stable var trustedApps : Map.Map<Principal, AppInfo> = Map.new();

  stable var stats = Stats.new(1000);
  Stats.log(stats, "deploied new backend version.");

  type OAuth2ConnectConfig = AuthProvider.OAuth2ConnectConfig;
  let googleConfig : OAuth2ConnectConfig = {
    provider = #google;
    clientId = "376650571127-vpotkr4kt7d76o8mki09f7a2vopatdp6.apps.googleusercontent.com";
    keysUrl = "https://www.googleapis.com/oauth2/v3/certs";
    var keys : [RSA.PubKey] = [];
  };

  let _zidadelConfig : OAuth2ConnectConfig = {
    provider = #zitadel;
    clientId = "327788236128717664";
    keysUrl = "https://identify-ci5vmz.us1.zitadel.cloud/oauth/v2/keys";
    var keys : [RSA.PubKey] = [];
  };

  // Reset trusted apps on each deployment
  trustedApps := Map.new();
  let btcGiftCards = {
    name = "Bitcoin Gift Cards";
    origins = ["https://btc-gift-cards.com", "https://y4leg-vyaaa-aaaah-aq3ra-cai.icp0.io"];
  };
  Map.set(trustedApps, phash, Principal.fromText("yvip2-dqaaa-aaaah-aq3qq-cai"), btcGiftCards);
  let btcGiftCardsDemo = {
    name = "Bitcoin Gift Cards Demo";
    origins = ["https://mdh4j-syaaa-aaaah-arcfq-cai.icp0.io"];
  };
  Map.set(trustedApps, phash, Principal.fromText("meg25-7aaaa-aaaah-arcfa-cai"), btcGiftCardsDemo);

  // Transform http request by sorting keys by key ID
  public query func transform(raw : Http.TransformArgs) : async Http.TransformResult {
    Http.transform(raw, #keepAll);
  };

  // Transform http request and remove first key if 3 keys are present
  public query func transform1(raw : Http.TransformArgs) : async Http.TransformResult {
    Http.transform(raw, #ignoreNofM(0, 3));
  };

  // Transform http request and remove second key if 3 keys are present
  public query func transform2(raw : Http.TransformArgs) : async Http.TransformResult {
    Http.transform(raw, #ignoreNofM(1, 3));
  };

  // Transform http request and remove third key if 3 keys are present
  public query func transform3(raw : Http.TransformArgs) : async Http.TransformResult {
    Http.transform(raw, #ignoreNofM(2, 3));
  };

  private func fetchKeys() : async () {
    ignore await fetchGoogleKeys();
  };

  let googleFetchAttempts = Stats.newAttemptTracker();

  public shared ({ caller }) func fetchGoogleKeys() : async Result.Result<[RSA.PubKey], Text> {
    Stats.logBalance(stats, "fetchGoogleKeys");
    if (not hasPermission(caller)) {
      if (Time.now() - googleFetchAttempts.lastSuccess < toNanos(MIN_FETCH_TIME)) return #err("Rate limit reached. Try again in some hours.");
      if (Time.now() - googleFetchAttempts.lastAttempt < toNanos(MIN_FETCH_ATTEMPT_TIME)) return #err("Rate limit reached. Try again in 30 minutes.");
    };

    Stats.log(stats, "attempt to fetch google keys (attempt " # Nat.toText(googleFetchAttempts.count + 1) # ")");
    let res = await AuthProvider.fetchKeys(googleConfig, googleFetchAttempts, transform);

    Stats.log(stats, Nat.toText(googleConfig.keys.size()) # " google keys fetched.");
    return res;
  };

  type PrepRes = Result.Result<{ pubKey : [Nat8]; expireAt : Time }, Text>;

  let sigStore = CanisterSignature.newStore(Principal.fromActor(this));

  // TODO: change interface type of expireIn to Duration
  public shared func prepareDelegation(token : Text, origin : Text, sessionKey : [Nat8], expireIn : Nat, targets : ?[Principal]) : async PrepRes {
    Stats.logBalance(stats, "prepareDelegationSig");

    // check preconditions
    if (googleConfig.keys.size() == 0) return #err("Google keys not loaded");
    if (expireIn > toNanos(MAX_EXPIRATION_TIME)) return #err("Expiration time to long");
    if (expireIn < toNanos(MIN_EXPIRATION_TIME)) return #err("Expiration time to short");
    let now = Time.now();
    let expireAt = now + expireIn;

    let nonce = ?Hex.toText(sessionKey);
    // Time of JWT token from google must not be more than 5 minutes in the future
    let jwt = switch (Jwt.decode(token, googleConfig.keys, now, #seconds(60), [googleConfig.clientId], nonce)) {
      case (#err err) {
        Stats.log(stats, "getDelegations failed: invalid token from " # origin);
        return #err("failed to decode token: " # err);
      };
      case (#ok data) data;
    };

    let sub = jwt.payload.sub;

    // This is adding a signature to the sigTree and storing its hash in certified data.
    let pubKey = CanisterSignature.prepareDelegation(sigStore, sub, origin, sessionKey, now, MAX_TIME_PER_LOGIN, expireAt, targets);

    // store user data
    let principal = CanisterSignature.pubKeyToPrincipal(pubKey);
    // TODO: make email optional
    let rawEmail = Option.get(jwt.payload.email, "");
    let normalized = Email.normalizeEmail(rawEmail);
    switch (normalized) {
      case (#err err) {
        Stats.log(stats, "!!!!!!!!!! Could not normalize email address which was signed by google: " # err # " !!!!!!!!!!");
        return #err("Failed to normalize gmail address.");
      };
      case (#ok email) {
        if (Map.has(users, phash, principal)) {
          Stats.inc(stats, "signin", origin);
        } else {
          Map.set(users, phash, principal, { email; sub; origin; createdAt = Time.now() });
          Stats.inc(stats, "signup", origin);
          Stats.inc(stats, "signin", origin);
        };
      };
    };

    return #ok({
      pubKey;
      expireAt;
    });
  };

  public shared query func getDelegation(token : Text, origin : Text, sessionKey : [Nat8], expireAt : Time, targets : ?[Principal]) : async Result.Result<{ auth : Delegation.AuthResponse }, Text> {
    // The log statements will only show up if this function is called as an update call
    Stats.logBalance(stats, "getDelegations");

    // If called as an update call, the getCertificate function returns null
    if (CertifiedData.getCertificate() == null) return #err("This function must only be called using query calls");

    // verify token
    if (googleConfig.keys.size() == 0) return #err("Google keys not loaded");
    if (expireAt < Time.now()) return #err("Expired");

    let nonce = ?Hex.toText(sessionKey);
    // Time of JWT token from google must not be more than 5 minutes in the future
    let jwt = switch (Jwt.decode(token, googleConfig.keys, Time.now(), #minutes(5), [googleConfig.clientId], nonce)) {
      case (#err err) {
        Stats.log(stats, "getDelegations failed: invalid token from " # origin # " " # err);
        return #err("failed to decode token: " # err);
      };
      case (#ok data) data;
    };

    let sub = jwt.payload.sub;

    //sign delegation
    let auth = CanisterSignature.getDelegation(sigStore, sub, origin, sessionKey, expireAt, targets);

    return #ok({ auth });
  };

  public shared query func checkEmail(principal : Principal, email : Text) : async Bool {
    Stats.logBalance(stats, "checkEmail");
    let ?actual = Map.get(users, phash, principal) else return false;
    return email == actual.email;
  };

  /// Get an email address for a principal
  public shared query ({ caller }) func getEmail(principal : Principal, origin : Text) : async ?Text {
    Stats.logBalance(stats, "getEmail");
    let ?appInfo = Map.get(trustedApps, phash, caller) else Debug.trap("Permission denied for caller " # Principal.toText(caller));
    for (o in appInfo.origins.vals()) {
      if (o == origin) {
        let ?user = Map.get(users, phash, principal) else return null;
        if (user.origin == origin) return ?user.email;
      };
    };
    // origin was not in appInfo.origions
    Debug.trap("Permission denied for origin " # origin);
  };

  /// Get an email address for a principal
  public shared query ({ caller }) func getUser(principal : Principal, origin : Text) : async ?User {
    Stats.logBalance(stats, "getUser");
    let ?appInfo = Map.get(trustedApps, phash, caller) else Debug.trap("Permission denied for caller " # Principal.toText(caller));
    for (o in appInfo.origins.vals()) {
      if (o == origin) {
        let ?user = Map.get(users, phash, principal) else return null;
        if (user.origin == origin) return ?user;
      };
    };
    // origin was not in appInfo.origions
    Debug.trap("Permission denied for origin " # origin);
  };

  public shared query ({ caller }) func getPrincipal() : async Text {
    Stats.logBalance(stats, "getPrincipal");
    let hasEmail = if (Map.has(users, phash, caller)) "\nEmail address saved" else "\nNo email set";
    if (Principal.isAnonymous(caller)) return "Anonymous user (not signed in) " # Principal.toText(caller);
    return "Principal " # Principal.toText(caller) # hasEmail;
  };

  public shared query ({ caller }) func getBalance() : async {
    val : Nat;
    text : Text;
  } {
    if (not hasPermission(caller)) {
      Debug.trap("Permisison denied.");
    };
    let val = Stats.cycleBalanceStart();
    let text = Stats.formatNat(val, "C");
    return { val; text };
  };

  public shared query ({ caller }) func getStats() : async [Text] {
    Stats.logBalance(stats, "getStats");
    let appCount = Nat.toText(Stats.getSubCount(stats, "register")) # " apps connected";
    let keyCount = Nat.toText(Map.size(users)) # " identities created";
    let loginCount = Nat.toText(Stats.getSubSum(stats, "signin")) # " sign ins";

    if (not hasPermission(caller) or true) {
      return [appCount, keyCount, loginCount];
    };
    let counter = Stats.counterEntries(stats);
    let counterText = Array.map<Stats.CounterEntry, Text>(counter, func(c) = c.category # " " # c.sub # ": " # Nat.toText(c.counter));

    let costs = Stats.costData(stats);

    let log = Iter.toArray(Stats.logEntries(stats));
    let accs = Iter.toArray(Iter.map(Map.entries(users), func((p : Principal, u : User)) : Text = Principal.toText(p) # " " # u.email # " " # u.origin # " " # TimeFormat.toText(u.createdAt)));
    return Array.flatten<Text>([[appCount, keyCount, loginCount], counterText, costs, log, accs]);
  };

  stable var mods : Set.Set<Principal> = Set.new();
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
  ignore setTimer<system>(#seconds(1), fetchKeys);
  ignore recurringTimer<system>(#seconds(60 * 60 * 48), fetchKeys);

};
