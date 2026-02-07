import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/firestore_model.dart';
import 'firestore_read_only_service.dart';
import 'firestore_batch_operations.dart';
import 'firestore_transaction_operations.dart';

export 'firestore_read_only_service.dart';

/// Service responsible for performing full CRUD operations on a Firestore collection.
///
/// This service extends [FirestoreReadOnlyService] to add write capabilities
/// ([create], [update], [delete]) as well as advanced batch and transaction support.
///
/// It requires a generic type [T] that extends [FirestoreModelMixin] to ensure
/// type safety and standardized data handling.
class FirestoreService<T extends FirestoreModelMixin> extends FirestoreReadOnlyService<T> {
  /// Function to convert a model instance [T] into a Firestore Map.
  final ToMap<T> toMap;

  /// Creates a new [FirestoreService].
  ///
  /// [collectionPath]: The path to the Firestore collection.
  /// [fromMap]: Function to deserialize Firestore data into model [T].
  /// [toMap]: Function to serialize model [T] into Firestore data.
  /// [firestore]: Optional Firestore instance (defaults to [FirebaseFirestore.instance]).
  FirestoreService({required super.collectionPath, required super.fromMap, required this.toMap, super.firestore})
    : super(isCollectionGroup: false);

  /// Returns a type-safe [CollectionReference] for this service.
  ///
  /// This reference uses [withConverter] to automatically handle serialization
  /// and deserialization of the model [T].
  CollectionReference<T> get collectionReference {
    return firestore
        .collection(collectionPath)
        .withConverter<T>(fromFirestore: (snapshot, _) => fromMap(snapshot), toFirestore: (item, _) => toMap(item));
  }

  /// Creates a new document in the collection.
  ///
  /// If the [item] has a [ref] or an [id] already set, it will attempt to use that
  /// specific document location. Otherwise, a new random ID is generated.
  ///
  /// Returns the ID of the created document.
  Future<String> create(T item) => execute(() async {
    DocumentReference<T> docRef;
    if (item.ref != null) {
      docRef = collectionReference.doc(item.ref!.id);
    } else if (item.id != null && item.id!.isNotEmpty) {
      docRef = collectionReference.doc(item.id);
    } else {
      docRef = collectionReference.doc();
    }

    // Assign the generated reference back to the item for immediate usage
    item.ref = firestore.doc(docRef.path);

    await docRef.set(item);
    return docRef.id;
  });

  /// Updates an existing document in the collection.
  ///
  /// [item] must have a valid [id] or [ref]. If [merge] is true (default),
  /// the update mimics a PATCH operation, only updating the fields present in the map.
  /// If [merge] is false, it overwrites the entire document.
  ///
  /// Throws an [Exception] if the item has no identity.
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

  /// Deletes a document by its [id].
  Future<void> delete(String id) => execute(() async {
    await collectionReference.doc(id).delete();
  });

  /// Provides access to batch operations for this collection.
  ///
  /// Returns a [FirestoreBatchOperations] helper that can queue writes
  /// on the provided [batch] or a new one.
  FirestoreBatchOperations<T> batch(WriteBatch batch) {
    return FirestoreBatchOperations(batch, collectionReference, firestore);
  }

  /// Provides access to transaction-scoped operations.
  ///
  /// Returns a [FirestoreTransactionOperations] helper to perform reads and writes
  /// within the context of the provided [transaction].
  FirestoreTransactionOperations<T> withTransaction(Transaction transaction) {
    return FirestoreTransactionOperations(transaction, collectionReference, firestore);
  }
}
