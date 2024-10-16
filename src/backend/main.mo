import Result "mo:base/Result";
import Time "mo:base/Time";
import Map "mo:map/Map";
import { thash } "mo:map/Map";
import Jwt "JWT";
import RSA "RSA";
import Delegation "Delegation";
import Ed25519 "Ed25519";
import IC "mo:base/ExperimentalInternetComputer";
import Float "mo:base/Float";
import Nat64 "mo:base/Nat64";
import Nat32 "mo:base/Nat32";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Http "Http";

actor Main {
  let TIME_HOUR = 60 * 60 * 1_000_000_000;
  let MAX_EXPIRATION_TIME = 31 * 24 * TIME_HOUR;
  let MAX_INSTRUCTIONS : Float = 20_000_000_000;
  let MIN_FETCH_TIME = 24 * TIME_HOUR;

  type KeyPair = Ed25519.KeyPair;
  stable var keyPairs : Map.Map<Text, KeyPair> = Map.new();
  let db = {
    set = func(k : Text, v : Ed25519.KeyPair) = Map.set(keyPairs, thash, k, v);
    get = func(k : Text) : ?Ed25519.KeyPair = Map.get(keyPairs, thash, k);
  };

  type Stat = { origin : Text; accounts : Nat };
  stable var stats : Map.Map<Text, Stat> = Map.new();

  let defaultGoogleKeys = "{
    \"keys\": [
      {
        \"kid\": \"a50f6e70ef4b548a5fd9142eecd1fb8f54dce9ee\",
        \"use\": \"sig\",
        \"n\": \"4VI56fF0rcWHHVgHFLHrmEO5w8oN9gbSQ9TEQnlIKRg0zCtl2dLKtt0hC6WMrTA9cF7fnK4CLNkfV_Mytk-rydu2qRV_kah62v9uZmpbS5dcz5OMXmPuQdV8fDVIvscDK5dzkwD3_XJ2mzupvQN2reiYgce6-is23vwOyuT-n4vlxSqR7dWdssK5sj9mhPBEIlfbuKNykX5W6Rgu-DyuoKRc_aukWnLxWN-yoroP2IHYdCQm7Ol08vAXmrwMyDfvsmqdXUEx4om1UZ5WLf-JNaZp4lXhgF7Cur5066213jwpp4f_D3MyR-oa43fSa91gqp2berUgUyOWdYSIshABVQ\",
        \"kty\": \"RSA\",
        \"e\": \"AQAB\",
        \"alg\": \"RS256\"
      },
      {
        \"e\": \"AQAB\",
        \"alg\": \"RS256\",
        \"use\": \"sig\",
        \"kid\": \"73e25f9789119c7875d58087a78ac23f5ef2eda3\",
        \"n\": \"tMXbmw7xEDVLLkAJdxpI-6pGywn0x9fHbD_mfgtFGZEs1LDjhDAJq6c-SoODeWQstjpetTgNqVCKOuU6zGyFPNtkDjhJqDW6THy06uJ8I85crILo3h-6NPclZ3bK9OzN5bIbzjbSvxrIM7ORZOlWzByOn5qGsMvI3aDrZ0lXNC1eCDWJpoJznG1fWcHYxbUy_CHDC3Cd26jX19aRALEEQU-y-wi9pv86qxEmrYMLsVN3__eWNNPkzxgf0eSOWFDv5_19YK7irYztqiwin6abxr9RHj3Qs21hpJ9A-YfsfmNkxmifgDeiTnXpZY8yfVTCJTtkgT7sjdU1lvhsMa4Z0w\",
        \"kty\": \"RSA\"
      }
    ]
  }";

  var googleKeys = switch (RSA.pubKeysFromJSON(defaultGoogleKeys)) {
    case (#ok keys) keys;
    case (#err _) [];
  };

  public query func transform(raw : Http.TransformArgs) : async Http.CanisterHttpResponsePayload {
    return {
      status = raw.response.status;
      body = raw.response.body;
      headers = [];
    };
  };

  var lastFetch : Time.Time = 0;
  public shared ({ caller }) func fetchGoogleKeys(json : ?Text) : async Result.Result<[RSA.PubKey], Text> {
    if (not Principal.isController(caller)) {
      if (Time.now() - lastFetch < MIN_FETCH_TIME) return #err("Rate limit reached. Try again in some hours.");
      // TODO?: Remove parameter json completely
      if (json != null) return #err("Permission denied. Try calling this function with parameter null to fetch from google api.");
    };

    let jsonKeys = switch (json) {
      case (?data) data;
      case (null) (await Http.getRequest("https://www.googleapis.com/oauth2/v3/certs", 5000, transform)).data;
    };

    switch (RSA.pubKeysFromJSON(jsonKeys)) {
      case (#ok keys) googleKeys := keys;
      case (#err err) return #err(err);
    };
    return #ok(googleKeys);
  };

  // TODO: add origin to have different keys for each app
  public shared func prepareDelegation(sub : Text, token : Nat32) : async Result.Result<{ pubKey : [Nat8]; perf0 : Nat64; perf1 : Nat64; usage : Float; cost : Float }, Text> {
    // prevent bots and people exploring the interface from creating keys *by accident*
    if (token != 123454321) return #err("invalid token");
    let pubKey : [Nat8] = Ed25519.getPubKey(db, sub);

    let perf1 = Float.fromInt(Nat64.toNat(IC.performanceCounter(1)));
    return #ok({
      pubKey;
      perf0 = IC.performanceCounter(0);
      perf1 = IC.performanceCounter(1);
      usage = perf1 / MAX_INSTRUCTIONS; // percentage of maximum instruction per request
      cost = perf1 * 0.000000000000536; // $ per instruction https://link.medium.com/zjNeJd73sNb
    });
  };

  public shared query func getDelegations(token : Text, sessionKey : [Nat8], expireIn : Nat) : async Result.Result<{ auth : Delegation.AuthResponse; perf0 : Nat64; perf1 : Nat64; usage : Float; cost : Float }, Text> {
    // verify token
    if (googleKeys.size() == 0) return #err("Google keys not set");
    if (expireIn > MAX_EXPIRATION_TIME) return #err("exporation time to long");

    let jwt = switch (Jwt.decode(token, googleKeys, Time.now())) {
      case (#err err) return #err("failed to decode token: " # err);
      case (#ok data) data;
    };

    // get prepared keys
    let keyPair = switch (Ed25519.getKeyPair(db, jwt.payload.sub, false)) {
      case (#ok keys) keys;
      case (#err _err) return #err("Couldn't get key for subject " # jwt.payload.sub # ". Call prepareDelegation(" # jwt.payload.sub # ") to generate one.");
    };

    // sign delegation
    let authResponse = Delegation.getDelegation(sessionKey, keyPair, Time.now() + expireIn);

    let perf1 = Float.fromInt(Nat64.toNat(IC.performanceCounter(1)));
    return #ok({
      auth = authResponse;
      perf0 = IC.performanceCounter(0);
      perf1 = IC.performanceCounter(1);
      usage = perf1 / MAX_INSTRUCTIONS; // percentage of maximum instruction per request
      cost = perf1 * 0.000000000000536; // $ per instruction https://link.medium.com/zjNeJd73sNb
    });
  };

  public shared query ({ caller }) func getPrincipal() : async Text {
    if (Principal.isAnonymous(caller)) return "Anonymous user (not signed in) " # Principal.toText(caller);
    return "Principal " # Principal.toText(caller) # " 1 of " # Nat.toText(Map.size(keyPairs));
  };

};
