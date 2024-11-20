import Result "mo:base/Result";
import Time "mo:base/Time";
import Map "mo:map/Map";
import { thash; phash } "mo:map/Map";
import Set "mo:map/Set";
import Jwt "JWT";
import RSA "RSA";
import Delegation "Delegation";
import Ed25519 "Ed25519";
import Nat32 "mo:base/Nat32";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Http "Http";
import Stats "Stats";
import Email "Email";

actor Main {
  let TIME_MINUTE = 60 * 1_000_000_000;
  let TIME_HOUR = 60 * TIME_MINUTE;
  let MAX_EXPIRATION_TIME = 31 * 24 * TIME_HOUR;
  let MIN_FETCH_ATTEMPT_TIME = TIME_MINUTE * 10;
  let MIN_FETCH_TIME = 6 * TIME_HOUR;

  type KeyPair = Ed25519.KeyPair;
  stable var keyPairs : Map.Map<Text, KeyPair> = Map.new();
  stable var emails : Map.Map<Principal, Text> = Map.new();
  stable var trustedApps : Map.Map<Principal, Text> = Map.new();

  stable var stats = Stats.new(1000);
  Stats.log(stats, "deploied new backend version.");

  var googleKeys : [RSA.PubKey] = [];

  public query func transform(raw : Http.TransformArgs) : async Http.CanisterHttpResponsePayload {
    Http.transform(raw);
  };

  var lastFetchaAttempt : Time.Time = 0;
  var pendingFetchAttempts : Nat = 0;
  var lastFetch : Time.Time = 0;
  public shared ({ caller }) func fetchGoogleKeys() : async Result.Result<{ keys : [RSA.PubKey] }, Text> {
    Stats.logBalance(stats, "fetchGoogleKeys");
    if (not hasPermission(caller)) {
      if (Time.now() - lastFetch < MIN_FETCH_TIME) return #err("Rate limit reached. Try again in some hours.");
      if (Time.now() - lastFetchaAttempt < MIN_FETCH_ATTEMPT_TIME) return #err("Rate limit reached. Try again in 30 minutes.");
    };
    pendingFetchAttempts += 1;
    lastFetchaAttempt := Time.now();
    Stats.log(stats, "attempt to fetch google keys (attempt " # Nat.toText(pendingFetchAttempts) # ")");

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
    if (pendingFetchAttempts < 3 and googleKeys.size() != 0) {
      return #err("Function inactive. Try using fetchGoogleKeys instead. pending Fetch requests: " # Nat.toText(pendingFetchAttempts));
    };
    if (not hasPermission(caller)) {
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

  type PrepRes = Result.Result<{ pubKey : [Nat8]; register : Bool }, Text>;
  public shared func prepareDelegation(sub : Text, origin : Text, token : Nat32) : async PrepRes {
    Stats.logBalance(stats, "prepareDelegation");
    // prevent bots and people exploring the interface from creating keys *by accident*
    if (token != 123454321) return #err("Invalid token");
    let lookupKey = origin # " " # sub;
    var register = false;
    let pubKey = switch (Map.get(keyPairs, thash, lookupKey)) {
      case (?keyPair) {
        Stats.inc(stats, "login", origin);
        Stats.log(stats, "login from " # lookupKey);
        keyPair.publicKey;
      };
      case (null) {
        Stats.inc(stats, "register", origin);
        register := true;
        let key = await Ed25519.generateKeyPair();
        Map.set(keyPairs, thash, lookupKey, key);
        Stats.log(stats, "register user from " # lookupKey);
        key.publicKey;
      };
    };

    return #ok({
      pubKey;
      register;
    });
  };

  public shared query func getDelegations(token : Text, origin : Text, sessionKey : [Nat8], expireIn : Nat) : async Result.Result<{ auth : Delegation.AuthResponse; emailSet : Bool }, Text> {
    // The log statements will only show up if this function is called as an update call
    Stats.logBalance(stats, "getDelegations");
    // verify token
    if (googleKeys.size() == 0) return #err("Google keys not loaded");
    if (expireIn > MAX_EXPIRATION_TIME) return #err("Expiration time to long");

    // Time of JWT token from google must not be more than 5 minutes in the future
    let jwt = switch (Jwt.decode(token, googleKeys, Time.now(), 5 * 60 /*seconds*/)) {
      case (#err err) {
        Stats.log(stats, "getDelegations failed: invalid token from " # origin);
        return #err("failed to decode token: " # err);
      };
      case (#ok data) data;
    };

    // get prepared keys
    let lookupKey = origin # " " # jwt.payload.sub;
    let keyPair = switch (Map.get(keyPairs, thash, lookupKey)) {
      case (?keys) keys;
      case (null) {
        Stats.log(stats, "getDelegations failed: no key for " # lookupKey);
        return #err("Could not get key for " # lookupKey # ".");
      };
    };

    // sign delegation
    let authResponse = Delegation.getDelegation(sessionKey, keyPair, Time.now() + expireIn);
    let emailSet = Map.has(emails, phash, Ed25519.toPrincipal(keyPair.publicKey));

    return #ok({
      auth = authResponse;
      emailSet;
    });
  };

  public shared ({ caller }) func setEmail(token : Text, origin : Text) : async Result.Result<{ email : Text; principal : Principal; caller : Principal }, Text> {
    // The log statement will only show up if this function is called as an update call
    Stats.logBalance(stats, "setEmail");
    // verify token
    if (googleKeys.size() == 0) return #err("Google keys not loaded");

    // Time of JWT token from google must not be more than 5 minutes in the future
    let jwt = switch (Jwt.decode(token, googleKeys, Time.now(), 5 * 60 /*seconds*/)) {
      case (#err err) {
        Stats.log(stats, "setEmail failed: invalid token from " # origin);
        return #err("failed to decode token: " # err);
      };
      case (#ok data) data;
    };

    // get prepared keys
    let lookupKey = origin # " " # jwt.payload.sub;
    let keyPair = switch (Map.get(keyPairs, thash, lookupKey)) {
      case (?keys) keys;
      case (null) {
        Stats.log(stats, "setEmail failed: no key for " # lookupKey);
        return #err("Could not get key for " # lookupKey # ".");
      };
    };
    let principal = Ed25519.toPrincipal(keyPair.publicKey);
    let email = jwt.payload.email;
    let normalized = Email.normalizeEmail(email);
    switch (normalized) {
      case (#ok email) {
        Map.set(emails, phash, principal, email);
      };
      case (#err err) {
        Stats.log(stats, "!!!!!!!!!! Could not normalize gmail address which was signed by google: " # err # " !!!!!!!!!!");
        return #err("Failed to normalize gmail address.");
      };
    };

    return #ok({
      email;
      principal;
      caller;
    });
  };

  public shared query func checkEmail(principal : Principal, email : Text) : async Bool {
    Stats.logBalance(stats, "checkEmail");
    let ?actual = Map.get(emails, phash, principal) else return false;
    return email == actual;
  };

  public shared query ({ caller }) func getEmail(principal : Principal) : async ?Text {
    Stats.logBalance(stats, "getEmail");
    let ?_name = Map.get(trustedApps, phash, caller) else Debug.trap("Permission denied for " # Principal.toText(caller));
    return Map.get(emails, phash, principal);
  };

  public shared query ({ caller }) func getPrincipal() : async Text {
    Stats.logBalance(stats, "getPrincipal");
    let hasEmail = if (Map.has(emails, phash, caller)) " email set" else " no email set";
    if (Principal.isAnonymous(caller)) return "Anonymous user (not signed in) " # Principal.toText(caller);
    return "Principal " # Principal.toText(caller) # hasEmail;
  };

  public shared query ({ caller }) func getStats() : async [Text] {
    Stats.logBalance(stats, "getStats");
    let appCount = Nat.toText(Stats.getSubCount(stats, "register")) # " apps connected";
    let keyCount = Nat.toText(Map.size(keyPairs)) # " identities created";
    let loginCount = Nat.toText(Stats.getSubSum(stats, "login") + Map.size(keyPairs)) # " sign ins";

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
