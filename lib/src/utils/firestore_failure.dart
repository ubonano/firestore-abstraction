/// Standardized exception for Firestore operations.
///
/// Wraps errors that occur during Firestore interactions, providing a [message],
/// an optional error [code], and the [originalError] if available.
class FirestoreFailure implements Exception {
  /// Error code for document not found.
  static const String codeNotFound = 'not-found';

  /// Error code for permission denied.
  static const String codePermissionDenied = 'permission-denied';

  /// Error code for unknown error.
  static const String codeUnknown = 'unknown';

  /// Error code for document already exists.
  static const String codeAlreadyExists = 'already-exists';

  /// Error code for invalid argument.
  static const String codeInvalidArgument = 'invalid-argument';

  /// A human-readable error message.
  final String message;

  /// A specific error code for programmatic handling (e.g., 'not-found', 'permission-denied').
  final String? code;

  /// The original error object caught, if any.
  final dynamic originalError;

  /// Creates a new [FirestoreFailure].
  FirestoreFailure(this.message, {this.code, this.originalError});

  @override
  String toString() => 'FirestoreFailure(message: $message, code: $code)';

  /// Creates a failure representing a "document not found" error.
  ///
  /// [id] is the identifier of the document that was not found.
  factory FirestoreFailure.notFound(String id) => FirestoreFailure('Document not found: $id', code: codeNotFound);

  /// Creates a failure representing a "permission denied" error.
  factory FirestoreFailure.permissionDenied() =>
      FirestoreFailure('Insufficient permissions to perform the operation', code: codePermissionDenied);

  /// Creates a failure representing an unknown error.
  ///
  /// [error] is the original exception that occurred.
  factory FirestoreFailure.unknown(dynamic error) =>
      FirestoreFailure('An unknown error occurred: $error', code: codeUnknown, originalError: error);

  /// Creates a failure representing a "document already exists" error.
  factory FirestoreFailure.alreadyExists(String id) =>
      FirestoreFailure('Document already exists: $id', code: codeAlreadyExists);

  /// Creates a failure representing an "invalid argument" error.
  factory FirestoreFailure.invalidArgument(String message) => FirestoreFailure(message, code: codeInvalidArgument);
}
