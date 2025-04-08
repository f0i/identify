import Result "mo:base/Result";
import Time "mo:base/Time";
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
import Blob "mo:base/Blob";
import Http "Http";
import Stats "Stats";
import Email "Email";
import HashTree "HashTree";
import CanisterSignature "CanisterSignature";
import Ed25519 "Ed25519";
import Hex "Hex";

actor class Main() = this {
  let TIME_MINUTE = 60 * 1_000_000_000;
  let TIME_HOUR = 60 * TIME_MINUTE;
  let MAX_EXPIRATION_TIME = 31 * 24 * TIME_HOUR;
  let MIN_EXPIRATION_TIME = TIME_MINUTE * 2;
  let MIN_FETCH_ATTEMPT_TIME = TIME_MINUTE * 10;
  let MIN_FETCH_TIME = 6 * TIME_HOUR;

  type HashTree = HashTree.HashTree;
  type Time = Time.Time;

  stable var emails : Map.Map<Principal, Text> = Map.new(); // TODO remove, was deprecated, use users instead
  type KeyPair = Ed25519.KeyPair;
  stable var keyPairs : Map.Map<Text, KeyPair> = Map.new();

  type User = { email : Text; sub : Text; origin : Text; createdAt : Time };
  stable var users : Map.Map<Principal, User> = Map.new();

  type AppInfo = { name : Text; origins : [Text] };
  stable var trustedApps : Map.Map<Principal, AppInfo> = Map.new();

  stable var stats = Stats.new(1000);
  Stats.log(stats, "deploied new backend version.");

  var googleKeys : [RSA.PubKey] = [];
  var googleClientIds : [Text] = ["376650571127-vpotkr4kt7d76o8mki09f7a2vopatdp6.apps.googleusercontent.com"];

  // init values
  let initKeys = "";
  switch (RSA.pubKeysFromJSON(initKeys)) {
    case (#ok keys) googleKeys := keys;
    case (#err err) {
      Stats.log(stats, "initial set google keys failed: " # err);
    };
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
    origins = ["https://mdh4j-syaaa-aaaah-arcfq-cai.icp0.io/"];
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

  var lastFetchaAttempt : Time = 0;
  var pendingFetchAttempts : Nat = 0;
  var lastFetch : Time = 0;
  public shared ({ caller }) func fetchGoogleKeys() : async Result.Result<{ keys : [RSA.PubKey] }, Text> {
    Stats.logBalance(stats, "fetchGoogleKeys");
    if (not hasPermission(caller)) {
      if (Time.now() - lastFetch < MIN_FETCH_TIME) return #err("Rate limit reached. Try again in some hours.");
      if (Time.now() - lastFetchaAttempt < MIN_FETCH_ATTEMPT_TIME) return #err("Rate limit reached. Try again in 30 minutes.");
    };
    pendingFetchAttempts += 1;
    lastFetchaAttempt := Time.now();
    Stats.log(stats, "attempt to fetch google keys (attempt " # Nat.toText(pendingFetchAttempts) # ")");

    // TODO: retry with other transform functions
    let fetched = await Http.getRequest("https://www.googleapis.com/oauth2/v3/certs", 5000, transform);

    switch (RSA.pubKeysFromJSON(fetched.data)) {
      case (#ok keys) googleKeys := keys;
      case (#err err) {
        Stats.log(stats, "google keys fetch failed: " # err);
        return #err(err);
      };
    };
    pendingFetchAttempts := 0;
    lastFetch := Time.now();
    Stats.log(stats, Nat.toText(googleKeys.size()) # " google keys fetched.");
    return #ok({
      keys = googleKeys;
    });
  };

  public shared ({ caller }) func setGoogleKeys(data : Text) : async Result.Result<{ keys : [RSA.PubKey] }, Text> {
    Stats.logBalance(stats, "setGoogleKeys");
    if (not hasPermission(caller)) {
      if (pendingFetchAttempts < 3 and googleKeys.size() != 0) {
        return #err("Function inactive. Try using fetchGoogleKeys instead. pending Fetch requests: " # Nat.toText(pendingFetchAttempts));
      };
      return #err("Permission denied.");
    };
    switch (RSA.pubKeysFromJSON(data)) {
      case (#ok keys) googleKeys := keys;
      case (#err err) {
        Stats.log(stats, "set google keys failed: " # err);
        return #err(err);
      };
    };
    Stats.log(stats, Nat.toText(googleKeys.size()) # " google keys set.");
    return #ok({
      keys = googleKeys;
    });
  };

  type PrepRes = Result.Result<{ pubKey : [Nat8]; expireAt : Time }, Text>;

  var sigTree : HashTree = #Empty;
  public shared func prepareDelegation(token : Text, origin : Text, sessionKey : [Nat8], expireIn : Nat) : async PrepRes {
    Stats.logBalance(stats, "prepareDelegationSig");

    // verify token
    if (googleKeys.size() == 0) return #err("Google keys not loaded");
    if (expireIn > MAX_EXPIRATION_TIME) return #err("Expiration time to long");
    if (expireIn < MIN_EXPIRATION_TIME) return #err("Expiration time to short");
    let expireAt = Time.now() + expireIn;

    let nonce = ?Hex.toText(sessionKey);
    // Time of JWT token from google must not be more than 5 minutes in the future
    let jwt = switch (Jwt.decode(token, googleKeys, Time.now(), 5 * 60 /*seconds*/, googleClientIds, nonce)) {
      case (#err err) {
        Stats.log(stats, "getDelegations failed: invalid token from " # origin);
        return #err("failed to decode token: " # err);
      };
      case (#ok data) data;
    };

    let sub = jwt.payload.sub;
    let { seed; hashedSeed } = HashTree.encodeSeed(origin, sub);
    let signingCanisterID = Principal.fromActor(this);
    let pubKey = CanisterSignature.DERencodePubKey(signingCanisterID, seed);

    let hash = Delegation.getUnsignedHash(sessionKey, expireAt);
    sigTree := HashTree.addSig(#Empty, hashedSeed, hash, Time.now());
    //TODO: sigTree := HashTree.addSig(sigTree, hashedSeed, hash, Time.now());
    CertifiedData.set(Blob.fromArray(HashTree.hash(sigTree)));

    let principal = CanisterSignature.toPrincipal(signingCanisterID, seed);
    let rawEmail = jwt.payload.email;
    let normalized = Email.normalizeEmail(rawEmail);
    switch (normalized) {
      case (#ok email) {
        if (Map.has(emails, phash, CanisterSignature.toPrincipal(signingCanisterID, seed))) {
          Stats.inc(stats, "signin", origin);
        } else {
          Map.set(emails, phash, principal, email);
          Map.set(users, phash, principal, { email; sub; origin; createdAt = Time.now() });
          Stats.inc(stats, "signup", origin);
          Stats.inc(stats, "signin", origin);
        };
      };
      case (#err err) {
        Stats.log(stats, "!!!!!!!!!! Could not normalize email address which was signed by google: " # err # " !!!!!!!!!!");
        return #err("Failed to normalize gmail address.");
      };
    };

    return #ok({
      pubKey;
      expireAt;
    });
  };

  public shared query func getDelegation(token : Text, origin : Text, sessionKey : [Nat8], expireAt : Time) : async Result.Result<{ auth : Delegation.AuthResponse }, Text> {
    // The log statements will only show up if this function is called as an update call
    Stats.logBalance(stats, "getDelegations");

    // If called as an update call, the getCertificate function returns null
    let ?cert = CertifiedData.getCertificate() else return #err("Certificate only available in query calls");

    // verify token
    if (googleKeys.size() == 0) return #err("Google keys not loaded");
    if (expireAt < Time.now()) return #err("Expired");

    let nonce = ?Hex.toText(sessionKey);
    // Time of JWT token from google must not be more than 5 minutes in the future
    let jwt = switch (Jwt.decode(token, googleKeys, Time.now(), 5 * 60 /*seconds*/, googleClientIds, nonce)) {
      case (#err err) {
        Stats.log(stats, "getDelegations failed: invalid token from " # origin # " " # err);
        return #err("failed to decode token: " # err);
      };
      case (#ok data) data;
    };

    let signingCanisterID = Principal.fromActor(this);
    let sub = jwt.payload.sub;
    let { seed; hashedSeed } = HashTree.encodeSeed(origin, sub);
    let pubKey = CanisterSignature.DERencodePubKey(signingCanisterID, seed);

    //sign delegation
    let signature = HashTree.getSignature(sigTree, hashedSeed, cert);
    let authResponse = Delegation.getDelegationExternalSig(sessionKey, pubKey, signature, expireAt);

    return #ok({
      auth = authResponse;
    });
  };

  public shared query func checkEmail(principal : Principal, email : Text) : async Bool {
    Stats.logBalance(stats, "checkEmail");
    let ?actual = Map.get(emails, phash, principal) else return false;
    return email == actual;
  };

  /// Get an email address for a principal
  public shared query ({ caller }) func getEmail(principal : Principal, origin : Text) : async ?Text {
    Stats.logBalance(stats, "getEmail");
    let ?appInfo = Map.get(trustedApps, phash, caller) else Debug.trap("Permission denied for " # Principal.toText(caller));
    for (o in appInfo.origins.vals()) {
      if (o == origin) {
        let ?user = Map.get(users, phash, principal) else return null;
        if (user.origin == origin) return ?user.email;
      };
    };
    // origin was not in appInfo.origions
    Debug.trap("Permission denied for " # origin);
  };

  public shared query ({ caller }) func getPrincipal() : async Text {
    Stats.logBalance(stats, "getPrincipal");
    let hasEmail = if (Map.has(emails, phash, caller)) " email set" else " no email set";
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
    let keyCount = Nat.toText(Map.size(emails)) # " identities created";
    let loginCount = Nat.toText(Stats.getSubSum(stats, "signin")) # " sign ins";

    if (not hasPermission(caller)) {
      return [appCount, keyCount, loginCount];
    };
    let counter = Stats.counterEntries(stats);
    let counterText = Array.map<Stats.CounterEntry, Text>(counter, func(c) = c.category # " " # c.sub # ": " # Nat.toText(c.counter));

    let costs = Stats.costData(stats);

    let log = Iter.toArray(Stats.logEntries(stats));
    let accs = Iter.toArray(Iter.map(Map.entries(emails), func((p : Principal, e : Text)) : Text = Principal.toText(p) # " " # e));
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

};
