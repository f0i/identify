#!/usr/bin/env bash

set -eu -o pipefail

# Example provider configurations for tested OAuth providers
# These are examples - any OAuth 2.0/OIDC provider should work with appropriate configuration
#
# Replace placeholders with your actual values:
# - YOUR_*_CLIENT_ID: Your OAuth client ID from the provider
# - YOUR_*_CLIENT_SECRET: Your OAuth client secret (if required)
# - your-domain.com: Your Identify instance domain
#
# See docs/configure-provider.md for detailed configuration guide

echo \
 dfx canister call --ic backend addProvider \
'(
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

echo \
 dfx canister call --ic backend addProvider \
'(
  "Auth0",
  variant {
    jwt = record {
      clientId = "YOUR_AUTH0_CLIENT_ID";
      authorizationUrl = "https://YOUR_AUTH0_DOMAIN.auth0.com/oauth/authorize";
      tokenUrl = null;
      redirectUri = "https://your-domain.com/oidc-callback.html";
      scope = "openid email profile";
      preFetch = true;
      authority = "https://YOUR_AUTH0_DOMAIN.auth0.com/";
      fedCMConfigUrl = null;
      keysUrl = "https://YOUR_AUTH0_DOMAIN.auth0.com/.well-known/jwks.json";
      responseType = "id_token";
      clientSecret = null;
    }
  },
)'

echo \
dfx canister call --ic backend addProvider \
'(
  "Zitadel",
  variant {
    jwt = record {
      clientId = "YOUR_ZITADEL_CLIENT_ID";
      authorizationUrl = "https://YOUR_ZITADEL_INSTANCE.zitadel.cloud/oauth/v2/authorize";
      tokenUrl = null;
      redirectUri = "https://your-domain.com/oidc-callback.html";
      scope = "openid email profile";
      preFetch = true;
      authority = "https://YOUR_ZITADEL_INSTANCE.zitadel.cloud/";
      fedCMConfigUrl = null;
      keysUrl = "https://YOUR_ZITADEL_INSTANCE.zitadel.cloud/oauth/v2/keys";
      responseType = "id_token";
      clientSecret = null;
    }
  },
)'


echo \
dfx canister call --ic backend addProvider \
'(
  "Github",
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


echo \
dfx canister call --ic backend addProvider \
'(
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

echo \
dfx canister call --ic backend addProvider \
'(
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

echo \
dfx canister call --ic backend addProvider \
'(
  "Discord",
  variant {
    pkce = record {
      userInfoEndpoint = "https://discord.com/api/users/@me";
      clientId = "YOUR_DISCORD_CLIENT_ID";
      authorizationUrl = "https://discord.com/oauth2/authorize";
      tokenUrl = "https://discord.com/api/oauth2/token";
      redirectUri = "https://your-domain.com/pkce-callback.html";
      clientSecret = opt "YOUR_DISCORD_CLIENT_SECRET";
      scope = "identify email openid";
    }
  },
)'

echo \
dfx canister call --ic backend addProvider \
'(
  "Discord",
  variant {
    jwt = record {
      clientId = "YOUR_DISCORD_CLIENT_ID";
      authorizationUrl = "https://discord.com/oauth2/authorize";
      tokenUrl = opt "https://discord.com/api/oauth2/token";
      redirectUri = "https://your-domain.com/oidc-callback.html";
      scope = "openid email identify";
      preFetch = true;
      authority = "";
      fedCMConfigUrl = null;
      keysUrl = "https://discord.com/api/oauth2/keys";
      responseType = "code";
      clientSecret = opt "YOUR_DISCORD_CLIENT_SECRET";
    }
  },
)'

