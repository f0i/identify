# Configure a Custom OAuth Provider

Identify supports adding custom OAuth 2.0 and OpenID Connect providers using either JWT or PKCE flows.

## Provider Types

### 1. JWT Flow (OpenID Connect)

For OIDC providers that issue JWT tokens (ID tokens):

```bash
dfx canister call --ic backend addProvider '(
  "ProviderName",
  variant {
    jwt = record {
      clientId = "your-client-id";
      authorizationUrl = "https://provider.example.com/oauth/authorize";
      tokenUrl = opt "https://provider.example.com/oauth/token";  # null for implicit flow
      redirectUri = "https://your-domain.com/oidc-callback.html";
      scope = "openid email profile";
      preFetch = true;
      authority = "https://provider.example.com/";
      fedCMConfigUrl = null;  # or opt "https://provider.example.com/.well-known/fedcm.json"
      keysUrl = "https://provider.example.com/.well-known/jwks.json";
      responseType = "id_token";  # or "code" for authorization code flow
      clientSecret = null;  # or opt "your-client-secret" if required
    }
  },
)'
```

**Key Fields:**
- `responseType = "id_token"` - Implicit flow (JWT returned directly)
- `responseType = "code"` - Authorization code flow (requires `tokenUrl` and `clientSecret`)
- `preFetch = true` - Pre-fetch JWT verification keys
- `keysUrl` - JWKS endpoint for JWT signature verification
- `authority` - Token issuer URL for validation

### 2. PKCE Flow (OAuth 2.0)

For OAuth providers without JWT support:

```bash
dfx canister call --ic backend addProvider '(
  "ProviderName",
  variant {
    pkce = record {
      userInfoEndpoint = "https://provider.example.com/api/user";
      clientId = "your-client-id";
      authorizationUrl = "https://provider.example.com/oauth/authorize";
      tokenUrl = "https://provider.example.com/oauth/token";
      redirectUri = "https://your-domain.com/pkce-callback.html";
      clientSecret = null;  # or opt "your-client-secret" if required
      scope = "user:read email";
    }
  },
)'
```

**Key Fields:**
- `userInfoEndpoint` - API endpoint to fetch user profile after authentication
- `clientSecret` - Optional, but required by some providers (e.g., GitHub)

## Choosing the Right Flow

| Provider Type | Use Flow | Advantages |
|--------------|----------|------------|
| OIDC with implicit flow | JWT (`responseType = "id_token"`) | Fastest, no backend token exchange |
| OIDC with code flow | JWT (`responseType = "code"`) | More secure, requires token exchange |
| OAuth 2.0 only | PKCE | Works with providers that don't issue JWTs |

## Security Considerations

- **JWT flow**: Tokens verified on-chain using public keys (most secure)
- **PKCE flow**: Requires HTTP outcalls that can't be replicated (trust in subnet required)
- **Client secrets**: If stored, can be extracted from canister (trust in subnet required)

See [CONSIDERATIONS.md](../CONSIDERATIONS.md) for detailed security implications.

## Provider-Specific Guides

- [Google](configure-google.md)
- [GitHub](configure-github.md)
- [X (Twitter)](configure-x.md)
- [LinkedIn](configure-linkedin.md)
- [Microsoft](configure-microsoft.md) (coming soon)
- [Apple](configure-apple.md) (coming soon)
