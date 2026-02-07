class FirestoreFailure implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  FirestoreFailure(this.message, {this.code, this.originalError});

  @override
  String toString() => 'FirestoreFailure(message: $message, code: $code)';

  factory FirestoreFailure.notFound(String id) => FirestoreFailure('Documento no encontrado: $id', code: 'not-found');

  factory FirestoreFailure.permissionDenied() =>
      FirestoreFailure('Permisos insuficientes para realizar la operación', code: 'permission-denied');

  factory FirestoreFailure.unknown(dynamic error) =>
      FirestoreFailure('Ocurrió un error desconocido: $error', code: 'unknown', originalError: error);
}
