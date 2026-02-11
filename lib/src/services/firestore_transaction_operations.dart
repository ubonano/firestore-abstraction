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
    final DocumentReference<T> docRef = _getTypedDocumentRef(item);

    // Assign generic reference and ID to the item so the caller has access to the generated ID
    // We create a raw reference from the typed reference path
    item.ref = _firestore.doc(docRef.path);
    item.id = docRef.id;

    // Check availability within transaction
    final snapshot = await _transaction.get(docRef);
    if (snapshot.exists) {
      throw FirestoreFailure.alreadyExists(docRef.id);
    }

    _transaction.set(docRef, item);
  }

  /// Queues an update operation in the transaction.
  ///
  /// Uses [update] semantics: fails if the document does not exist.
  void update(T item) {
    if (item.id == null && item.ref == null) {
      throw FirestoreFailure.invalidArgument('Cannot update a document without ID or Reference');
    }

    final DocumentReference<T> docRef = _getTypedDocumentRef(item);

    // Transaction.update requires a Map<String, dynamic> of fields to update.
    // Since we are updating the whole object (or what toMap returns), and we have a typed reference,
    // we should prefer .set(..., SetOptions(merge: true)) or strictly uses update if we want to enforce existence.
    // However, cloud_firestore's transaction.update takes specific fields.
    // To support full object update with "must exist" semantics, we can use existing toMap logic
    // but we can't easily use the typed reference's converter for partial updates unless we do .set with merge.
    // But .set(merge:true) will create if not exists? No, not if we check existence.
    // Standard Firestore update() implies "must exist".
    // Let's stick to Map for update to be safe with standard semantics.

    final data = item.toMap();
    // Use the raw reference for update to match the data map
    final rawRef = _firestore.doc(docRef.path);
    _transaction.update(rawRef, data);
  }

  /// Queues a delete operation in the transaction.
  void delete(String id) {
    if (id.isEmpty) {
      throw FirestoreFailure.invalidArgument('Document ID cannot be empty');
    }
    _transaction.delete(_collectionRef.doc(id));
  }

  /// Performs a safe atomic update using a transform function.
  ///
  /// Reads the current document, applies the [transform] function, and saves the result.
  /// Throws [FirestoreFailure.notFound] if the document does not exist.
  Future<void> updateAtomic(String id, T Function(T current) transform) async {
    final doc = await get(id);
    if (doc == null) {
      throw FirestoreFailure.notFound(id);
    }

    final updatedDoc = transform(doc);

    // Ensure the ID is preserved for the update if it was lost
    if (updatedDoc.id == null && updatedDoc.ref == null) {
      updatedDoc.id = id;
    }

    update(updatedDoc);
  }

  /// Helper to resolve the correct typed document reference.
  DocumentReference<T> _getTypedDocumentRef(T item) {
    if (item.ref != null) {
      // Assuming the item's ref belongs to this collection.
      // We use the ID to get a typed reference from our collection reference.
      return _collectionRef.doc(item.ref!.id);
    } else if (item.id != null && item.id!.isNotEmpty) {
      return _collectionRef.doc(item.id);
    } else {
      return _collectionRef.doc();
    }
  }
}
