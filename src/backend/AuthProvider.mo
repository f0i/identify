import Http "Http";
import RSA "RSA";
import Stats "Stats";
import Time "mo:new-base/Time";
import Result "mo:new-base/Result";
import Text "mo:new-base/Text";
import Option "mo:new-base/Option";
import Debug "mo:base/Debug";
import Jwt "JWT";

module {
  type Result<T> = Result.Result<T, Text>;

  public type Provider = {
    #google;
    #zitadel;
    #auth0;
    #github;
    #x;
  };

  public func providerName(provider : Provider) : Text {
    switch (provider) {
      case (#google) "Google";
      case (#zitadel) "Zitadel";
      case (#auth0) "Auth0";
      case (#github) "GitHub";
      case (#x) "X";
    };
  };

  public type OAuth2ConnectConfig = {
    provider : Provider;
    clientId : Text;
    keysUrl : Text;
    var keys : [RSA.PubKey];
  };

  type Transform = shared query Http.TransformArgs -> async Http.TransformResult;

  public func fetchKeys(config : OAuth2ConnectConfig, attempts : Stats.AttemptTracker, transform : Transform) : async Result<[RSA.PubKey]> {
    attempts.count += 1;
    attempts.lastAttempt := Time.now();

    Debug.print("fetching keys from " # config.keysUrl);
    let fetched = await Http.getRequest(config.keysUrl, 5000, transform);

    switch (RSA.pubKeysFromJSON(fetched.data)) {
      case (#ok keys) config.keys := keys;
      case (#err err) {
        Debug.print("Failed to fetch " # providerName(config.provider) # " public keys: " # err);
        return #err("Failed to fetch " # providerName(config.provider) # " public keys: " # err);
      };
    };

    attempts.count := 0;
    attempts.lastSuccess := Time.now();
    Debug.print("Successfuly fetched " # providerName(config.provider) # " public keys");
    return #ok(config.keys);
  };

  type Identifier = {
    servie : Text;
    id : Text;
    email : ?Text;
    email_verified : Bool;
  };

  public func getIdentifier(provider : Provider, jwt : Jwt.JWT) : Result<Identifier> {
    switch (provider) {
      case (#google) {
        return #ok({
          servie = "google";
          id = jwt.payload.sub;
          email = jwt.payload.email;
          email_verified = Option.get(jwt.payload.email_verified, false);
        });
      };
      case (#zitadel) {
        if (jwt.payload.amr == ?["pwd"]) {
          return #ok({
            servie = "zitadel";
            id = jwt.payload.sub;
            email = jwt.payload.email; // TODO: check if email address is available
            email_verified = Option.get(jwt.payload.email_verified, false);
          });
        } else {
          return #err("Unsupported authentication method in zitadel: " # (debug_show jwt.payload.amr));
        };
      };
      case (#auth0) {
        let sub = jwt.payload.sub;
        let subParts = Text.split(sub, #char('|'));
        let ?auth = subParts.next() else return #err("Invalid Id token: missing dat in subject field " # sub);
        let ?userId = subParts.next() else return #err("Invalid Id token: missing user id in subject field " # sub);
        let null = subParts.next() else return #err("Invalid ID token: excess data in subject field " # sub);

        if (auth == "github" or auth == "google-oauth2") {
          return #ok({
            servie = auth;
            id = userId;
            email = jwt.payload.email;
            email_verified = Option.get(jwt.payload.email_verified, false);
          });
        } else {
          return #err("Unsupported sub format in auth0: " # jwt.payload.sub);
        };
      };
      case (_) #err("Identifier not implemented for provider " # providerName(provider));
    };
  };

  public func getVerifiedEmail(provider : Provider, jwt : Jwt.JWT) : ?Text {
    let #ok(data) = getIdentifier(provider, jwt) else return null;
    if (not data.email_verified) return null;
    return data.email;
  }

};
