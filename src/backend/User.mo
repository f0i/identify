import AuthProvider "AuthProvider";
import Time "mo:core/Time";
import { trap } "mo:core/Runtime";
import JWT "JWT";

module {

  type Provider = AuthProvider.Provider;
  type Time = Time.Time;
  type JWT = JWT.JWT;

  public type User = {
    provider : Provider;
    email : ?Text;
    email_verified : ?Bool;
    sub : Text;
    origin : Text;
    createdAt : Time;
  };

  public func create(origin : Text, provider : Provider, jwt : JWT) : User {
    let payload = jwt.payload;
    return {
      provider;
      email = payload.email;
      email_verified = payload.email_verified;
      sub = payload.sub;
      origin;
      createdAt = Time.now();
    };
  };

  public func update(user : User, origin : Text, provider : Provider, jwt : JWT) : User {
    let payload = jwt.payload;

    // verify that it is the same user
    if (user.provider != provider) trap("Provider does not match: " # AuthProvider.providerName(user.provider) # " != " # AuthProvider.providerName(provider));
    if (user.origin != origin) trap("User origin does not match: " # user.origin # " != " # origin);
    if (user.sub != payload.sub) trap("User subject does not match: " # user.sub # " != " # payload.sub);

    return {
      provider;
      email = payload.email;
      email_verified = payload.email_verified;
      sub = user.sub;
      origin;
      createdAt = user.createdAt;
    };
  };

};
