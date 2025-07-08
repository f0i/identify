import Result "mo:new-base/Result";
import Http "Http";
import RSA "RSA";
import Stats "Stats";
import Time "mo:new-base/Time";

module {
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

  public func fetchKeys(config : OAuth2ConnectConfig, attempts : Stats.AttemptTracker, transform : Transform) : async Result.Result<[RSA.PubKey], Text> {
    attempts.count += 1;
    attempts.lastAttempt := Time.now();

    let fetched = await Http.getRequest(config.keysUrl, 5000, transform);

    switch (RSA.pubKeysFromJSON(fetched.data)) {
      case (#ok keys) config.keys := keys;
      case (#err err) {
        return #err("Failed to fetch " # providerName(config.provider) # " public keys: " # err);
      };
    };

    attempts.count := 0;
    attempts.lastSuccess := Time.now();
    return #ok(config.keys);
  };

};
