import { JSON } "mo:serde";
import Http "Http";
import Text "mo:core/Text";
import Nat "mo:core/Nat";
import Debug "mo:core/Debug";
import Result "mo:core/Result";
import Runtime "mo:core/Runtime";
import Iter "mo:core/Iter";
import AuthProvider "AuthProvider";
import UrlKit "mo:url-kit";

module PKCE {

  // Define a generic type for the PKCE config, as we don't have the real type from AuthProvider.

  // Define a type for the transform function
  type TransformFn = Http.TransformFn;
  type OAuth2ConnectConfig = AuthProvider.OAuth2ConnectConfig;

  public type Bearer = {
    token_type : Text;
    expires_in : Nat; // in seconds;
    access_token : Text;
    scope : Text;
  };

  // Function to exchange the authorization code for an access token
  public func exchangeToken(
    config : OAuth2ConnectConfig,
    code : Text,
    verifier : Text,
    transform : TransformFn,
  ) : async Result.Result<Bearer, Text> {

    let #pkce(pkceParams) = config.auth else return #err(config.name # " does not support PKCE.");

    let body : Text = [
      ("grant_type", "authorization_code"),
      ("code", code),
      ("redirect_uri", pkceParams.redirectUri),
      ("client_id", pkceParams.clientId),
      ("code_verifier", verifier),
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

    let response = await Http.postRequest(pkceParams.tokenUrl, ?body, headers, 3000, transform);

    // Parse JSON response and extract the access_token
    let tokenJSON = response.data;
    let tokenBlob = switch (JSON.fromText(tokenJSON, null)) {
      case (#ok data) data;
      case (#err err) return #err("could not decode token: " # err # " >" # tokenJSON # "<");
    };
    let ?token : ?Bearer = from_candid (tokenBlob) else return #err("missing field in token. " # tokenJSON);
    return #ok(token);
  };

  // Function to get user info using the access token
  public func getUserInfo(
    config : OAuth2ConnectConfig,
    token : Bearer,
    transform : TransformFn,
  ) : async Result.Result<Text, Text> {

    let #pkce(pkceParams) = config.auth else return #err(config.name # " does not support PKCE.");

    let response = await Http.getRequest(
      pkceParams.userInfoEndpoint,
      [{ name = "Authorization"; value = "Bearer " # token.access_token }],
      3000,
      transform,
      false, // TODO!
    );

    // TODO: Parse JSON response and extract the user's sub (id)
    // For now, we just return the body as text.
    return #ok(response.data);
  };
};

