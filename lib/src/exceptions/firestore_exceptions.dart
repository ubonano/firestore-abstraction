/// Standardized exception for Firestore operations.
///
/// Wraps errors that occur during Firestore interactions, providing a [message],
/// an optional error [code], and the [originalError] if available.
class FirestoreFailure implements Exception {
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
  factory FirestoreFailure.notFound(String id) => FirestoreFailure('Documento no encontrado: $id', code: 'not-found');

  /// Creates a failure representing a "permission denied" error.
  factory FirestoreFailure.permissionDenied() =>
      FirestoreFailure('Permisos insuficientes para realizar la operación', code: 'permission-denied');

  /// Creates a failure representing an unknown error.
  ///
  /// [error] is the original exception that occurred.
  factory FirestoreFailure.unknown(dynamic error) =>
      FirestoreFailure('Ocurrió un error desconocido: $error', code: 'unknown', originalError: error);
}
