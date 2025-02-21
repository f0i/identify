# `ICgsi`

ICgsi is an authentication provider for the Internet Computer, providing an endpoint for the standard authentication client to request Sign In with Google.

It also lets whitelisted apps look up the email address for a specific principal.

# Integration

## Managed setup

To integrate ICgsi into your own app, you just have to point the auth-client to one of the supported login urls.

- Integrate the auth-client into your app.
- Instead of "identity.ic0.app" point the auth client to one of the public instances of ICgsi (e.g. "https://login.f0i.de").

## Self deployed

Follow this steps if you want full control over the login process.

- deploy the canister on the IC
- Set up a custom domain. This should be a subdomain where you have control over the "top-level private domain", so you can create a google client id for it.
- Configure the canister to use the client ID
- Periodically update the google public keys
- Follow the same steps as for the section [Managed Setup](#Managed-Setup) to configure the auth-client

# Apps that use ICgsi

## Bitcoin Gift Cards

https://btc-gift-cards.com

## login.f0i.de

This app shows some basic statistics about how many apps are connected and how many users signed in with ICgsi.

# Development

## Contribution

You are welcome to submit any issues you have.
For PRs, please contact me in advance.

## Testing

Unfortunately the test require some differnt features that cause them to require different execution modes.
You can run all of them using the following commands.

```
mops test --mode wasi base64 jwt leb128 stats
mops test --mode interpreter delegation ed25519
```

# Roadmap / Ideas

Ideas for further work, roughly ordered by importance, starting with the most important one.

- Provide more documentation about how it works
- Create tutorial to showcase integration options
- Use timer to automatically update googlke keys
- Support other login providers (X, GitHub, Apple, Microsoft, Auth0)
- Derive mops packages for JWT, RSA, HashTree, Email validation, ULEB128, etc.
- provide dummy version for local development where email addresses can be manually set per principal.
- Make auth work with local development by falling back to self contained ED25519 signatures instead of canister signatures.
- Provide an option to integrate the sign in button directly into the app, eliminating the extra step of redirecting to the auth provider.
- Support other algorithms than just RS256 for JWT tokens
- Implement with threshold ECDSA or shreshold Schnorr signatures, just to showcase them.

