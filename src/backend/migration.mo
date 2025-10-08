import Whitelist "Whitelist";
import Identify "Identify";
import Map "mo:core/Map";
import List "mo:core/List";
import Principal "mo:core/Principal";
import Text "mo:core/Text";
import CanisterSignature "CanisterSignature";
import AuthProvider "AuthProvider";
import User "User";
import Stats "Stats";
import RSA "RSA";

/// This module contains migrations from older version
module {
  type Map<K, V> = Map.Map<K, V>;
  type List<T> = List.List<T>;

  /// Type of previous version
  public type OldAuthParams = {
    /// OpenID Connect params
    #jwt : {
      clientId : Text;
      keysUrl : Text;
      preFetch : Bool;
      authority : Text;
      authorizationUrl : Text;
      fedCMConfigUrl : ?Text;
      responseType : Text;
      scope : Text;
      redirectUri : Text;
      clientSecret : ?Text;
      tokenUrl : ?Text;
    };
    /// PKCE params
    #pkce : {
      clientId : Text;
      authorizationUrl : Text;
      tokenUrl : Text;
      userInfoEndpoint : Text;
      redirectUri : Text;
      clientSecret : ?Text;
      scope : Text;
    };
  };

  /// Type of previous version
  public type OldOAuth2Config = {
    provider : AuthProvider.ProviderKey;
    name : Text;
    auth : OldAuthParams;
    var keys : [RSA.PubKey];
    var fetchAttempts : Stats.AttemptTracker;
  };

  /// Type of previous version
  type OldState = {
    var whitelist : Whitelist.Whitelist;
    identify : {
      codeHash : Map<[Nat8], Identify.CodeHash>;
      owner : Principal;
      providers : List<OldOAuth2Config>;
      sigStore : CanisterSignature.SignatureStore;
      signIns : Map<[Nat8], AuthProvider.SignInInfo>;
      users : Map<Principal, User.User>;
    };
  };

  /// Type of current version
  type NewState = {
    whitelist : Whitelist.Whitelist;
    identify : Identify.Identify;
  };

  /// Sample migratipon function
  public func migrate(old : OldState) : NewState {
    return {
      whitelist = old.whitelist;
      identify = {
        providers = old.identify.providers;
        owner = old.identify.owner;
        sigStore = old.identify.sigStore;
        signIns = old.identify.signIns;
        users = old.identify.users;
        codeHash = old.identify.codeHash;
      };
    };
  };

};
