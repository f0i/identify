# Configure Apple Sign-In

**⚠️ Status: Not fully implemented yet**

Apple Sign-In will support PKCE + JWT flow via Sign in with Apple.

## Planned Configuration

Apple will use OAuth 2.0 authorization code flow with PKCE, combined with JWT token validation using Apple's public keys.

## Setup Steps (Coming Soon)

1. Register an App ID in [Apple Developer Portal](https://developer.apple.com/account/)
2. Configure Sign in with Apple capability
3. Create a Services ID for web authentication
4. Configure return URLs
5. Add provider configuration to Identify

## References

- [Sign in with Apple Documentation](https://developer.apple.com/documentation/sign_in_with_apple)
- [Configuring Your Webpage for Sign in with Apple](https://developer.apple.com/documentation/sign_in_with_apple/sign_in_with_apple_js/configuring_your_webpage_for_sign_in_with_apple)

**Note**: This provider is not yet available. Check the [README](../README.md) for implementation status updates.
