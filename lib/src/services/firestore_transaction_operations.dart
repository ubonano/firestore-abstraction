import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firestore_model_mixin.dart';
import '../utils/firestore_failure.dart';

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
  ///
  /// Throws [FirestoreFailure.alreadyExists] if the document already exists.
  /// Note: This performs a read within the transaction.
  Future<void> create(T item) async {
    final docRef = _getDocumentRef(item);

    // Check availability within transaction
    final snapshot = await _transaction.get(docRef);
    if (snapshot.exists) {
      throw FirestoreFailure.alreadyExists(docRef.id);
    }

    final data = item.toMap();

    _transaction.set(docRef, data);
  }

  /// Queues an update operation in the transaction.
  ///
  /// Uses [update] semantics: fails if the document does not exist.
  void update(T item) {
    if (item.id == null && item.ref == null) {
      throw FirestoreFailure('No se puede actualizar un documento sin ID o Referencia', code: 'invalid-argument');
    }

    final docRef = _getDocumentRef(item);

    final data = item.toMap();

    _transaction.update(docRef, data);
  }

  /// Queues a delete operation in the transaction.
  void delete(String id) {
    if (id.isEmpty) {
      throw FirestoreFailure('El ID del documento no puede estar vacío', code: 'invalid-argument');
    }
    _transaction.delete(_collectionRef.doc(id));
  }

  DocumentReference<Map<String, dynamic>> _getDocumentRef(T item) {
    if (item.ref != null) {
      return _firestore.doc(item.ref!.path);
    } else if (item.id != null && item.id!.isNotEmpty) {
      return _firestore.collection(_collectionRef.path).doc(item.id);
    } else {
      return _firestore.collection(_collectionRef.path).doc();
    }
  }
}
