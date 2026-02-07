import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/firestore_model.dart';
import '../exceptions/firestore_exceptions.dart';

class FirestoreBatchOperations<T extends FirestoreModelMixin> {
  final WriteBatch _batch;
  final CollectionReference<T> _collectionRef;
  final FirebaseFirestore _firestore;

  FirestoreBatchOperations(this._batch, this._collectionRef, this._firestore);

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

  void delete(String id) {
    _batch.delete(_collectionRef.doc(id));
  }

  Future<void> commit() => _batch.commit();
}
