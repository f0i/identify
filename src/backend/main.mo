import Result "mo:base/Result";
import Time "mo:base/Time";
import Map "mo:map/Map";
import { phash } "mo:map/Map";
import Set "mo:map/Set";
import Jwt "JWT";
import RSA "RSA";
import Delegation "Delegation";
import Ed25519 "Ed25519";
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

actor class Main() = this {
  let TIME_MINUTE = 60 * 1_000_000_000;
  let TIME_HOUR = 60 * TIME_MINUTE;
  let MAX_EXPIRATION_TIME = 31 * 24 * TIME_HOUR;
  let MIN_FETCH_ATTEMPT_TIME = TIME_MINUTE * 10;
  let MIN_FETCH_TIME = 6 * TIME_HOUR;

  type HashTree = HashTree.HashTree;

  type KeyPair = Ed25519.KeyPair;
  stable var keyPairs : Map.Map<Text, KeyPair> = Map.new();
  stable var emails : Map.Map<Principal, Text> = Map.new();
  stable var trustedApps : Map.Map<Principal, Text> = Map.new();
  Map.set(trustedApps, phash, Principal.fromText("yvip2-dqaaa-aaaah-aq3qq-cai"), "btc-gift-cards.com");

  stable var stats = Stats.new(1000);
  Stats.log(stats, "deploied new backend version.");

  var googleKeys : [RSA.PubKey] = [];
  var googleClientIds : [Text] = ["376650571127-vpotkr4kt7d76o8mki09f7a2vopatdp6.apps.googleusercontent.com"];

  let initKeys = "
{
  \"keys\": [
    {
      \"e\": \"AQAB\",
      \"kty\": \"RSA\",
      \"n\": \"5D9Xb4z8eFr-3Zh3m5GnM_KVqc6rskPL7EMa6lSxNiMJ-PhXGORU-S-QgLmMvHu3vAMfvxz6ph3JZDpdGT68wj-vWqqBudaDYCbnbkjXm6UpcrFMpGAiOS6gACNxpz80JXaO2DPtl9jTN6WyJY9tLHdqRfesfOlwzB0lmVZ8shSDh8usN3vB1KfYuR6Vytly1phaWJr92yMICKUjtXT-0SlrtqDgX_U2Swl4QyZN6rrfuG3F6Fmw-m12Ve_kyoPUb02bbJCSFDnIZsMvRlSZem5nUrs86zDPTWfNcB0LUYG8OgMzOev7r04h_RY2F6K7c8nE2EobYTrH0kw2QIf8vQ\",
      \"use\": \"sig\",
      \"alg\": \"RS256\",
      \"kid\": \"eec534fa5b8caca201ca8d0ff96b54c562210d1e\"
    },
    {
      \"n\": \"uac7NRcojCutcceWq1nrpLGJjQ7ywvgWsUcb1DWMKJ3KNNHiRzh9jshoi9tmq1zlarJ_h7GQg8iU1qD7SgpVYJmjlKG1MNVRAtuNrNMC0UAnNfG7mBBNorHFndfp-9cLTiMjXSXRzhNqiMvTVKeolRdMB2lH9RzJnwlpXtvUbD7M1pXOlPlMaOy1zxUnHn0uszU5mPRQk79i03BNrAdhwrAUB-ZuMnqpjaUcb9VU3KIwuZNPtsVenLN12sRYpaZ6WBw8Q9q7fAoaJUovM0Go8deC9pJYyxJuHdVo9HP0osyzg3g_rOYi14wmvMBuiDf3F4pTnudAfFyl3d0Mn_i4ZQ\",
      \"use\": \"sig\",
      \"kty\": \"RSA\",
      \"alg\": \"RS256\",
      \"kid\": \"5d12ab782cb6096285f69e48aea99079bb59cb86\",
      \"e\": \"AQAB\"
    }
  ]
}
  ";
  switch (RSA.pubKeysFromJSON(initKeys)) {
    case (#ok keys) googleKeys := keys;
    case (#err err) {
      Stats.log(stats, "initial set google keys failed: " # err);
    };
  };

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

  type PrepRes = Result.Result<{ pubKey : [Nat8]; register : Bool }, Text>;

  var sigTree : HashTree = #Empty;
  public shared func prepareDelegation(token : Text, origin : Text, sessionKey : [Nat8], expireIn : Nat) : async PrepRes {
    Stats.logBalance(stats, "prepareDelegationSig");

    // verify token
    if (googleKeys.size() == 0) return #err("Google keys not loaded");
    if (expireIn > MAX_EXPIRATION_TIME) return #err("Expiration time to long");

    // Time of JWT token from google must not be more than 5 minutes in the future
    let jwt = switch (Jwt.decode(token, googleKeys, Time.now(), 5 * 60 /*seconds*/, googleClientIds)) {
      case (#err err) {
        Stats.log(stats, "getDelegations failed: invalid token from " # origin);
        return #err("failed to decode token: " # err);
      };
      case (#ok data) data;
    };

    let sub = jwt.payload.sub;
    let seed = HashTree.encodeSeed(origin, sub);
    let signingCanisterID = Principal.fromActor(this);
    let pubKey = CanisterSignature.DERencodePubKey(signingCanisterID, seed);

    let hash = Delegation.getUnsignedHash(sessionKey, Time.now() + expireIn);
    sigTree := HashTree.addSig(#Empty, seed, hash, Time.now());
    //TODO: sigTree := HashTree.addSig(sigTree, seed, hash, Time.now());
    CertifiedData.set(Blob.fromArray(HashTree.hash(sigTree)));

    let principal = CanisterSignature.toPrincipal(signingCanisterID, seed);
    let rawEmail = jwt.payload.email;
    let normalized = Email.normalizeEmail(rawEmail);
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
      pubKey;
      register = true;
    });
  };

  public shared query func getDelegation(token : Text, origin : Text, sessionKey : [Nat8], expireIn : Nat) : async Result.Result<{ auth : Delegation.AuthResponse; emailSet : Bool }, Text> {
    // The log statements will only show up if this function is called as an update call
    Stats.logBalance(stats, "getDelegations");

    // If called as an update call, the getCertificate function returns null
    let ?cert = CertifiedData.getCertificate() else return #err("Certificate only available in query calls");

    // verify token
    if (googleKeys.size() == 0) return #err("Google keys not loaded");
    if (expireIn > MAX_EXPIRATION_TIME) return #err("Expiration time to long");

    // Time of JWT token from google must not be more than 5 minutes in the future
    let jwt = switch (Jwt.decode(token, googleKeys, Time.now(), 5 * 60 /*seconds*/, googleClientIds)) {
      case (#err err) {
        Stats.log(stats, "getDelegations failed: invalid token from " # origin);
        return #err("failed to decode token: " # err);
      };
      case (#ok data) data;
    };

    let signingCanisterID = Principal.fromActor(this);
    let sub = jwt.payload.sub;
    let seed = HashTree.encodeSeed(origin, sub);
    let pubKey = CanisterSignature.DERencodePubKey(signingCanisterID, seed);

    //sign delegation
    let signature = HashTree.getSignature(sigTree, seed, cert);
    let authResponse = Delegation.getDelegationExternalSig(sessionKey, pubKey, signature, Time.now() + expireIn);
    let emailSet = Map.has(emails, phash, CanisterSignature.toPrincipal(signingCanisterID, seed));

    if (not emailSet) return #err("Email not set");

    return #ok({
      auth = authResponse;
      emailSet;
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
