# Configure LinkedIn Sign-In

LinkedIn authentication uses JWT tokens via OIDC with a code exchange flow.

## 1. Create a LinkedIn App

In [LinkedIn Developers](https://www.linkedin.com/developers/apps):

1. Click **Create app**
2. Fill in app details and create
3. Go to **Auth** tab
4. Add redirect URL: `https://your-domain.com/oidc-callback.html`
5. In **Products**, request access to **Sign In with LinkedIn using OpenID Connect**
6. Note your **Client ID** and **Client Secret** from the **Auth** tab

## 2. Configure the Provider

```bash
dfx canister call --ic backend addProvider '(
  "LinkedIn",
  variant {
    jwt = record {
      clientId = "YOUR_LINKEDIN_CLIENT_ID";
      authorizationUrl = "https://www.linkedin.com/oauth/v2/authorization";
      tokenUrl = opt "https://www.linkedin.com/oauth/v2/accessToken";
      redirectUri = "https://your-domain.com/oidc-callback.html";
      scope = "openid email profile";
      preFetch = true;
      authority = "https://www.linkedin.com/oauth/";
      fedCMConfigUrl = null;
      keysUrl = "https://www.linkedin.com/oauth/openid/jwks";
      responseType = "code";
      clientSecret = opt "YOUR_LINKEDIN_CLIENT_SECRET";
    }
  },
)'
```

Replace `YOUR_LINKEDIN_CLIENT_ID`, `YOUR_LINKEDIN_CLIENT_SECRET`, and `your-domain.com` with your values.

## Key Configuration Details

- `responseType = "code"` - Uses authorization code flow (requires token exchange)
- `tokenUrl` - Required for exchanging authorization code for JWT token
- `clientSecret` - Required for token exchange
- **JWT does not reflect nonce** - Cannot fully prevent token replay attacks

## Security Considerations

- Requires client secret stored in backend canister
- JWT tokens from LinkedIn do not include the provided nonce
- Trust in subnet node providers required

See [CONSIDERATIONS.md](../CONSIDERATIONS.md) for detailed security implications.

## References

- [Sign In with LinkedIn using OpenID Connect](https://learn.microsoft.com/en-us/linkedin/consumer/integrations/self-serve/sign-in-with-linkedin-v2)
