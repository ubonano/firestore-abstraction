import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_exceptions.dart';

/// Helper class for executing Firestore operations with standardized error handling.
///
/// This class provides static methods to wrap Firestore calls, ensuring that exceptions
/// are caught and rethrown as domain-specific [FirestoreFailure]s.
class FirestoreExecutor {
  /// Executes a [Future] and handles errors.
  static Future<T> execute<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseException catch (e) {
      throw FirestoreFailure(e.message ?? 'Error de Firebase', code: e.code, originalError: e);
    } catch (e) {
      throw FirestoreFailure.unknown(e);
    }
  }

  /// Wraps a [Stream] to handle errors effectively.
  static Stream<T> executeStream<T>(Stream<T> stream) => stream.handleError((e) {
    if (e is FirebaseException) {
      throw FirestoreFailure(e.message ?? 'Error de Stream Firebase', code: e.code, originalError: e);
    }
    throw FirestoreFailure.unknown(e);
  });

  /// Executes a Firestore transaction with standardized error handling.
  static Future<T> runTransaction<T>(Future<T> Function(Transaction transaction) action) async =>
      execute(() async => await FirebaseFirestore.instance.runTransaction(action));
}
