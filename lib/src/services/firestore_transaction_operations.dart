import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/firestore_model.dart';
import '../exceptions/firestore_exceptions.dart';

class FirestoreTransactionOperations<T extends FirestoreModelMixin> {
  final Transaction _transaction;
  final CollectionReference<T> _collectionRef;
  final FirebaseFirestore _firestore;

  FirestoreTransactionOperations(this._transaction, this._collectionRef, this._firestore);

  Future<T?> get(String id) async {
    final docRef = _collectionRef.doc(id);
    final snapshot = await _transaction.get(docRef);
    if (!snapshot.exists) return null;
    return snapshot.data();
  }

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

    _transaction.set(docRef, item);
  }

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

    _transaction.set(docRef, item, SetOptions(merge: merge));
  }

  void delete(String id) {
    _transaction.delete(_collectionRef.doc(id));
  }
}
