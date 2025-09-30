# Changelog

## 0.0.1 2025-09-30

### Authentication & Identity
*   **Generic OIDC Provider:** Implemented a generic OIDC provider for easier integration with other OIDC-compliant services.
*   **Whitelist Helper:** Added a whitelist helper for managing access control.
*   **Custom Providers:** Refactored the authentication flow to prepare for custom providers.
*   **PKCE Flow:** Updated the PKCE sign-in message and fixed an error message for providers that don't support PKCE.
*   **JWT Flow:** Fixed an issue with delegation preparation in the JWT flow and implemented key fetching when a `keyId` is not found.
*   **Performance:** JWT keys are now only fetched if pre-fetch is requested.

### Core System & Performance
*   **Dependency Updates:** Updated various dependencies to their latest versions.
*   **Cleanup**: Remove unused dependencies and deprecated code, including Ed25519 Delegations.
*   **Build & Deployment:** Prepared `mops.toml` for publishing and removed benchmark tests for alternative libraries.
*   **Refactoring:** Simplified `main.mo` and refactored configuration naming.
*   **Security:** Updated the security policy.

### Documentation
*   **Documentation Structure:** Prepared the documentation structure for new content.
*   **General Updates:** Updated and refactored existing documentation.

## 2025-08-12

### Authentication & Identity
*   **Auth0 Integration (Initial Version):** Added initial support for Auth0 login, allowing users to authenticate via Auth0 and obtain Internet Computer delegations.
*   **Multi-Provider Support:** Implemented detection of login providers via URL parameters, enabling developers to choose the authentication method.
*   **Generalized Authentication Flow:** Refactored frontend authentication logic to support multiple providers (Google, Auth0) through a unified flow.

### Core System & Performance
*   **Backend Module Refactoring:** Continued adoption of core Motoko modules for improved backend structure and user data management.
*   **Toolchain Update:** Updated the mops toolchain for improved build processes.
*   **Internal Cleanups:** Various internal cleanups and dependency management improvements.

## 2025-08-02

### Authentication & Identity
*   **Enhanced Login Flows:** Prepared for integration with Auth0 and Zitadel, including custom nonce handling and patching `auth0-spa-js` for improved popup behavior.
*   **Delegation Management Refinements:** Significant refactoring of delegation management, including support for targets and improved JSON-RPC responses.
*   **Identity Manager:** Implemented a dedicated identity manager for streamlined user identity handling.
*   **Security & User Management:** Added security considerations, listed web2 login providers, and introduced features for email management and setting moderators. Improved origin detection and display during sign-in.

### Core System & Performance
*   **Module Migration:** Continued migration to core modules (e.g., `core/Map`, `User.mo`) for a more robust and organized codebase.
*   **Toolchain & Persistence Updates:** Updated the mops toolchain and transitioned to enhanced orthogonal persistence.
*   **Encoding & Hashing Improvements:** Updated ULEB encoder, refined HashTree operations, and improved the Base64 decoder to support whitespace and padding. Added performance benchmarks for Base64 encoding.
*   **Inter-Canister Communication:** Implemented ICRC-49 for direct canister calls and refactored JSON-RPC for better communication.
*   **General Refactoring & Stability:** Numerous internal refactorings, code cleanups, and improvements to error handling and status reporting for increased stability and maintainability.

### Candid Decoder
*   **UI & Functionality Updates:** Introduced and significantly updated the Candid decoder UI, including fixes for field hash handling and the use of a larger field name lookup table.
*   **Improved Decoding:** Enhanced the decoder's capabilities with more test cases and general improvements to its logic.

## Older

### Initial Setup & Foundational Components
*   **Project Initialization:** Established the project structure, including initial frontend and backend components, and set up the build process with esbuild.
*   **Project Renaming:** Renamed the project to "Identify" to better reflect its purpose.
*   **Documentation & Resources:** Added initial documentation, including an authentication sequence diagram and general resources.

### Cryptographic & Encoding Core
*   **JWT & RS256 Verification:** Implemented a robust JWT parser with RS256 verification, including key parsing from JSON and validation of `iat` and `exp` times.
*   **Delegation Signing:** Introduced the core functionality for delegation signing, including preparing delegations and functions to retrieve them from the actor.
*   **Key Generation & Encoding:** Added ED25519 key generation with DER encoding, ULEB128 encoding, and a wrapper for ED25519. Implemented a Base64 decoder with comprehensive tests.
*   **HashTree & Canister Signatures:** Developed the HashTree with CBOR encoding and began implementation of canister signatures.

### System Monitoring & Client Interaction
*   **Performance Metrics:** Integrated instruction counters and estimated cost into responses, along with a general performance counter.
*   **Client Management:** Added functions for client ID validation, allowing trusted applications to read email addresses, and managing key pairs.
*   **User Interface & Experience:** Introduced basic frontend styling, improved logging, added info pages, and displayed the app origin during sign-in.
*   **Error Handling & Utilities:** Implemented general error handling, backup functions for setting keys, and utilities for sorting keys in HTTP outcall responses.
