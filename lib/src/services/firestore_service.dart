import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/firestore_model.dart';
import 'firestore_read_only_service.dart';
import 'firestore_batch_operations.dart';
import 'firestore_transaction_operations.dart';

export 'firestore_read_only_service.dart';

class FirestoreService<T extends FirestoreModelMixin> extends FirestoreReadOnlyService<T> {
  final ToMap<T> toMap;

  FirestoreService({required super.collectionPath, required super.fromMap, required this.toMap, super.firestore})
    : super(isCollectionGroup: false);

  CollectionReference<T> get collectionReference {
    return firestore
        .collection(collectionPath)
        .withConverter<T>(fromFirestore: (snapshot, _) => fromMap(snapshot), toFirestore: (item, _) => toMap(item));
  }

  Future<String> create(T item) => execute(() async {
    DocumentReference<T> docRef;
    if (item.ref != null) {
      docRef = collectionReference.doc(item.ref!.id);
    } else if (item.id != null && item.id!.isNotEmpty) {
      docRef = collectionReference.doc(item.id);
    } else {
      docRef = collectionReference.doc();
    }

    item.ref = firestore.doc(docRef.path);

    await docRef.set(item);
    return docRef.id;
  });

  Future<void> update(T item, {bool merge = true}) => execute(() async {
    DocumentReference<T> docRef;
    if (item.ref != null) {
      docRef = collectionReference.doc(item.ref!.id);
    } else {
      if (item.id == null || item.id!.isEmpty) {
        throw Exception('No se puede actualizar un documento sin ID o Referencia');
      }
      docRef = collectionReference.doc(item.id);
    }

    await docRef.set(item, SetOptions(merge: merge));
  });

  Future<void> delete(String id) => execute(() async {
    await collectionReference.doc(id).delete();
  });

  FirestoreBatchOperations<T> batch(WriteBatch batch) {
    return FirestoreBatchOperations(batch, collectionReference, firestore);
  }

  FirestoreTransactionOperations<T> withTransaction(Transaction transaction) {
    return FirestoreTransactionOperations(transaction, collectionReference, firestore);
  }
}
