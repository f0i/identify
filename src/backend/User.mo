import Time "mo:core/Time";
import { trap } "mo:core/Runtime";
import JWT "JWT";
import PKCE "PKCE";
import Nat "mo:core/Nat";
import Option "mo:core/Option";
import AuthProvider "AuthProvider";

module {

  type ProviderKey = AuthProvider.ProviderKey;
  type Time = Time.Time;
  type JWT = JWT.JWT;

  public type User = {
    provider : ProviderKey;
    id : Text;
    username : ?Text;

    email : ?Text;
    email_verified : ?Bool;
    origin : Text;
    createdAt : Time;

    name : ?Text;
    bio : ?Text;
    avatar_url : ?Text;
    website : ?Text;
    location : ?Text;
    provider_created_at : ?Text;
    followers_count : ?Nat;
    following_count : ?Nat;
    tweet_count : ?Nat;
    public_repos : ?Nat;
    public_gists : ?Nat;
    verified : ?Bool;
  };

  public func fromJWT(origin : Text, provider : ProviderKey, jwt : JWT) : User {
    let payload = jwt.payload;
    return {
      provider;
      id = payload.sub;
      email = payload.email;
      email_verified = payload.email_verified;
      origin;
      createdAt = Time.now();
      name = payload.name;
      username = if (payload.email_verified == ?true) payload.email else null;
      avatar_url = payload.picture;
      // Not available in JWT payload
      bio = null;
      website = null;
      location = null;
      provider_created_at = null;
      followers_count = null;
      following_count = null;
      tweet_count = null;
      public_repos = null;
      public_gists = null;
      verified = null;
    };
  };

  public func fromPKCE(origin : Text, provider : ProviderKey, user : PKCE.PKCEUser) : User {
    switch (user) {
      case (#x(xUser)) fromXUser(origin, provider, xUser);
      case (#github(githubUser)) fromGithubUser(origin, provider, githubUser);
    };
  };

  public func fromXUser(origin : Text, provider : ProviderKey, user : PKCE.XUser) : User {
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

    return {
      provider;
      id = user.data.id;
      // X does not provide email
      email = null;
      email_verified = null;
      origin;
      createdAt = Time.now();
      username = ?user.data.username;
      name = ?user.data.name;
      bio = user.data.description;
      avatar_url = ?user.data.profile_image_url;
      website = optOr(user.data.url, firstUrl(user.data.entities));
      location = null;
      provider_created_at = ?user.data.created_at;
      followers_count = followersCount;
      following_count = followingCount;
      tweet_count = tweetCount;
      public_repos = null;
      public_gists = null;
      verified = ?user.data.verified;
    };
  };

  public func fromGithubUser(origin : Text, provider : ProviderKey, user : PKCE.GitHubUser) : User {
    return {
      provider;
      id = Nat.toText(user.id);
      email = user.email;
      // GitHub does not provide email_verified status
      email_verified = null;
      origin;
      createdAt = Time.now();
      username = ?user.login;
      name = ?user.name;
      bio = user.bio;
      avatar_url = ?user.avatar_url;
      website = user.blog;
      location = user.location;
      provider_created_at = ?user.created_at;
      followers_count = ?user.followers;
      following_count = ?user.following;
      tweet_count = null;
      public_repos = ?user.public_repos;
      public_gists = ?user.public_gists;
      verified = null;
    };
  };

  public func update(existing_user : User, origin : Text, provider : ProviderKey, new_user_data : User) : User {
    // verify that it is the same user
    if (existing_user.provider != provider) trap("Provider does not match: " # AuthProvider.providerName(existing_user.provider) # " != " # AuthProvider.providerName(provider));
    if (existing_user.origin != origin) trap("User origin does not match: " # existing_user.origin # " != " # origin);
    if (existing_user.id != new_user_data.id) trap("User ID does not match: " # existing_user.id # " != " # new_user_data.id); // Changed from sub to id

    return {
      provider;
      id = existing_user.id; // Keep existing ID
      email = new_user_data.email; // Update email
      email_verified = new_user_data.email_verified; // Update email_verified
      origin;
      createdAt = existing_user.createdAt; // Keep existing createdAt
      username = new_user_data.username;
      name = new_user_data.name;
      bio = new_user_data.bio;
      avatar_url = new_user_data.avatar_url;
      website = new_user_data.website;
      location = new_user_data.location;
      provider_created_at = new_user_data.provider_created_at;
      followers_count = new_user_data.followers_count;
      following_count = new_user_data.following_count;
      tweet_count = new_user_data.tweet_count;
      public_repos = new_user_data.public_repos;
      public_gists = new_user_data.public_gists;
      verified = new_user_data.verified;
    };
  };

  public func optOr<T>(a : ?T, b : ?T) : ?T {
    if (Option.isSome(a)) {
      return a;
    } else {
      return b;
    };
  };

};
