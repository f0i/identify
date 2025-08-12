import { print } "mo:core/Debug";
import { trap } "mo:core/Runtime";
import Jwt "../src/backend/JWT";
import RSA "../src/backend/RSA";

let testJWT1 = "eyJhbGciOiJSUzI1NiIsImtpZCI6IjVhYWZmNDdjMjFkMDZlMjY2Y2NlMzk1YjIxNDVjN2M2ZDQ3MzBlYTUiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FjY291bnRzLmdvb2dsZS5jb20iLCJhenAiOiIzNzY2NTA1NzExMjctdnBvdGtyNGt0N2Q3Nm84bWtpMDlmN2Eydm9wYXRkcDYuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJhdWQiOiIzNzY2NTA1NzExMjctdnBvdGtyNGt0N2Q3Nm84bWtpMDlmN2Eydm9wYXRkcDYuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJzdWIiOiIxMTQ4MDgxMjIyNDk0OTIxNTI3ODQiLCJlbWFpbCI6ImYwaWRlc2lyZUBnb29nbGVtYWlsLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjp0cnVlLCJuYmYiOjE3MjcxNzMzNjgsIm5hbWUiOiJNYXJ0aW4gUy4iLCJwaWN0dXJlIjoiaHR0cHM6Ly9saDMuZ29vZ2xldXNlcmNvbnRlbnQuY29tL2EvQUNnOG9jSmRXWU1SRGFuU0NxdlpmdDlpQ0lhNHYydEdlX241SmFGNm03WU9vRDZZdV9wS1N3UlBzZz1zOTYtYyIsImdpdmVuX25hbWUiOiJNYXJ0aW4iLCJmYW1pbHlfbmFtZSI6IlMuIiwiaWF0IjoxNzI3MTczNjY4LCJleHAiOjE3MjcxNzcyNjgsImp0aSI6IjBhZGU5YWZlOGFlMTk5ZTMyYzQxZGJiMTBlODU5NDllZDUxN2Y1YmIifQ.Gq3-E3VuSCBMWrUEpAwWSuL7rx7b-mjHIy31TJLpyKqcPr5_NLXd-Z5Vp7OVW4Dq-XzlTfid6RVoHcx2Rbko0S1qqlWKy3D6o7xL_XJs2GXDFWnFdQSGwRO20drFzEX3C44UKAv6SaSrcKZuCiHJkNYfS90FBrbBImwM3DS3X7nOMQf-IKMvZ6GemW9huciECApbDhqB7N1C1He9R8NNK7BIUIqV0EBnGhvCouRvrjyLRjuclSnUSOQw7Bchp_Iwp6Ld0YWTwoUmiD9aji4sdn_BHRtITyz_e27BPbECcD6DXR1WMRDJPGmzkjCoFB5w7rRYKcQiXavksl-FpkCAaA";

let testJWT2 = "eyJhbGciOiJSUzI1NiIsImtpZCI6IjVhYWZmNDdjMjFkMDZlMjY2Y2NlMzk1YjIxNDVjN2M2ZDQ3MzBlYTUiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2FjY291bnRzLmdvb2dsZS5jb20iLCJhenAiOiIzNzY2NTA1NzExMjctdnBvdGtyNGt0N2Q3Nm84bWtpMDlmN2Eydm9wYXRkcDYuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJhdWQiOiIzNzY2NTA1NzExMjctdnBvdGtyNGt0N2Q3Nm84bWtpMDlmN2Eydm9wYXRkcDYuYXBwcy5nb29nbGV1c2VyY29udGVudC5jb20iLCJzdWIiOiIxMTQ4MDgxMjIyNDk0OTIxNTI3ODQiLCJlbWFpbCI6ImYwaWRlc2lyZUBnb29nbGVtYWlsLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjp0cnVlLCJuYmYiOjE3Mjc1MjUwMTIsIm5hbWUiOiJNYXJ0aW4gUy4iLCJwaWN0dXJlIjoiaHR0cHM6Ly9saDMuZ29vZ2xldXNlcmNvbnRlbnQuY29tL2EvQUNnOG9jSmRXWU1SRGFuU0NxdlpmdDlpQ0lhNHYydEdlX241SmFGNm03WU9vRDZZdV9wS1N3UlBzZz1zOTYtYyIsImdpdmVuX25hbWUiOiJNYXJ0aW4iLCJmYW1pbHlfbmFtZSI6IlMuIiwiaWF0IjoxNzI3NTI1MzEyLCJleHAiOjE3Mjc1Mjg5MTIsImp0aSI6IjMzYjBlOWRmZDQ2ZjQ2NjU2ZDRlNTRlNTc3YTUzOTI0NzRkMDI1ZDgifQ.dgzTfojxrYISFqU9wQ4-HrBZw7iwycneRKQ9bGLNDjcP-R1gooYrbpldZj5JeLeTnFgDCLncsnTc0TqlURoim56OxFDYsugVce5WZi3OUogzqf_TTEoiMWNaDeTKJIM_QIgkPWT7ZQ8DCyPrfEZqqAIj0BlTLjOn9Z-sVY7vIJA3V17er2vH9crBjIVA_Wj_mLqrwG5aMFna9MycaqIkq1dWlaAnCK_OqXDA_C5JE7A4S6ICDuOYf8Aa-YtoQjBBEoBRBq--_73ALs_BiqL0GI1eojwbYcvTSFaEOhkKhZSnItqiYVcwLGnOad03YwgHegQgKfFsSFHNuSplpZi6MA";

