import { JSON } "mo:serde";
import Http "Http";
import Text "mo:core/Text";
import Nat "mo:core/Nat";
import Debug "mo:core/Debug";
import Result "mo:core/Result";
import Runtime "mo:core/Runtime";
import Iter "mo:core/Iter";
import Option "mo:core/Option";
import AuthProvider "AuthProvider";
import UrlKit "mo:url-kit";

module PKCE {

  // Define a generic type for the PKCE config, as we don't have the real type from AuthProvider.

  // Define a type for the transform function
  type TransformFn = Http.TransformFn;
  type OAuth2ConnectConfig = AuthProvider.OAuth2ConnectConfig;

  public type Bearer = {
    token_type : Text;
    expires_in : ?Nat; // in seconds;
    access_token : Text;
    scope : Text;
  };

  type GitHubUser = {
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

  type XUser = {
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

  // Normalized user type: prefer X.com fields; fallback to GitHub fields
  public type NormalizedUser = {
    id : Text;
    username : Text;
    name : Text;
    bio : ?Text;
    avatar_url : ?Text;
    website : ?Text;
    location : ?Text;
    created_at : ?Text;
    followers_count : ?Nat;
    following_count : ?Nat;
    tweet_count : ?Nat;
    public_repos : ?Nat;
    public_gists : ?Nat;
    verified : ?Bool;
  };

  public func optOr<T>(a : ?T, b : ?T) : ?T = if (Option.isSome(a)) { a } else {
    b;
  };

  public func normalizeXUser(user : XUser) : NormalizedUser {
    type URLObject = {
      start : Nat;
      end : Nat;
      url : Text;
      expanded_url : Text;
      display_url : Text;
    };

    type URL = {
      urls : ?[URLObject];
    };

    type Entities = {
      url : ?URL;
    };

    type PublicMetrics = {
      followers_count : Nat;
      following_count : Nat;
      tweet_count : Nat;
    };

    func firstUrl(entities : ?Entities) : ?Text {
      let ?ents = entities else return null;
      let ?url = ents.url else return null;
      let ?urls = url.urls else return null;
      if (urls == []) return null;
      return ?urls[0].expanded_url;
    };

    let followersCount : ?Nat = ?user.data.public_metrics.followers_count;
    let followingCount : ?Nat = ?user.data.public_metrics.following_count;
    let tweetCount : ?Nat = ?user.data.public_metrics.tweet_count;

    {
      id = user.data.id;
      username = user.data.username;
      name = user.data.name;
      bio = user.data.description;
      avatar_url = ?user.data.profile_image_url;
      website = optOr(user.data.url, firstUrl(user.data.entities));
      location = null;
      created_at = ?user.data.created_at;
      followers_count = followersCount;
      following_count = followingCount;
      tweet_count = tweetCount;
      public_repos = null;
      public_gists = null;
      verified = ?user.data.verified;
    };
  };

  public func normalizeGithubUser(user : GitHubUser) : NormalizedUser {
    {
      id = Nat.toText(user.id);
      username = user.login;
      name = user.name;
      bio = user.bio;
      avatar_url = ?user.avatar_url; // TODO: change to not optional?
      website = user.blog;
      location = user.location;
      created_at = ?user.created_at;
      followers_count = ?user.followers;
      following_count = ?user.following;
      tweet_count = null;
      public_repos = ?user.public_repos;
      public_gists = ?user.public_gists;
      verified = null;
    };
  };

  /// Function to exchange the authorization code for an access token
  public func exchangeToken(
    config : OAuth2ConnectConfig,
    code : Text,
    verifier : Text,
    transform : TransformFn,
  ) : async Result.Result<Bearer, Text> {

    let #pkce(pkceParams) = config.auth else return #err(config.name # " does not support PKCE.");

    var body : Text = [
      ("grant_type", "authorization_code"),
      ("code", code),
      ("redirect_uri", pkceParams.redirectUri),
      ("client_id", pkceParams.clientId),
      ("code_verifier", verifier),
      ("client_secret", Option.get(pkceParams.clientSecret, "")),
    ]
    |> Iter.map(
      _.vals(),
      func((key : Text, value : Text)) : Text = UrlKit.encodeText(key) # "=" # UrlKit.encodeText(value),
    )
    |> Text.join("&", _);

    let headers = [
      { name = "Content-Type"; value = "application/x-www-form-urlencoded" },
      { name = "Accept"; value = "application/json" },
    ];

    let response = await Http.postRequest(pkceParams.tokenUrl, ?body, headers, 9000, transform);

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
    config : OAuth2ConnectConfig,
    token : Bearer,
    transform : TransformFn,
  ) : async Result.Result<NormalizedUser, Text> {

    let #pkce(pkceParams) = config.auth else return #err(config.name # " does not support PKCE.");

    let response = await Http.getRequest(
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
      case (#x) {
        let ?xUser : ?XUser = from_candid (userBlob) else return #err("missing field in token. " # userJSON);
        return #ok(normalizeXUser(xUser));
      };
      case (#github) {
        let ?githubUser : ?GitHubUser = from_candid (userBlob) else return #err("missing field in token. " # userJSON);
        return #ok(normalizeGithubUser(githubUser));
      };
      case (_) {
        return #err("No user type defined for " # config.name);
      };
    };
  };

};

