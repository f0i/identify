import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Time "mo:base/Time";
import Jwt "JWT";
import RSA "RSA";

actor Main {
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
      }
    ]
  }";

  public shared ({ caller }) func login(token : Text) : async Result.Result<Jwt.JWT, Text> {
    if (Principal.isAnonymous(caller)) {
      return #err("Caller must not be anonymous");
    };

    // verify token
    let #ok(keys) = RSA.pubKeysFromJSON(googleKeys) else return #err("failed to parse keys");

    let _jwt = switch (Jwt.decode(token, keys, Time.now())) {
      case (#err err) return #err("failed to decode token: " # err);
      case (#ok data) data;
    };

    // sign delegation
    //TODO: implement

    return #err("not implemented")

  };

};
