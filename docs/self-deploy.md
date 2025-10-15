
# Self-Deploy Identify

There are three main ways to deploy and use the Identify canister.

1.  **Deploy the pre-built wasm:** The easiest way to get started. Deploy the wasm and configure providers on-the-fly.
2.  **Build from source:** For full control, clone the repository, configure your providers in the source code, and deploy.
3.  **Use as a Mops library:** The most flexible option. Integrate the Identify logic directly into your own backend canister.

---

## Option 1: Deploy the Pre-built Release

This method allows you to deploy the latest version of Identify without needing to build it yourself. The release contains pre-built files that are ready to deploy.

### 1. Download and Extract the Release

Download the latest release zip file from the [Identify releases](https://github.com/f0i/identify/releases). Extract the contents to get:
- `backend.wasm.gz` - The backend canister
- `backend.did` - The backend interface definition
- `frontend/` - The frontend assets
- `dfx.json` - Configuration file for deployment

### 2. Deploy the Backend Canister

Deploy the backend wasm to the IC. The principal you use for this command will be the initial controller.

```bash
dfx canister create --ic backend
dfx canister install --ic backend --wasm backend.wasm.gz
```

Note the backend canister ID from the output (e.g., `xxxxx-xxxxx-xxxxx-xxxxx-cai`).

### 3. Update the Backend Canister ID

The frontend contains a hardcoded reference to the default backend canister ID (`fhzgg-waaaa-aaaah-aqzvq-cai`). Replace this with your newly deployed backend canister ID in the frontend's `app.js` file:

```bash
# Replace YOUR_BACKEND_CANISTER_ID with your actual backend canister ID
sed -i 's/fhzgg-waaaa-aaaah-aqzvq-cai/YOUR_BACKEND_CANISTER_ID/g' frontend/app.js
```

For example, if your backend canister ID is `abc12-34567-89xyz-pqrst-cai`:

```bash
sed -i 's/fhzgg-waaaa-aaaah-aqzvq-cai/abc12-34567-89xyz-pqrst-cai/g' frontend/app.js
```

### 4. Deploy with dfx

Deploy using dfx:

```bash
dfx deploy --ic
```

### 5. Configure Providers

After deployment, you need to add your desired OAuth providers. You can do this by calling the `addProvider` function on the canister. This must be done with the same principal that deployed the canister.

Here is an example of how to add a generic OAuth 2.0 provider using `dfx`.

```bash
dfx canister call --ic backend addProvider '(
  "MyOIDCProvider",
  variant {
    jwt = record {
      clientId = "your-client-id";
      authorizationUrl = "https://oidc.example.com/authorize";
      tokenUrl = null;
      redirectUri = "https://<your-identify-instance-url>/oidc-callback.html";
      scope = "openid email profile";
      preFetch = true;
      authority = "https://oidc.example.com/";
      fedCMConfigUrl = null;
      keysUrl = "https://oidc.example.com/.well-known/jwks.json";
      responseType = "id_token";
      clientSecret = null;
    }
  }
)'
```

Replace the placeholder values with your actual provider details and your canister ID.

**Quick Reference:** See [configure-provider.sh](../configure-provider.sh) for example configurations of tested providers.

See [Configure Custom Provider](./configure-provider.md) for detailed configuration options, or check provider-specific guides:
- [Google](./configure-google.md)
- [GitHub](./configure-github.md)
- [LinkedIn](./configure-linkedin.md)
- [X](./configure-x.md)

---

## Option 2: Build from Source

This approach is best if you want to manage the provider configuration directly in the source code.

### 1. Clone the Repository

```bash
git clone https://github.com/f0i/identify
cd identify
```

Delete `canister_ids.json`. When you deploy, dfx will create a new one for you with your canister IDs.

### 2. Configure Providers (optional)

Open `src/backend/main.mo` and add your provider configurations at the end of the actor class (before the closing `};`).

```motoko
// src/backend/main.mo

// ... (at the end of the actor class)

  type OAuth2Config = AuthProvider.OAuth2Config;
  transient let googleConfig : OAuth2Config = {
    name = "Google";
    provider = "google";
    auth = #jwt({
      clientId = "376650571127-vpotkr4kt7d76o8mki09f7a2vopatdp6.apps.googleusercontent.com";
      keysUrl = "https://www.googleapis.com/oauth2/v3/certs";
      preFetch = true;
      authority = "https://accounts.google.com/";
      authorizationUrl = "https://accounts.google.com/o/oauth2/v2/auth";
      fedCMConfigUrl = ?"https://accounts.google.com/gsi/fedcm.json";
      responseType = "id_token";
      scope = "openid email profile";
      redirectUri = "https://login.f0i.de/oidc-callback.html";
      clientSecret = null;
      tokenUrl = null;
    });
    var keys : [RSA.PubKey] = [];
    var fetchAttempts = Stats.newAttemptTracker();
  };
  Identify.addProvider(identify, googleConfig, owner);

// ...
```

### 3. Deploy

Deploy the canister to the IC.

```bash
dfx deploy --ic
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

#### 2.1. Initialization

First, initialize the Identify library within your actor class.

```motoko
import Identify "mo:identify/Identify";
import Delegation "mo:identify/Delegation";
import AuthProvider "mo:identify/AuthProvider";
import Http "mo:identify/Http";
import RSA "mo:identify/RSA";
import Stats "mo:identify/Stats";
import Principal "mo:core/Principal";
import Time "mo:core/Time";
import Result "mo:core/Result";
import { setTimer; recurringTimer } = "mo:core/Timer";

shared ({ caller = initializer }) persistent actor class MyActor() = this {
  let owner = initializer;
  let backend = Principal.fromActor(this);
  let identify = Identify.init(backend, owner);

  type Time = Time.Time;
  type ProviderKey = AuthProvider.ProviderKey;

  // ...
```

#### 2.2 Expose Public Methods

You need to expose the core Identify functions for delegation preparation and retrieval. You also need to expose the `transform` functions required for making HTTP outcalls.

```motoko
  // ...

  public shared func prepareDelegation(
    provider : ProviderKey,
    token : Text,
    origin : Text,
    sessionKey : [Nat8],
    expireIn : Nat,
    targets : ?[Principal],
  ) : async Identify.PrepRes {
    return await* Identify.prepareDelegation(identify, provider, token, origin, sessionKey, expireIn, targets, transformKeys);
  };

  public shared func prepareDelegationPKCE(
    provider : ProviderKey,
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
    provider : ProviderKey,
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

#### 2.3 Add Providers and Fetch Keys

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

## See Also

- [Custom Domain Setup](./custom-domain.md): Configure a custom domain for your instance.
- [Configure Providers](./configure-provider.md): Learn how to configure OAuth providers.
- [Use with @dfinity/auth-client](./use-with-auth-client.md): Integrate Identify into your app.
