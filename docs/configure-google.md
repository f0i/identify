# Configure Google Sign-In

Google authentication uses the implicit OIDC flow with JWT tokens.

## 1. Create a Google OAuth Client ID

In the [Google Cloud Console](https://console.cloud.google.com/):

1. Go to **APIs & Services** > **Credentials**
2. Click **Create Credentials** > **OAuth client ID**
3. Select **Web application**
4. Add authorized JavaScript origins: `https://your-domain.com`
5. Add authorized redirect URIs: `https://your-domain.com/oidc-callback.html`
6. Note your **Client ID**

## 2. Configure the Provider

Add the Google provider to your deployed Identify canister using the `addProvider` function:

```bash
dfx canister call --ic backend addProvider '(
  "Google",
  variant {
    jwt = record {
      clientId = "YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com";
      authorizationUrl = "https://accounts.google.com/o/oauth2/v2/auth";
      tokenUrl = null;
      redirectUri = "https://your-domain.com/oidc-callback.html";
      scope = "openid email profile";
      preFetch = true;
      authority = "https://accounts.google.com/";
      fedCMConfigUrl = opt "https://accounts.google.com/gsi/fedcm.json";
      keysUrl = "https://www.googleapis.com/oauth2/v3/certs";
      responseType = "id_token";
      clientSecret = null;
    }
  },
)'
```

Replace `YOUR_GOOGLE_CLIENT_ID` and `your-domain.com` with your values.

## Key Configuration Fields

- `responseType = "id_token"` - Uses implicit flow (JWT returned directly)
- `preFetch = true` - Backend pre-fetches public keys for JWT verification
- `fedCMConfigUrl` - Enables Federated Credential Management support
- `clientSecret = null` - No client secret required

## References

- [Google OAuth 2.0](https://developers.google.com/identity/protocols/oauth2)
- [Get Google API Client ID](https://developers.google.com/identity/oauth2/web/guides/get-google-api-clientid)
