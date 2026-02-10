import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_model_mixin.dart';
import 'firestore_exceptions.dart';

/// Helper class for shared Firestore logic.
class FirestoreHelper {
  /// Resolves the document reference to use for an operation.
  ///
  /// Uses [ref] if available, otherwise [id]. If neither is present,
  /// generates a new document reference so long as the operation supports it (e.g. create).
  static DocumentReference<Map<String, dynamic>> getDocumentRef<T extends FirestoreModelMixin>({
    required FirebaseFirestore firestore,
    required String collectionPath,
    required T item,
  }) {
    if (item.ref != null) {
      return firestore.doc(item.ref!.path);
    } else if (item.id != null && item.id!.isNotEmpty) {
      return firestore.collection(collectionPath).doc(item.id);
    } else {
      return firestore.collection(collectionPath).doc();
    }
  }

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
