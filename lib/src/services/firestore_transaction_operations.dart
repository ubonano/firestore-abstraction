import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firestore_model_mixin.dart';
import '../utils/firestore_failure.dart';
import '../utils/firestore_helper.dart';

/// Helper class for managing transaction-scoped operations.
///
/// Ensures strict read-before-write semantics required by Firestore transactions.
/// Operations performed here are part of the larger transaction passed in the constructor.
class FirestoreTransactionOperations<T extends FirestoreModelMixin> {
  final Transaction _transaction;
  final CollectionReference<T> _collectionRef;
  final FirebaseFirestore _firestore;

  /// Creates a new [FirestoreTransactionOperations] instance.
  FirestoreTransactionOperations(this._transaction, this._collectionRef, this._firestore);

  /// Reads a document within the transaction.
  ///
  /// This MUST be called before any writes on the same document if the modification
  /// depends on the current value.
  Future<T?> get(String id) async {
    final docRef = _collectionRef.doc(id);
    final snapshot = await _transaction.get(docRef);
    if (!snapshot.exists) return null;
    return snapshot.data();
  }

  /// Queues a create operation in the transaction.
  void create(T item) {
    final docRef = FirestoreHelper.getDocumentRef(
      firestore: _firestore,
      collectionPath: _collectionRef.path,
      item: item,
    );

    final data = item.toMap();

    _transaction.set(docRef, data);
  }

  /// Queues an update operation in the transaction.
  void update(T item, {bool merge = true}) {
    if (item.id == null && item.ref == null) {
      throw FirestoreFailure('No se puede actualizar un documento sin ID o Referencia', code: 'invalid-argument');
    }

    final docRef = FirestoreHelper.getDocumentRef(
      firestore: _firestore,
      collectionPath: _collectionRef.path,
      item: item,
    );

    final data = item.toMap();

    _transaction.set(docRef, data, SetOptions(merge: merge));
  }

  /// Queues a partial update operation in the transaction.
  ///

  void updatePartial(String id, Map<String, dynamic> data) {
    final docRef = _collectionRef.doc(id);

    final dataToUpdate = Map<String, dynamic>.from(data);

    _transaction.update(docRef, dataToUpdate);
  }

  /// Queues a delete operation in the transaction.
  void delete(String id) {
    if (id.isEmpty) {
      throw FirestoreFailure('El ID del documento no puede estar vacío', code: 'invalid-argument');
    }
    _transaction.delete(_collectionRef.doc(id));
  }
}