// from https://www.googleapis.com/oauth2/v3/certs
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

let auth0Keys = "{\"keys\":[{\"kty\":\"RSA\",\"use\":\"sig\",\"n\":\"j-WWrCZHYDyTCkgU3ghimk1DcX2OtWOofvJmX7AspN47rsoOi1WRYjM3dsHpT5TqyoqQMkz2SP2FGijXd_ofPKzegtJ14u2sOP310Z5F0qQCE-IIIqZ9ITjLR_j8L804CNqymu6TKqFOH2DJ0mz2bycBGqYLHc3KMhvlTtoWTmR-bq1YSxYOqj4oVLIs_F-TPtKlZIlvvJ7Z89M3FHtMJ89Na1NeBuqsxkuEdMoKFSBEhLzXZfZWG-SMb2l1iRNn6JXu2sB2lM0b6AqwsBwqo8gFgvSDYswVYPq_4o05FOLrCW1KCmtxcCfecL5y2CSdMGsT38R0F0AuEDftQ8EGfQ\",\"e\":\"AQAB\",\"kid\":\"gz6HIyC_kKuw487sW8Lf2\",\"x5t\":\"yHtrDsR18xL2Df72jr9SCIwYWyE\",\"x5c\":[\"MIIDBTCCAe2gAwIBAgIJEbaTy1bNW+ZZMA0GCSqGSIb3DQEBCwUAMCAxHjAcBgNVBAMTFWlkZW50aWZ5LnVrLmF1dGgwLmNvbTAeFw0yNTA3MDQwOTUxMjBaFw0zOTAzMTMwOTUxMjBaMCAxHjAcBgNVBAMTFWlkZW50aWZ5LnVrLmF1dGgwLmNvbTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAI/llqwmR2A8kwpIFN4IYppNQ3F9jrVjqH7yZl+wLKTeO67KDotVkWIzN3bB6U+U6sqKkDJM9kj9hRoo13f6Hzys3oLSdeLtrDj99dGeRdKkAhPiCCKmfSE4y0f4/C/NOAjasprukyqhTh9gydJs9m8nARqmCx3NyjIb5U7aFk5kfm6tWEsWDqo+KFSyLPxfkz7SpWSJb7ye2fPTNxR7TCfPTWtTXgbqrMZLhHTKChUgRIS812X2VhvkjG9pdYkTZ+iV7trAdpTNG+gKsLAcKqPIBYL0g2LMFWD6v+KNORTi6wltSgprcXAn3nC+ctgknTBrE9/EdBdALhA37UPBBn0CAwEAAaNCMEAwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUk7fXMm6PKm6dl9rvPnWzDlhjdMEwDgYDVR0PAQH/BAQDAgKEMA0GCSqGSIb3DQEBCwUAA4IBAQCEkMt9IZ8vBbiguX6lIl+F2aSz3dxRjDq83X+1CqCuCWJApOL7uCFQiXlLArIrE2pB/A4KEYGBgqBmEoYHBKSmgSIA308b2oBkSr0P0lD6WR3bDDKxzqi9zwUOXZfLyVynZBqDwE6V0psBTPqGD9HyubKZFUFWwKpzwNxtC6ReJZORFlsCtIoAFB03ffwxJsLP2Ok9pm4PZMrC4chR/8vunSyZkHWElH6IAa//PMKsJv9LMuWTDPar+b0JWkBvj/6UbtSmdrRnd1LxnwgoDMsTJvx9jN2VGf1TsFv/EESIM3uInNAZ2Wsz89uxn5wYa9DGWSy3OPxXg+QtI0Ods7fo\"],\"alg\":\"RS256\"},{\"kty\":\"RSA\",\"use\":\"sig\",\"n\":\"ui_oI_9HPVVjzQzg5y_hWkkIIOaCYxKo2hL4MU8WqwFkhNVtYhYP8_EBsfGhtpNYwaS3nOEFWOLnOthVSq77SVClGjKlB4Ch7mTgOjE4ecbk9_We5dBeHLzkfyZoEtzsSl7jQTyQ8SZSbvKeY191_9V82l4pk6jF2zVpClMvNDV3HOw9KpyLMMPAGGSOFF20-jLBkMAHyDCxLkf1_Vx9Tix9m2e9GSDC3s6o9u5dGtIvJoZEVu4Fo6iXWyJu2M_DoAhEDwQIUny6bYupHBKKLuL-vyYcKQhMJwq5TyJCCg2WnV3WoQ8upke873sekPS7kGyNeysGH7D4J6zK_R0LvQ\",\"e\":\"AQAB\",\"kid\":\"IwbhY2DjCyS8AgY-gF_od\",\"x5t\":\"axNEGF7rhqIeBaMJLEHzfJPf4gs\",\"x5c\":[\"MIIDBTCCAe2gAwIBAgIJfJmMvuoveYQOMA0GCSqGSIb3DQEBCwUAMCAxHjAcBgNVBAMTFWlkZW50aWZ5LnVrLmF1dGgwLmNvbTAeFw0yNTA3MDQwOTUxMjBaFw0zOTAzMTMwOTUxMjBaMCAxHjAcBgNVBAMTFWlkZW50aWZ5LnVrLmF1dGgwLmNvbTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALov6CP/Rz1VY80M4Ocv4VpJCCDmgmMSqNoS+DFPFqsBZITVbWIWD/PxAbHxobaTWMGkt5zhBVji5zrYVUqu+0lQpRoypQeAoe5k4DoxOHnG5Pf1nuXQXhy85H8maBLc7Epe40E8kPEmUm7ynmNfdf/VfNpeKZOoxds1aQpTLzQ1dxzsPSqcizDDwBhkjhRdtPoywZDAB8gwsS5H9f1cfU4sfZtnvRkgwt7OqPbuXRrSLyaGRFbuBaOol1sibtjPw6AIRA8ECFJ8um2LqRwSii7i/r8mHCkITCcKuU8iQgoNlp1d1qEPLqZHvO97HpD0u5BsjXsrBh+w+Cesyv0dC70CAwEAAaNCMEAwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQU5Jc2SU4dxFi1dprCLIXhXHFtH4gwDgYDVR0PAQH/BAQDAgKEMA0GCSqGSIb3DQEBCwUAA4IBAQCKI3Q3N7RB6i0fp57yBGQY5Uapf23s80vJGnUphRAry1xV6jBW/4TLkNGAEzAFzXHYbsQNIbDF4UYXMPtNPi5/YUlvqUuIKk5x+D8jUhzK+nMJgEsi1qkSseu+5bGd7ef9QqzLb6T7BjQzMeKThPbpxABa2azOF5dFgPM28SgdypZfeEVujNtqNydzg8+yYOg6jqLahSHQgvsXLOYjl872FIZCWR76IEXR43ucLeRqguTxiRSydB+ev8N4NAYgXXGanJX90AW2Nwjm/XJthm+kgocIPmhEHdnUc92z57MczDBn7ZbBtpMgnfW7aZzPr96wNkDKhjcrwsx53MaOLYab\"],\"alg\":\"RS256\"}]}";

