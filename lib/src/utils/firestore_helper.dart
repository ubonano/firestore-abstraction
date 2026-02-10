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

  /// Prepares the data map for writing to Firestore.
  ///
  /// Injects [FieldValue.serverTimestamp] for `createdAt` (if [isCreate] is true)
  /// and `updatedAt`, ensuring server-side time consistency.
  static Map<String, dynamic> prepareData(Map<String, dynamic> data, {bool isCreate = false}) {
    final map = Map<String, dynamic>.from(data);

    // We use FieldValue.serverTimestamp() to ensure consistency and avoid client-time issues.
    if (isCreate) {
      map['createdAt'] = FieldValue.serverTimestamp();
      map['updatedAt'] = FieldValue.serverTimestamp();
    } else {
      map['updatedAt'] = FieldValue.serverTimestamp();
      // Ensure we don't accidentally overwrite createdAt on updates if it's not present (standard behavior)
      // but if the user passed it in 'data', it would be there.
      // Typically, models might include createdAt in toMap.
      // If we are updating, we usually want to preserve existing createdAt.
      // If the map has it, we leave it (or the server ignores it if we only send partial data?
      // But update(item) usually replaces fields).
      // However, if we use SetOptions(merge: true), fields not in map are preserved.
      // To be safe, we usually don't remove createdAt from the map if it's there,
      // but for updates we definitely enforce updatedAt.
    }

    // Ensure ID and Ref are not part of the persisted data to avoid redundancy/recursion issues
    map.remove('id');
    map.remove('ref');

    return map;
  }

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
