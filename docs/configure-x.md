# Configure X (Twitter) Sign-In

X (formerly Twitter) authentication uses the PKCE flow with OAuth 2.0.

## 1. Create an X App

In [X Developer Portal](https://developer.x.com/en/portal/dashboard):

1. Create a new project and app
2. Go to app settings
3. Enable **OAuth 2.0**
4. Set **Type of App**: Web App
5. Add **Callback URI**: `https://your-domain.com/pkce-callback.html`
6. Note your **Client ID**
7. Save changes

## 2. Configure the Provider

```bash
dfx canister call --ic backend addProvider '(
  "X",
  variant {
    pkce = record {
      userInfoEndpoint = "https://api.x.com/2/users/me?user.fields=created_at,description,entities,id,location,name,pinned_tweet_id,profile_image_url,protected,public_metrics,url,username,verified,withheld";
      clientId = "YOUR_X_CLIENT_ID";
      authorizationUrl = "https://x.com/i/oauth2/authorize";
      tokenUrl = "https://api.x.com/2/oauth2/token";
      redirectUri = "https://your-domain.com/pkce-callback.html";
      clientSecret = null;
      scope = "users.read tweet.read";
    }
  },
)'
```

Replace `YOUR_X_CLIENT_ID` and `your-domain.com` with your values.

## Key Configuration Details

- `clientSecret = null` - X OAuth 2.0 PKCE does not require a client secret
- **  Rate Limits**: X API has very restrictive rate limits (25 requests/day for `users/me`)
- Non-replicable HTTP outcalls (see security considerations)

## Security Considerations

- **Non-replicable HTTP outcalls**: Token exchange and user info requests can only be performed by a single node. A malicious node could manipulate results.
- **No client secret required**: Reduces attack surface compared to GitHub
- **Severe rate limiting**: Only 25 sign-ins per day due to X API restrictions

See [CONSIDERATIONS.md](../CONSIDERATIONS.md) for detailed security implications.

## References

- [X OAuth 2.0 Authorization Code Flow with PKCE](https://docs.x.com/resources/fundamentals/authentication/oauth-2-0/authorization-code)
- [X API Rate Limits](https://docs.x.com/x-api/fundamentals/rate-limits)
