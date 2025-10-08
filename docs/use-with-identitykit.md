# Use with IdentityKit

[IdentityKit](https://identitykit.xyz) is a React library that provides a unified interface for multiple Internet Computer authentication providers, including Identify.

## Installation

```bash
npm install @nfid/identitykit
```

## Basic Setup

```typescript
import { IdentityKitProvider, IdentityKitTheme } from "@nfid/identitykit/react";

function App() {
  return (
    <IdentityKitProvider
      signers={[
        // Add Identify as a signer
        "https://login.f0i.de",  // or your custom Identify instance
      ]}
      theme={IdentityKitTheme.LIGHT}
    >
      <YourApp />
    </IdentityKitProvider>
  );
}
```

## Connect Button

```typescript
import { IdentityKitAuthType, useIdentityKit } from "@nfid/identitykit/react";

function LoginButton() {
  const { connect } = useIdentityKit();

  return (
    <button
      onClick={() =>
        connect({
          authType: IdentityKitAuthType.DELEGATION,
        })
      }
    >
      Sign In
    </button>
  );
}
```

## ICRC-25 Support

Identify implements ICRC-25 (Signer Interaction Standard), which IdentityKit uses for communication. This enables features like:
- Account management (ICRC-27)
- Delegations (ICRC-34)
- Call canister (ICRC-49)

## See Also

- [Use with @dfinity/auth-client](./use-with-auth-client.md): Vanilla JavaScript alternative.
- [Use with ic-use-internet-identity](./use-with-ic-use-internet-identity.md): React hook alternative.
- [Self-Deploy Identify](./self-deploy.md): Deploy your own instance.

## References

- [IdentityKit Documentation](https://docs.identitykit.xyz/)
- [IdentityKit GitHub](https://github.com/internet-identity-labs/identitykit)
- [ICRC-25 Standard](https://github.com/dfinity/wg-identity-authentication/blob/main/topics/icrc_25_signer_interaction_standard.md)
