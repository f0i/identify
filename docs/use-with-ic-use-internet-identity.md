
# ic-use-internet-identity

For react applications, you can use the `ic-use-internet-identity` package, which provides a convenient hook and context provider for integrating IC authentication providers like Internet Identity and Identify.

To use this package with Identify, you can follow the instructions from official repository with one addition: you need to pass the `identityProvider` option to the `loginOptions` prop of the `InternetIdentityProvider` component.

```jsx
<InternetIdentityProvider loginOptions={{ identityProvider: "https://login.f0i.de" }} >
  <App />
</InternetIdentityProvider>
```

## Quick start

Here is a quick guide to get you started.
See the [full documentation](https://github.com/kristoferlund/ic-use-internet-identity?tab=readme-ov-file#2-connect-the-login-function-to-a-button) for more details.

### Install dependencies

```bash
pnpm install ic-use-internet-identity
pnpm install @dfinity/agent @dfinity/auth-client @dfinity/identity @dfinity/candid
```

### Usage

To use `ic-use-internet-identity` in your React application, follow these steps:

### Setup the `InternetIdentityProvider` component

Wrap your application's root component with `InternetIdentityProvider` to provide all child components access to the identity context.

```jsx
// main.tsx

import { InternetIdentityProvider } from "ic-use-internet-identity";
import React from "react";
import ReactDOM from "react-dom/client";

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <InternetIdentityProvider loginOptions={{ identityProvider: "https://login.f0i.de" }} >
      <App />
    </InternetIdentityProvider>
  </React.StrictMode>
);
```

### Create a login button

You can use the `useInternetIdentity` hook to access the login function and the current authentication status and conditionally render the login button and status messages.

```jsx
// LoginButton.tsx

import { useInternetIdentity } from "ic-use-internet-identity";

export function LoginButton() {
  const { login, status, error, isError, identity } = useInternetIdentity();

  const renderButton = () => {
    switch (status) {
      case "initializing":
        return (<button disabled>⏳ Initializing...</button>);
      case "idle":
        return (<button onClick={login}>Login with Internet Identity </button>);
      case "logging-in":
        return (<button disabled>🔄 Logging in...</button>);
      case "success":
        return (<button disabled>✅ Logged in</button>);
      case "error":
        return (<button onClick={login}> 🔄 Retry Login </button>);
      default:
        return null;
    }
  };

  return (
    <div>
      {renderButton()}
      {isError && (
        <div style={{ color: "red", marginTop: "8px" }}>
          ❌ Login failed: {error?.message}
        </div>
      )}
    </div>
  );
}
```

### Use the identity to make authenticated calls

Now you can use the `identity` from the `useInternetIdentity` hook to create authenticated actors for making calls to your canisters.

```jsx
// Actors.tsx

import { ReactNode } from "react";
import {
  ActorProvider,
  createActorContext,
  createUseActorHook,
} from "ic-use-actor";
import {
  canisterId,
  idlFactory,
} from "path-to/your-service/index";
import { _SERVICE } from "path-to/your-service.did";
import { useInternetIdentity } from "ic-use-internet-identity";

const actorContext = createActorContext<_SERVICE>();
export const useActor = createUseActorHook<_SERVICE>(actorContext);

 export default function Actors({ children }: { children: ReactNode }) {
  const { identity } = useInternetIdentity();

  return (
    <ActorProvider<_SERVICE>
      canisterId={canisterId}
      context={actorContext}
      identity={identity}
      idlFactory={idlFactory}
    >
      {children}
    </ActorProvider>
  );
}
```

## Resources

- [GitHub repo](https://github.com/kristoferlund/ic-use-internet-identity)
