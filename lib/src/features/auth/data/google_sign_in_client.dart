import 'package:google_sign_in/google_sign_in.dart';

/// The Google credentials Supabase's signInWithIdToken needs. A plain value
/// object so no google_sign_in type crosses into the repository's logic and
/// tests need no platform channels.
final class GoogleCredentials {
  const GoogleCredentials({required this.idToken, required this.accessToken});
  final String idToken;
  final String accessToken;
}

/// Wraps the native Google account picker behind an injectable seam. Returns
/// null when the user cancels the picker (no error, no credentials); throws on
/// a genuine failure so the repository maps it to a Failure. The repository,
/// never this file's callers, owns the Either mapping.
abstract interface class GoogleSignInClient {
  /// Triggers the native picker and returns the signed-in account's idToken +
  /// accessToken, or null if the user cancelled.
  Future<GoogleCredentials?> signIn();
}

/// google_sign_in v7 implementation. Not unit-tested: it only touches platform
/// channels (the singleton GoogleSignIn.instance). v7 separates authentication
/// (idToken) from authorization (accessToken), so this performs both steps.
final class PackageGoogleSignInClient implements GoogleSignInClient {
  PackageGoogleSignInClient({required String webClientId, String? iosClientId})
    : _webClientId = webClientId,
      _iosClientId = iosClientId;

  final String _webClientId;
  final String? _iosClientId;

  // Process-wide: `GoogleSignIn.instance.initialize()` is undefined behavior if
  // called more than once on the singleton, so the guard must survive any
  // re-creation of this wrapper (e.g. a provider cycle), not just one instance.
  static bool _initialized = false;

  static const _scopes = <String>['email', 'profile'];

  @override
  Future<GoogleCredentials?> signIn() async {
    final google = GoogleSignIn.instance;
    if (!_initialized) {
      // initialize() must be awaited exactly once before any other call (v7).
      await google.initialize(
        serverClientId: _webClientId,
        clientId: _iosClientId,
      );
      _initialized = true;
    }
    try {
      final GoogleSignInAccount account = await google.authenticate(
        scopeHint: _scopes,
      );
      final idToken = account.authentication.idToken;
      // v7 no longer returns an access token from authenticate(); request it
      // from the authorization client (Supabase requires it for Google).
      final authorization =
          await account.authorizationClient.authorizationForScopes(_scopes) ??
          await account.authorizationClient.authorizeScopes(_scopes);
      final accessToken = authorization.accessToken;
      if (idToken == null) {
        // A successful pick with no idToken is a misconfiguration, not a
        // cancel: surface it as a fault so it is mapped and reported.
        throw const GoogleSignInMissingTokenException();
      }
      return GoogleCredentials(idToken: idToken, accessToken: accessToken);
    } on GoogleSignInException catch (e) {
      // A user-dismissed picker is not an error: collapse it to null so the
      // repository returns Right(unit) and the screen simply stays put.
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }
}

/// Raised when the native picker returns an account with no idToken (a Google/
/// client-id misconfiguration). Carried to the repository's single boundary so
/// it is mapped to an UnexpectedFailure and crash-reported.
final class GoogleSignInMissingTokenException implements Exception {
  const GoogleSignInMissingTokenException();
}
