import 'package:cloud_firestore/cloud_firestore.dart';
import '../exceptions/firestore_exceptions.dart';

/// Mixin for handling exceptions standardized across Firestore services.
///
/// Wraps generic [FirebaseException]s into domain-specific [FirestoreFailure]s.
mixin FirestoreErrorHandler {
  /// Executes a future and handles errors.
  Future<R> execute<R>(Future<R> Function() action) async {
    try {
      return await action();
    } on FirebaseException catch (e) {
      throw FirestoreFailure(e.message ?? 'Error de Firebase', code: e.code, originalError: e);
    } catch (e) {
      throw FirestoreFailure.unknown(e);
    }
  }

  /// Wraps a stream to handle errors effectively.
  Stream<R> executeStream<R>(Stream<R> stream) {
    return stream.handleError((e) {
      if (e is FirebaseException) {
        throw FirestoreFailure(e.message ?? 'Error de Stream Firebase', code: e.code, originalError: e);
      }
      throw FirestoreFailure.unknown(e);
    });
  }
}
