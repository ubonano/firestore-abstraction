import 'package:cloud_firestore/cloud_firestore.dart';
import '../classes/firestore_model.dart';
import '../exceptions/firestore_exceptions.dart';

/// Helper class for managing batch write operations.
///
/// Allows queueing multiple write operations ([create], [update], [delete])
/// to be executed atomically using a single [WriteBatch].
class FirestoreBatchOperations<T extends FirestoreModelMixin> {
  final WriteBatch _batch;
  final CollectionReference<T> _collectionRef;
  final FirebaseFirestore _firestore;

  /// Creates a new [FirestoreBatchOperations] instance.
  ///
  /// Typically created via [FirestoreService.batch].
  FirestoreBatchOperations(this._batch, this._collectionRef, this._firestore);

  /// Queues a create operation in the batch.
  ///
  /// Uses the item's existing ID or reference if available, otherwise generates a new one.
  void create(T item) {
    DocumentReference<T> docRef;
    if (item.ref != null) {
      docRef = _collectionRef.doc(item.ref!.id);
    } else if (item.id != null && item.id!.isNotEmpty) {
      docRef = _collectionRef.doc(item.id);
    } else {
      docRef = _collectionRef.doc();
    }

    item.ref = _firestore.doc(docRef.path);

    _batch.set(docRef, item);
  }

  /// Queues an update operation in the batch.
  ///
  /// Throws [FirestoreFailure] if valid identity (ID or ref) is missing.
  void update(T item, {bool merge = true}) {
    DocumentReference<T> docRef;
    if (item.ref != null) {
      docRef = _collectionRef.doc(item.ref!.id);
    } else {
      if (item.id == null || item.id!.isEmpty) {
        throw FirestoreFailure('No se puede actualizar un documento sin ID o Referencia', code: 'invalid-argument');
      }
      docRef = _collectionRef.doc(item.id);
    }

    _batch.set(docRef, item, SetOptions(merge: merge));
  }

  /// Queues a delete operation in the batch.
  void delete(String id) {
    _batch.delete(_collectionRef.doc(id));
  }

  /// Commits the batch, executing all queued operations atomically.
  Future<void> commit() => _batch.commit();
}
