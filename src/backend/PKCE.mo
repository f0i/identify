import { JSON } "mo:serde";
import Http "Http";
import Text "mo:core/Text";
import Nat "mo:core/Nat";
import Result "mo:core/Result";
import Iter "mo:core/Iter";
import Option "mo:core/Option";
import AuthProvider "AuthProvider";
import URL "URL";

module PKCE {

  // Define a generic type for the PKCE config, as we don't have the real type from AuthProvider.

  // Define a type for the transform function
  type TransformFn = Http.TransformFn;
  type OAuth2Config = AuthProvider.OAuth2Config;
  type Result<T> = Result.Result<T, Text>;

  public type Bearer = {
    token_type : Text;
    expires_in : ?Nat; // in seconds;
    access_token : Text;
    scope : Text;
  };

  public type PKCEUser = { #github : GitHubUser; #x : XUser };

  public type GitHubUser = {
    login : Text;
    id : Nat;
    node_id : Text;
    avatar_url : Text;
    gravatar_id : ?Text;
    url : Text;
    html_url : Text;
    followers_url : Text;
    following_url : Text;
    gists_url : Text;
    starred_url : Text;
    subscriptions_url : Text;
    organizations_url : Text;
    repos_url : Text;
    events_url : Text;
    received_events_url : Text;
    type_ : Text;
    site_admin : Bool;
    name : Text;
    company : ?Text;
    blog : ?Text;
    location : ?Text;
    email : ?Text;
    hireable : ?Bool;
    bio : ?Text;
    twitter_username : ?Text;
    public_repos : Nat;
    public_gists : Nat;
    followers : Nat;
    following : Nat;
    created_at : Text;
    updated_at : Text;
  };

  public type XUser = {
    data : {
      entities : ?{
        url : ?{
          urls : ?[{
            start : Nat;
            end : Nat;
            url : Text;
            expanded_url : Text;
            display_url : Text;
          }];
        };
      };
      public_metrics : {
        followers_count : Nat;
        following_count : Nat;
        tweet_count : Nat;
        listed_count : ?Nat;
        like_count : ?Nat;
        media_count : ?Nat;
      };
      description : ?Text;
      url : ?Text;
      username : Text;
      profile_image_url : Text;
      name : Text;
      id : Text; // always present
      verified : Bool;
      protected : Bool;
      created_at : Text;
    };
  };

  public func exchangeAuthorizationCode(
    config : OAuth2Config,
    code : Text,
    verifier : ?Text,
    transform : TransformFn,
  ) : async* Result<Text> {

    let bodyValues : [(Text, Text)] = switch (config.auth) {
      case (#jwt(jwtParams)) {
        [
          ("grant_type", "authorization_code"),
          ("code", code),
          ("redirect_uri", jwtParams.redirectUri),
          ("client_id", jwtParams.clientId),
          ("client_secret", Option.get(jwtParams.clientSecret, "")),
        ];
      };
      case (#pkce(pkceParams)) {
        [
          ("grant_type", "authorization_code"),
          ("code", code),
          ("redirect_uri", pkceParams.redirectUri),
          ("client_id", pkceParams.clientId),
          ("code_verifier", Option.get(verifier, "")),
          ("client_secret", Option.get(pkceParams.clientSecret, "")),
        ];
      };
    };

    let tokenUrl : Text = switch (config.auth) {
      case (#jwt(jwtParams)) {
        let ?url = jwtParams.tokenUrl else return #err("Invalid configuration: tokenUrl not defined");
        url;
      };
      case (#pkce(pkceParams)) pkceParams.tokenUrl;
    };

    let bodyIter : Iter.Iter<Text> = Iter.map(
      bodyValues.vals(),
      func((key : Text, value : Text)) : Text = URL.urlEncode(key) # "=" # URL.urlEncode(value),
    );
    let body : Text = Text.join("&", bodyIter);

    let headers = [
      { name = "Content-Type"; value = "application/x-www-form-urlencoded" },
      { name = "Accept"; value = "application/json" },
    ];

    let response = await* Http.postRequest(tokenUrl, ?body, headers, 9000, transform);

    if (response.statusCode != 200) return #err("Request failed with status code " # Nat.toText(response.statusCode) # " " # response.data);

    return #ok(response.data);
  };

  /// Function to exchange the authorization code for an bearer access token
  public func exchangeToken(
    config : OAuth2Config,
    code : Text,
    verifier : Text,
    transform : TransformFn,
  ) : async* Result.Result<Bearer, Text> {

    let #pkce(pkceParams) = config.auth else return #err(config.name # " does not support PKCE.");

    let body : Text = [
      ("grant_type", "authorization_code"),
      ("code", code),
      ("redirect_uri", pkceParams.redirectUri),
      ("client_id", pkceParams.clientId),
      ("code_verifier", verifier),
      ("client_secret", Option.get(pkceParams.clientSecret, "")),
    ]
    |> Iter.map(
      _.vals(),
      func((key : Text, value : Text)) : Text = URL.urlEncode(key) # "=" # URL.urlEncode(value),
    )
    |> Text.join("&", _);

    let headers = [
      { name = "Content-Type"; value = "application/x-www-form-urlencoded" },
      { name = "Accept"; value = "application/json" },
    ];

    let response = await* Http.postRequest(pkceParams.tokenUrl, ?body, headers, 9000, transform);

    // Parse JSON response and extract the access_token
    let tokenJSON = response.data;
    let tokenBlob = switch (JSON.fromText(tokenJSON, null)) {
      case (#ok data) data;
      case (#err err) return #err("could not decode token: " # err # " >" # tokenJSON # "<");
    };
    let ?token : ?Bearer = from_candid (tokenBlob) else return #err("missing field in token. " # tokenJSON # " " # body);
    return #ok(token);
  };

  /// Function to get user info using the access token
  public func getUserInfo(
    config : OAuth2Config,
    token : Bearer,
    transform : TransformFn,
  ) : async Result.Result<PKCEUser, Text> {

    let #pkce(pkceParams) = config.auth else return #err(config.name # " does not support PKCE.");

    let response = await* Http.getRequest(
      pkceParams.userInfoEndpoint,
      [{ name = "Authorization"; value = "Bearer " # token.access_token }],
      3000,
      transform,
      false, // TODO!
    );

    // Parse JSON response and extract the user data
    let userJSON = response.data;
    let userBlob = switch (JSON.fromText(userJSON, null)) {
      case (#ok data) data;
      case (#err err) return #err("could not decode user info: " # err # " >" # userJSON # "<");
    };

    switch (config.provider) {
      case ("x") {
        let ?xUser : ?XUser = from_candid (userBlob) else return #err("missing field in token. " # userJSON);
        return #ok(#x(xUser));
      };
      case ("github") {
        let ?githubUser : ?GitHubUser = from_candid (userBlob) else return #err("missing field in token. " # userJSON);
        return #ok(#github(githubUser));
      };
      case (_) {
        return #err("No user type defined for " # config.name);
      };
    };
  };

};
