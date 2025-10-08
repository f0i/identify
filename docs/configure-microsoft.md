# Configure Microsoft Sign-In

**  Status: Not fully implemented yet**

Microsoft authentication will support PKCE + JWT flow via Microsoft Entra ID (formerly Azure AD).

## Planned Configuration

Microsoft will use the OAuth 2.0 authorization code flow with PKCE, combined with JWT token validation.

## Setup Steps (Coming Soon)

1. Register an application in [Microsoft Entra admin center](https://entra.microsoft.com/)
2. Configure redirect URIs
3. Request OpenID Connect permissions
4. Add provider configuration to Identify

## References

- [Microsoft identity platform OAuth 2.0 authorization code flow](https://learn.microsoft.com/azure/active-directory/develop/v2-oauth2-auth-code-flow)
- [Microsoft Entra ID OpenID Connect](https://learn.microsoft.com/entra/identity-platform/v2-protocols-oidc)

**Note**: This provider is not yet available. Check the [README](../README.md) for implementation status updates.
