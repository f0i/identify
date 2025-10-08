# Use with @dfinity/auth-client

To integrate Identify into an existing application that already uses `@dfinity/auth-client`, you only need to update the `identityProvider` URL in your `login` call.

```typescript
import { AuthClient } from "@dfinity/auth-client";

const authClient = await AuthClient.create();

await authClient.login({
  // Use the Identify service URL
  identityProvider: "https://login.f0i.de",
  onSuccess: () => console.log("Login successful!"),
  onError: (error) => console.error("Login failed:", error),
});
```

## Quick start

The `@dfinity/auth-client` is a JavaScript library that provides a seamless way to integrate authentication into your Internet Computer applications. When used with Identify, it allows your users to sign in using their Google accounts.

### Installation

First, add the `@dfinity/auth-client` package to your project:

```bash
npm install @dfinity/auth-client
```

### Integration

Integrating `auth-client` with Identify is straightforward. You need to create an `AuthClient` instance and then use its `login` method, pointing to the Identify canister URL.

#### 1. Create an AuthClient instance

```typescript
import { AuthClient } from "@dfinity/auth-client";

const authClient = await AuthClient.create();
```

#### 2. Log in

When you call the `login` method, you need to provide the `identityProvider`. For Identify, this is the URL `https://login.f0i.de`.

```typescript
await authClient.login({
  identityProvider: "https://login.f0i.de",
  onSuccess: () => {
    console.log("Login successful!");
    handleAuthenticated(authClient);
  },
  onError: (error) => {
    console.error("Login failed:", error);
  },
});
```

#### 3. Get user information

Once the user is authenticated, you can get their identity and principal.

```typescript
async function handleAuthenticated(authClient: AuthClient) {
  const identity = authClient.getIdentity();
  const principal = identity.getPrincipal();

  console.log("User principal:", principal.toText());

  // You can now use the identity to make authenticated calls to your canisters
}
```

#### 4. Log out

To log the user out, simply call the `logout` method.

```typescript
await authClient.logout();
console.log("Logged out!");
```

### Complete Example

Here is a complete example of how you might use `@dfinity/auth-client` in a simple web application.

```typescript
import { AuthClient } from "@dfinity/auth-client";

// This would typically be in your application's entry point
async function main() {
  const authClient = await AuthClient.create();

  const loginButton = document.getElementById("loginButton");
  const logoutButton = document.getElementById("logoutButton");

  if (await authClient.isAuthenticated()) {
    handleAuthenticated(authClient);
  }

  loginButton.onclick = async () => {
    await authClient.login({
      identityProvider: "https://login.f0i.de",
      onSuccess: () => handleAuthenticated(authClient),
      onError: (error) => console.error("Login failed:", error),
    });
  };

  logoutButton.onclick = async () => {
    await authClient.logout();
    // Update UI to reflect logged-out state
  };
}

async function handleAuthenticated(authClient: AuthClient) {
  const identity = authClient.getIdentity();
  const principal = identity.getPrincipal();

  console.log("User principal:", principal.toText());
  // Update UI to reflect authenticated state
  // You can now create actors and make authenticated calls
}

main();
```

## Further Reading

- [@dfinity/auth-client documentation](https://agent-js.icp.xyz/auth-client/classes/AuthClient.html): For more detailed information on the `auth-client` API.
- [Self-Deploy Identify](./self-deploy.md): If you need to deploy your own instance of Identify.
- [Use with ic-use-internet-identity](./use-with-ic-use-internet-identity.md): React hook alternative.
- [Use with IdentityKit](./use-with-identitykit.md): ICRC-25 compatible alternative.
