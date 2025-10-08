# Configure a Custom Domain

A custom domain is required for OAuth provider configuration and improves user trust.

## Overview

Setting up a custom domain requires:
1. Configuring DNS records
2. Adding domain to canister's `.well-known/ic-domains` file
3. Registering domain with IC boundary nodes
4. Updating OAuth provider redirect URIs

## Quick Setup

### 1. Configure DNS Records

Get your canister ID: `dfx canister id backend --ic`

Add these DNS records (replace `login.your-domain.com` and `abc123-cai` with your values):

```
Type: CNAME
Name: login
Value: login.your-domain.com.icp1.io

Type: TXT
Name: _canister-id.login
Value: abc123-cai

Type: CNAME
Name: _acme-challenge.login
Value: _acme-challenge.login.your-domain.com.icp2.io
```

### 2. Add Domain to Canister

Create `.well-known/ic-domains` file with your domain name, then deploy.

### 3. Register with Boundary Nodes

```bash
curl -sL -X POST \
  -H 'Content-Type: application/json' \
  https://icp0.io/registrations \
  --data '{"name": "login.your-domain.com"}'
```

### 4. Update OAuth Provider Settings

Use your custom domain in OAuth provider configurations:
- Redirect URIs: `https://login.your-domain.com/oidc-callback.html` or `/pkce-callback.html`

## References

- [Custom Domains on IC](https://internetcomputer.org/docs/building-apps/frontends/custom-domains/using-custom-domains)
- [DNS Configuration Guide](https://internetcomputer.org/docs/building-apps/frontends/custom-domains/dns-setup)
