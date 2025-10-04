import Identify "backend/Identify";

module {
  public type OAuth2Config = Identify.OAuth2Config;
  public type FrontendOAuth2Config = Identify.FrontendOAuth2Config;
  public type PrepRes = Identify.PrepRes;
  public type CodeHash = Identify.CodeHash;
  public type Identify = Identify.Identify;

  /// Initialize a new Identify state.
  /// Parameters:
  /// - backend: The principal of the canister that will be used to sign delegations.
  /// - owner: The principal of the user that is allowed to add and update providers.
  public let init = Identify.init;

  /// Add a provider to the list of configured providers.
  /// This function can only be called by the owner (which is provided on init.)
  /// The config.provider must be unique, otherwise the previous one will be replaced
  public let addProvider = Identify.addProvider;

  /// Add a provider to the list of configured providers.
  /// If a authority is provided, the configuration will be loaded from the configuration in GET <authority>.well-known/openid-configuration.
  /// Parameters:
  /// - config: The Identify state.
  /// - provider: The provider configuration to add. If the auth field contains a authority, the configuration will be fetched from there.
  /// - caller: The principal of the caller. Must be the owner.
  public let addProviderFetch = Identify.addProviderFetch;

  /// Get the configuration of the authentication providers.
  /// This only contains the configuration values that are public and required by the front end to perform the authentication request.
  /// clientSecret, which is required by some PKCE flows is not included.
  public let getConfig = Identify.getConfig;

  /// Prefetch the keys used for signing the JWTs.
  /// Running this periodically (e.g. every day) can increase the sign in speed for some providers.
  /// Required keys will still be loaded at the time of login, if the requested key ID is not present.
  public let prefetchKeys = Identify.prefetchKeys;

  /// Connect code and session key
  /// The codeHash is a sha256 hash of the authorization code returned from the provider
  /// By committing to the code in advance, it prevents potential attackers (boundary nodes or node machines) from intercepting the code and creating a delegation for a different sessionKey.
  public let lockCodeHash = Identify.lockCodeHash;

  /// Verify the JWT token and prepare a delegation.
  /// The delegation can be fetched using an query call to getDelegation.
  public let prepareDelegation = Identify.prepareDelegation;

  /// Check PKCE sign in and prepare delegation
  ///
  /// Warning:
  /// This function uses non-replicated http-outcalls to complete the authentication flow and request user data.
  /// It therefore requires some trust in the node provider, not to manipulate the requests.
  /// If possible use `prepareDelegation` instead.
  public let prepareDelegationPKCEJWT = Identify.prepareDelegationPKCEJWT;

  /// Complete PKCE sign to get a JWT and prepare delegation.
  ///
  /// Warning:
  /// This function uses non-replicated http-outcalls to complete authentication.
  /// It therefore requires some trust in the node provider, not to manipulate the requests.
  /// If possible use `prepareDelegation` instead.
  public let prepareDelegationPKCE = Identify.prepareDelegationPKCE;

  /// Get the delegation.
  /// The delegation must be prepared using `prepareDelegation`, `prepareDelegationPKCEJWT` or `prepareDelegationPKCE`.
  /// This function must be called with a query call, to be able to read the certified data from the canister.
  public let getDelegation = Identify.getDelegation;

  /// Get user information for a specific principal
  public let getUser = Identify.getUser;

  /// Get the list of provider configurations for the frontend
  public let getProviders = Identify.getProviders;
};
