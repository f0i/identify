import Map "mo:core/Map";
import Principal "mo:core/Principal";
import User "User";

module {
  type Map<K, V> = Map.Map<K, V>;
  type AppInfo = { name : Text; origins : [Text] };

  public type Whitelist = {
    apps : Map<Principal, AppInfo>;
  };

  public func empty() : Whitelist {
    return { apps = Map.empty() };
  };

  public func addApp(whitelist : Whitelist, name : Text, canister : Principal, origins : [Text]) : () {
    Map.add(whitelist.apps, Principal.compare, canister, { name; origins });
  };

  public func isWhitelisted(whitelist : Whitelist, caller : Principal, appOrigin : Text, userOrigin : Text) : Bool {
    let ?appInfo = Map.get(whitelist.apps, Principal.compare, caller) else return false;
    // caller is whitelisted, now check origin
    var appOriginFound = false;
    var userOriginFound = false;

    for (o in appInfo.origins.vals()) {
      if (o == appOrigin) {
        appOriginFound := true;
      };
      if (o == userOrigin) {
        userOriginFound := true;
      };
    };
    return appOriginFound and userOriginFound;
  };
};
