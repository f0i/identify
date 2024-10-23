import Result "mo:base/Result";
import Time "mo:base/Time";
import Map "mo:map/Map";
import { thash } "mo:map/Map";
import Jwt "JWT";
import RSA "RSA";
import Delegation "Delegation";
import Ed25519 "Ed25519";
import Nat32 "mo:base/Nat32";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Http "Http";
import Stats "Stats";
import Info "Info";

actor Main {
  let TIME_HOUR = 60 * 60 * 1_000_000_000;
  let MAX_EXPIRATION_TIME = 31 * 24 * TIME_HOUR;
  let MIN_FETCH_TIME = 24 * TIME_HOUR;

  type KeyPair = Ed25519.KeyPair;
  stable var keyPairs : Map.Map<Text, KeyPair> = Map.new();

  stable var stats = Stats.new(1000);
  Stats.log(stats, "deploied new backend version. " # Info.cycleBalance(0));

  var googleKeys : [RSA.PubKey] = [];

  public query func transform(raw : Http.TransformArgs) : async Http.CanisterHttpResponsePayload {
    return {
      status = raw.response.status;
      body = raw.response.body;
      headers = [];
    };
  };

  var lastFetch : Time.Time = 0;
  public shared ({ caller }) func fetchGoogleKeys() : async Result.Result<{ keys : [RSA.PubKey]; cost : Nat; expectedCost : Nat }, Text> {
    if (not Principal.isController(caller)) {
      if (Time.now() - lastFetch < MIN_FETCH_TIME) return #err("Rate limit reached. Try again in some hours.");
    };
    let start = Info.cycleBalanceStart();
    lastFetch := Time.now();

    let fetched = await Http.getRequest("https://www.googleapis.com/oauth2/v3/certs", 5000, transform);

    switch (RSA.pubKeysFromJSON(fetched.data)) {
      case (#ok keys) googleKeys := keys;
      case (#err err) {
        Stats.log(stats, "google keys fetch failed: " # err # " " # Info.cycleBalance(start));
        return #err(err);
      };
    };
    Stats.log(stats, Nat.toText(googleKeys.size()) # " google keys fetched. " # Info.cycleBalance(start));
    return #ok({
      keys = googleKeys;
      cost = fetched.cost;
      expectedCost = fetched.expectedCost;
    });
  };

  // TODO: add origin to have different keys for each app
  public shared func prepareDelegation(sub : Text, origin : Text, token : Nat32) : async Result.Result<{ pubKey : [Nat8] }, Text> {
    // prevent bots and people exploring the interface from creating keys *by accident*
    if (token != 123454321) return #err("invalid token");
    let startBalance = Info.cycleBalanceStart();
    let lookupKey = origin # " " # sub;
    let pubKey = switch (Map.get(keyPairs, thash, lookupKey)) {
      case (?keyPair) {
        Stats.inc(stats, "login", origin);
        Stats.log(stats, "login from " # origin # " " # Info.cycleBalance(startBalance));
        keyPair.publicKey;
      };
      case (null) {
        Stats.inc(stats, "register", origin);
        let key = await Ed25519.generateKeyPair();
        Map.set(keyPairs, thash, lookupKey, key);
        Stats.log(stats, "register user from " # origin # " " # Info.cycleBalance(startBalance));
        key.publicKey;
      };
    };

    return #ok({
      pubKey;
    });
  };

  public shared query func getDelegations(token : Text, origin : Text, sessionKey : [Nat8], expireIn : Nat) : async Result.Result<{ auth : Delegation.AuthResponse }, Text> {
    // The log statement will only show up if this function is called as an update call
    let start = Info.cycleBalanceStart();

    // verify token
    if (googleKeys.size() == 0) return #err("Google keys not loaded");
    if (expireIn > MAX_EXPIRATION_TIME) return #err("Expiration time to long");

    let jwt = switch (Jwt.decode(token, googleKeys, Time.now())) {
      case (#err err) {
        Stats.log(stats, "getDelegations failed: invalid token from " # origin # " " # Info.cycleBalance(start));
        return #err("failed to decode token: " # err);
      };
      case (#ok data) data;
    };

    // get prepared keys
    let lookupKey = origin # " " # jwt.payload.sub;
    let keyPair = switch (Map.get(keyPairs, thash, lookupKey)) {
      case (?keys) keys;
      case (null) {
        Stats.log(stats, "getDelegations failed: no key for " # lookupKey # " " # Info.cycleBalance(start));
        return #err("Could not get key for subject " # jwt.payload.sub # ".");
      };
    };

    // sign delegation
    let authResponse = Delegation.getDelegation(sessionKey, keyPair, Time.now() + expireIn);

    Stats.log(stats, "getDelegations called as update function from " # origin # " " # Info.cycleBalance(start));

    return #ok({
      auth = authResponse;
    });
  };

  public shared query ({ caller }) func getPrincipal() : async Text {
    if (Principal.isAnonymous(caller)) return "Anonymous user (not signed in) " # Principal.toText(caller);
    return "Principal " # Principal.toText(caller);
  };

  public shared query ({ caller }) func getStats() : async [Text] {
    let appCount = Nat.toText(Stats.getSubCount(stats, "register")) # " apps connected";
    let keyCount = Nat.toText(Map.size(keyPairs)) # " keys created";

    if (not Principal.isController(caller)) return [keyCount, appCount];
    let balanceText = Info.cycleBalance(0);
    let counter = Stats.counterEntries(stats);
    let counterText = Array.map<Stats.CounterEntry, Text>(counter, func(c) = c.category # " " # c.sub # ": " # Nat.toText(c.counter));

    let log = Iter.toArray(Stats.logEntries(stats));
    return Array.flatten<Text>([[keyCount, appCount, balanceText], counterText, log]);
  };

};
