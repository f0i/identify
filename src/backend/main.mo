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

actor Main {
  let MAX_EXPIRATION_TIME = 31 * 24 * 60 * 60 * 1_000_000_000;
  let MAX_INSTRUCTIONS : Float = 20_000_000_000;

  type KeyPair = Ed25519.KeyPair;
  stable var keyPairs : Map.Map<Text, KeyPair> = Map.new();
  let db = {
    set = func(k : Text, v : Ed25519.KeyPair) = Map.set(keyPairs, thash, k, v);
    get = func(k : Text) : ?Ed25519.KeyPair {
      let keyPair = Map.get(keyPairs, thash, k);
      switch (keyPair) {
        case (?ks) lastKey := ks;
        case (_) {};
      };
      keyPair;
    };
  };

  // TODO: remove old keys / implement update function that fetches https://www.googleapis.com/oauth2/v3/certs
  let googleKeys = "{
    \"keys\": [
    {
      \"kty\": \"RSA\",
        \"e\": \"AQAB\",
        \"alg\": \"RS256\",
        \"n\": \"jPxgqe78Uy8UI0nrbys8zFQnskdLnvY9DFAKbI9Or7sPc7vhyQ-ynHWXrvrv3J3EVqcqwZSTAjiKbSbIhKRF2iXyIP5jmhS6QTUQb7D8smC89yZi6Ii-AzpH6QKvmhU7yJ1u0odMM1UDUS5bH5aL50HxxqqaQGlZ7PFOT0xrauAFW-3ONVc7_tXGMbfYRzeRrXqaONJ1B9LOconUlsBsL0U1TepINyztbwjM3NBlvEuBX0m4ZbCFznGoWmnix3FuUS4gAybOO3WYr6Zd71cKBFPfdpMMfNjWM2pf1-1O1IF8iArGbvngn8Vk5QGH3MkJDA_JgZOu9pI64LSIEKG02w\",
        \"use\": \"sig\",
        \"kid\": \"5aaff47c21d06e266cce395b2145c7c6d4730ea5\"
    },
    {
      \"n\": \"1BqxSPBr-Fap-E39TLXfuDg0Bfg05zYqhvVvEVhfPXRkPj7M8uK_1MOb-11XKaZ4IkWMJIwRJlT7DvDqpktDLxvTkL5Z5CLkX63TzDMK1LL2AK36sSqPthy1FTDNmDMry867pfjy_tktKjsI_lC40IKZwmVXEqGS2vl7c8URQVgbpXwRDKSr_WKIR7IIB-FMNaNWC3ugWYkLW-37zcqwd0uDrDQSJ9oPX0HkPKq99Imjhsot4x5i6rtLSQgSD7Q3lq1kvcEu6i4KhG4pA0yRZQmGCr4pzi7udG7eKTMYyJiq5HoFA446fdk6v0mWs9C7Cl3R_G45S_dH0M8dxR_zPQ\",
      \"e\": \"AQAB\",
      \"alg\": \"RS256\",
      \"kid\": \"28a421cafbe3dd889271df900f4bbf16db5c24d4\",
      \"use\": \"sig\",
      \"kty\": \"RSA\"
    },
    {
      \"kid\": \"b2620d5e7f132b52afe8875cdf3776c064249d04\",
      \"kty\": \"RSA\",
      \"e\": \"AQAB\",
      \"n\": \"pi22xDdK2fz5gclIbDIGghLDYiRO56eW2GUcboeVlhbAuhuT5mlEYIevkxdPOg5n6qICePZiQSxkwcYMIZyLkZhSJ2d2M6Szx2gDtnAmee6o_tWdroKu0DjqwG8pZU693oLaIjLku3IK20lTs6-2TeH-pUYMjEqiFMhn-hb7wnvH_FuPTjgz9i0rEdw_Hf3Wk6CMypaUHi31y6twrMWq1jEbdQNl50EwH-RQmQ9bs3Wm9V9t-2-_Jzg3AT0Ny4zEDU7WXgN2DevM8_FVje4IgztNy29XUkeUctHsr-431_Iu23JIy6U4Kxn36X3RlVUKEkOMpkDD3kd81JPW4Ger_w\",
      \"use\": \"sig\",
      \"alg\": \"RS256\"
    },
    {
      \"n\": \"1BqxSPBr-Fap-E39TLXfuDg0Bfg05zYqhvVvEVhfPXRkPj7M8uK_1MOb-11XKaZ4IkWMJIwRJlT7DvDqpktDLxvTkL5Z5CLkX63TzDMK1LL2AK36sSqPthy1FTDNmDMry867pfjy_tktKjsI_lC40IKZwmVXEqGS2vl7c8URQVgbpXwRDKSr_WKIR7IIB-FMNaNWC3ugWYkLW-37zcqwd0uDrDQSJ9oPX0HkPKq99Imjhsot4x5i6rtLSQgSD7Q3lq1kvcEu6i4KhG4pA0yRZQmGCr4pzi7udG7eKTMYyJiq5HoFA446fdk6v0mWs9C7Cl3R_G45S_dH0M8dxR_zPQ\",
      \"use\": \"sig\",
      \"e\": \"AQAB\",
      \"kid\": \"28a421cafbe3dd889271df900f4bbf16db5c24d4\",
      \"alg\": \"RS256\",
      \"kty\": \"RSA\"
    },
    {
      \"e\": \"AQAB\",
      \"n\": \"4VI56fF0rcWHHVgHFLHrmEO5w8oN9gbSQ9TEQnlIKRg0zCtl2dLKtt0hC6WMrTA9cF7fnK4CLNkfV_Mytk-rydu2qRV_kah62v9uZmpbS5dcz5OMXmPuQdV8fDVIvscDK5dzkwD3_XJ2mzupvQN2reiYgce6-is23vwOyuT-n4vlxSqR7dWdssK5sj9mhPBEIlfbuKNykX5W6Rgu-DyuoKRc_aukWnLxWN-yoroP2IHYdCQm7Ol08vAXmrwMyDfvsmqdXUEx4om1UZ5WLf-JNaZp4lXhgF7Cur5066213jwpp4f_D3MyR-oa43fSa91gqp2berUgUyOWdYSIshABVQ\",
      \"alg\": \"RS256\",
      \"kty\": \"RSA\",
      \"use\": \"sig\",
      \"kid\": \"a50f6e70ef4b548a5fd9142eecd1fb8f54dce9ee\"
    }
    ]
  }";

  stable var lastKey : Ed25519.KeyPair = { publicKey = []; secretKey = [] };
  stable var lastSession : [Nat8] = [];
  stable var lastExpiration : Int = 0;

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

  //TODO: add query keyword
  public shared func getDelegations(token : Text, sessionKey : [Nat8], expireIn : Nat) : async Result.Result<{ auth : Delegation.AuthResponse; perf0 : Nat64; perf1 : Nat64; usage : Float; cost : Float }, Text> {
    lastSession := sessionKey;
    lastExpiration := Time.now() + expireIn;
    // verify token
    let #ok(keys) = RSA.pubKeysFromJSON(googleKeys) else return #err("failed to parse keys");
    if (expireIn > MAX_EXPIRATION_TIME) return #err("exporation time to long");

    let jwt = switch (Jwt.decode(token, keys, Time.now())) {
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

  public shared query ({ caller }) func debugger() : async Text {
    // TODO!: never expose secret keys!
    debug_show { caller; lastSession; lastKey; lastExpiration };
  };
};
