import Http "Http";
import RSA "RSA";
import Stats "Stats";
import Time "mo:core/Time";
import Result "mo:core/Result";
import Text "mo:core/Text";
import Option "mo:core/Option";
import Debug "mo:core/Debug";
import Error "mo:core/Error";
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
    name : Text;
    clientId : Text;
    keysUrl : Text;
    var keys : [RSA.PubKey];
    var fetchAttempts : Stats.AttemptTracker;
  };

  type Transform = shared query Http.TransformArgs -> async Http.TransformResult;

  public func fetchKeys(config : OAuth2ConnectConfig, transform : Transform) : async Result<[RSA.PubKey]> {
    let attempts = config.fetchAttempts;
    attempts.count += 1;
    attempts.lastAttempt := Time.now();

    Debug.print("fetching keys from " # config.keysUrl);
    try {
      let fetched = await Http.getRequest(config.keysUrl, 5000, transform);

      config.keys := RSA.deserializeKeys(fetched.data);

      attempts.count := 0;
      attempts.lastSuccess := Time.now();
      return #ok(config.keys);
    } catch (e) {
      return #err("Failed to fetch keys for " # config.name # ": " # Error.message(e));
    };
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
