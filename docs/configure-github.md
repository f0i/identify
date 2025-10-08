# Configure GitHub Sign-In

GitHub authentication uses the PKCE (Proof Key for Code Exchange) flow with OAuth 2.0.

## 1. Create a GitHub OAuth App

In [GitHub Developer Settings](https://github.com/settings/developers):

1. Go to **OAuth Apps** > **New OAuth App**
2. Set **Application name** to your app name
3. Set **Homepage URL**: `https://your-domain.com`
4. Set **Authorization callback URL**: `https://your-domain.com/pkce-callback.html`
5. Click **Register application**
6. Note your **Client ID** and generate a **Client Secret**

## 2. Configure the Provider

```bash
dfx canister call --ic backend addProvider '(
  "GitHub",
  variant {
    pkce = record {
      userInfoEndpoint = "https://api.github.com/user";
      clientId = "YOUR_GITHUB_CLIENT_ID";
      authorizationUrl = "https://github.com/login/oauth/authorize";
      tokenUrl = "https://github.com/login/oauth/access_token";
      redirectUri = "https://your-domain.com/pkce-callback.html";
      clientSecret = opt "YOUR_GITHUB_CLIENT_SECRET";
      scope = "read:user user:email";
    }
  },
)'
```

Replace `YOUR_GITHUB_CLIENT_ID`, `YOUR_GITHUB_CLIENT_SECRET`, and `your-domain.com` with your values.

## Security Considerations

**Trust Assumptions:**

- **Non-replicable HTTP outcalls**: Token exchange and user info requests can only be performed by a single node, as GitHub rejects duplicate requests. A malicious node could manipulate results.
- **Client secret storage**: The client secret is stored in the backend canister and could be extracted, allowing impersonation of your Identify instance.

**You must trust that there are no malicious node providers in the subnet.**

See [CONSIDERATIONS.md](../CONSIDERATIONS.md) for detailed security implications.

## References

- [GitHub OAuth Apps](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps)
