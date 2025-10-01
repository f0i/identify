
# Self-Deploy Identify

There are three main ways to deploy and use the Identify canister.

1.  **Deploy the pre-built wasm:** The easiest way to get started. Deploy the wasm and configure providers on-the-fly.
2.  **Build from source:** For full control, clone the repository, configure your providers in the source code, and deploy.
3.  **Use as a Mops library:** The most flexible option. Integrate the Identify logic directly into your own backend canister.

---

## Option 1: Deploy the Pre-built Wasm

This method allows you to deploy the latest version of Identify without needing to build it yourself. You can then add your own OAuth providers by calling a canister function.

### 1. Download the Wasm

Download the latest `backend.wasm.gz` file from the [Identify releases](https://github.com/f0i/ic-gsi/releases).

### 2. Deploy the Canister

Deploy the wasm to the IC. The principal you use for this command will be the initial controller.

```bash
dfx canister create backend
dfx canister install backend --wasm backend.wasm.gz
```

### 3. Configure Providers

After deployment, you need to add your desired OAuth providers. You can do this by calling the `addProvider` function on the canister. This must be done with the same principal that deployed the canister.

Here is an example of how to add a generic OAuth 2.0 provider using `dfx`.

```bash
dfx canister call backend addProvider '(
  "MyOIDCProvider",
  record {
    auth = variant {
      jwt = record {
        clientId = "your-client-id";
        keysUrl = "https://oidc.example.com/.well-known/jwks.json";
        preFetch = true;
        authority = "https://oidc.example.com/";
        redirectUri = "https://<your-identify-instance-url>/callback.html";
        fedCMConfigUrl = null;
        responseType = "code id_token";
        scope = opt "openid email profile";
      }
    }
  }
)'
```

Replace the placeholder values with your actual provider details and your canister ID.

---

## Option 2: Build from Source

This approach is best if you want to manage the provider configuration directly in the source code.

### 1. Clone the Repository

```bash
git clone https://github.com/f0i/ic-gsi.git
cd ic-gsi
```

### 2. Configure Providers

Open `src/backend/main.mo` and modify the provider configurations. You can add, remove, or edit the `OAuth2Config` blocks.

```motoko
// src/backend/main.mo

// ...

  transient let myCustomProvider : OAuth2Config = {
    name = "MyProvider";
    provider = #generic("MyProvider");
    auth = #pkce({
      authorizationUrl = "https://example.com/oauth/authorize";
      tokenUrl = "https://example.com/oauth/token";
      userInfoEndpoint = "https://api.example.com/user";
      clientId = "your-client-id";
      redirectUri = "https://<your-identify-instance-url>/pkce-callback.html";
      clientSecret = opt "your-client-secret";
    });
    var keys : [RSA.PubKey] = [];
    var fetchAttempts = Stats.newAttemptTracker();
  };

  // Add your provider to the list
  Identify.addProvider(identify, myCustomProvider, owner);

// ...
```

### 3. Deploy

Deploy the canister to the IC.

```bash
dfx deploy backend
```

---

## Option 3: Use as a Mops Library

This is the most advanced and flexible method. It allows you to integrate Identify's core logic directly into your own backend canister.

### 1. Add the Library

Add the `identify` library to your project using Mops.

```bash
mops add identify
```

### 2. Integrate into Your Actor

Now you can import and use the `identify` library within your own actor. The following snippets are based on the implementation in `src/backend/main.mo`.

#### a. Initialization

First, initialize the Identify library within your actor class.

```motoko
import Identify "mo:identify/Identify";
import Delegation "mo:identify/Delegation";
import AuthProvider "mo:identify/AuthProvider";
import Http "mo:identify/Http";
import Principal "mo:core/Principal";
import Time "mo:core/Time";

shared ({ caller = initializer }) persistent actor class MyActor() = this {
  let owner = initializer;
  let backend = Principal.fromActor(this);
  let identify = Identify.init(backend, owner);

  // ...
```

#### b. Expose Public Methods

You need to expose the core Identify functions for delegation preparation and retrieval. You also need to expose the `transform` functions required for making HTTP outcalls.

```motoko
  // ...

  public shared func prepareDelegation(
    provider : AuthProvider.Provider,
    token : Text,
    origin : Text,
    sessionKey : [Nat8],
    expireIn : Nat,
    targets : ?[Principal],
  ) : async Identify.PrepRes {
    return await* Identify.prepareDelegation(identify, provider, token, origin, sessionKey, expireIn, targets, transformKeys);
  };

  public shared func prepareDelegationPKCE(
    provider : AuthProvider.Provider,
    code : Text,
    verifier : Text,
    origin : Text,
    sessionKey : [Nat8],
    expireIn : Nat,
    targets : ?[Principal],
  ) : async Identify.PrepRes {
    return await* Identify.prepareDelegationPKCE(identify, provider, code, verifier, origin, sessionKey, expireIn, targets, transform);
  };

  public shared query func getDelegation(
    provider : AuthProvider.Provider,
    origin : Text,
    sessionKey : [Nat8],
    expireAt : Time,
    targets : ?[Principal],
  ) : async Result.Result<{ auth : Delegation.AuthResponse }, Text> {
    return Identify.getDelegation(identify, provider, origin, sessionKey, expireAt, targets);
  };

  public query func transformKeys(raw : Http.TransformArgs) : async Http.TransformResult {
    Http.transformKeys(raw);
  };

  public query func transform(raw : Http.TransformArgs) : async Http.TransformResult {
    Http.transform(raw);
  };

  // ...
```

#### c. Add Providers and Fetch Keys

You can add providers programmatically and set up timers to periodically fetch the latest OAuth keys.

```motoko
  // ...

  // Add a provider configuration
  let googleConfig : AuthProvider.OAuth2Config = {
    name = "Google";
    provider = "google";
    auth = #jwt({
      clientId = "your-google-client-id.apps.googleusercontent.com";
      keysUrl = "https://www.googleapis.com/oauth2/v3/certs";
      preFetch = true;
      authority = "https://accounts.google.com/";
      fedCMConfigUrl = null;
      responseType = "code id_token";
      scope = ?"openid email profile";
    });
    var keys : [RSA.PubKey] = [];
    var fetchAttempts = Stats.newAttemptTracker();
  };

  Identify.addProvider(identify, googleConfig, owner);


  // Pre-fetch keys to verify JWT keys.
  private func fetchAllKeys() : async () {
    ignore await* Identify.prefetchKeys(identify, transformKeys);
  };

  // Update keys now and every 2 days
  ignore setTimer<system>(#seconds(1), fetchAllKeys);
  ignore recurringTimer<system>(#hours(48), fetchAllKeys);

};
```
