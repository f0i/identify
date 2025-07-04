# Security Considerations

This document outlines the security considerations for the authentication flow.
If you think something is missing, incorrect or ambiguous, please don't hesitate to contact me or open an issue.

## Assumptions

- **Browser is secure**, user is not compromised, and the user is not using a malicious browser extension.
- **Connection between browser and web2 auth provider is secure.**
- **Web2 auth providers are secure** and not compromised.
- **Http gateways** can read, block or delay requests, and issue their own requests.
- **Node providers** can read state, both stored and during execution, but cannot modify it and cannot modify or interrupt execution.
- **Threshold cryptography** is secure, e.g. to sign data with canister signatures.
- **Http outclalls** cannot be modified, but the data send and received can be read by the node provider.

Or in other words, this is considered private/secure:

- Browser <-> Web2 Auth Provider
- Threshold Cryptography

... not manipulatable, but public information:

- Computation in canister
- HTTP outcalls from canister
- canister state

.. can be interrupted and public information:

- communication from and a canister

## PKCE

PKCE (Proof Key for Code Exchange) uses a code challenge and code_verifier for an interactive login flow.
It expects the code_verifier to be a random string that is kept secret on the client side

### Authentication flow option 1

One option to prevent replay attacks is to commit to a session_key and code_verifier.

- The frontend generates a session_key.
- The frontend generates a random `code_verifier` and computes `code_challange` (hash of code_verifier).
- The frontend sends both session_key and code_challange to backend.
- Backend stores the session_key and code_verifier, sends success response to frontend.
- The frontend redirects the user to the web2 auth provider with the `code_challange`.
- The user logs in with the web2 auth provider.
- The web2 auth provider redirects the user back to the frontend with a `code`.
- The frontend sends the `code`, `code_verifier`, and `session_key` to the backend.
- The backend verifies the `code_verifier` and `session_key` matches the stored values.
- The backend exchanges the `code` for an access token.
- The backend requests user information from the web2 auth provider using the access token.
- The backend creates and signs the delegation for the user.
- The backend sends the delegation to the frontend.
- User is logged in.

### Authentication flow option 2

Another option would be to use the session_key as part of the code_challange.
This way, the frontend would not need to commit the session_key and code_verifier in advance, saving some seconds in the login flow.

- The frontend generates a session_key.
- The frontend generates a `code_verifier` based on the session_key and computes `code_challange` (hash of code_verifier).
- The frontend redirects the user to the web2 auth provider with the `code_challange`.
- The user logs in with the web2 auth provider.
- The web2 auth provider redirects the user back to the frontend with a `code`.
- The frontend sends the `code` and `session_key` to the backend.
- The backend reconstructs the code_verifier from the `session_key`.
- The backend exchanges the `code` for an access token. (This will fail if the session_key produces a different code_verifier than the one used in the initial request.)
- The backend requests user information from the web2 auth provider using the access token.
- The backend creates and signs the delegation for the user.
- The backend sends the delegation to the frontend.
- User is logged in.

## JWT

Google and Auth0 provide a JWT flow that allows the frontend to get a signed JWT token without interacting with the backend.

This could still be intercepted by the attacker and used to login as the user.
Therefore, the JWT must contain a nonce that is unique for the session key of the frontend session.
Since this noce is part of the signed data inside the JWT, it cannot be modified by the attacker (unlike in the PKCE flow).