let clientId = "376650571127-vpotkr4kt7d76o8mki09f7a2vopatdp6.apps.googleusercontent.com";

print("# JWT test");
print("- parse RSA keys");

let keys = switch (RSA.pubKeysFromJSON(googleKeys)) {
  case (#err err) trap("failed to parse keys: " # err);
  case (#ok data) data;
};

let nowNanos1 = 1727177187123456789;
//   iat token1 1727173668
//   exp token1 1727177268

let nowNanos2 = 1727527187123456789;
//   iat token2 1727525312
//   exp token2 1727528912

let keysAuth0 = switch (RSA.pubKeysFromJSON(auth0Keys)) {
  case (#err err) trap("failed to parse keys: " # err);
  case (#ok data) data;
};

print("- token 1");
let data1 = switch (Jwt.decode(testJWT1, keys, nowNanos1, #seconds(10), [clientId], null)) {
  case (#err err) trap("failed to decode jwt 1: " # err);
  case (#ok data) data;
};
assert data1.payload.name == ?"Martin S.";

print("- token 2");
let data2 = switch (Jwt.decode(testJWT2, keys, nowNanos2, #seconds(10), [clientId], null)) {
  case (#err err) trap("failed to decode jwt 2: " # err);
  case (#ok data) data;
};
assert data2.payload.name == ?"Martin S.";

assert data1 != data2;
