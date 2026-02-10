import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firestore_model_mixin.dart';
import '../utils/firestore_paginated_result.dart';

import '../utils/firestore_failure.dart';
import '../utils/firestore_helper.dart';
import 'firestore_transaction_operations.dart';

typedef FromMap<T> = T Function(DocumentSnapshot<Map<String, dynamic>> snapshot);
typedef ToMap<T> = Map<String, dynamic> Function(T item);
typedef QueryBuilder<T> = Query<T> Function(Query<T> query);

/// Service responsible for performing full CRUD operations on a Firestore collection.
///
/// It requires a generic type [T] that extends [FirestoreModelMixin] to ensure
/// type safety and standardized data handling.
class FirestoreService<T extends FirestoreModelMixin> {
  /// The underlying Firestore instance.
  final FirebaseFirestore firestore;

  /// The path to the collection (e.g., 'users' or 'users/123/orders').
  final String collectionPath;

  /// Function to deserialize data into model [T].
  final FromMap<T> fromMap;

  /// Function to convert a model instance [T] into a Firestore Map.
  final ToMap<T> toMap;

  /// Creates a new [FirestoreService].
  ///
  /// [collectionPath]: The path to the Firestore collection.
  /// [fromMap]: Function to deserialize Firestore data into model [T].
  /// [toMap]: Function to serialize model [T] into Firestore data.
  /// [firestore]: Optional Firestore instance (defaults to [FirebaseFirestore.instance]).
  FirestoreService({
    required this.collectionPath,
    required this.fromMap,
    required this.toMap,
    FirebaseFirestore? firestore,
  }) : firestore = firestore ?? FirebaseFirestore.instance;

  /// Returns the base [Query] for reading.
  ///
  /// Applies the type converter.
  Query<T> get queryReference => firestore
      .collection(collectionPath)
      .withConverter<T>(fromFirestore: (snapshot, _) => fromMap(snapshot), toFirestore: (item, _) => toMap(item));

  Query<T> get _queryRef => queryReference;

  /// Returns a type-safe [CollectionReference] for this service.
  ///
  /// This reference uses [withConverter] to automatically handle serialization
  /// and deserialization of the model [T].
  CollectionReference<T> get collectionReference => firestore
      .collection(collectionPath)
      .withConverter<T>(fromFirestore: (snapshot, _) => fromMap(snapshot), toFirestore: (item, _) => toMap(item));

  /// Fetches a single document by its [id].
  ///
  /// Returns `null` if the document does not exist.
  Future<T?> get(String id, {GetOptions? options}) => FirestoreHelper.execute(() async {
    final docRef = collectionReference.doc(id);
    final snapshot = await docRef.get(options);
    if (!snapshot.exists || snapshot.data() == null) return null;
    return snapshot.data();
  });

  /// Checks if a document exists.
  Future<bool> exists(String id, {GetOptions? options}) => FirestoreHelper.execute(() async {
    final docRef = firestore.collection(collectionPath).doc(id);
    final snapshot = await docRef.get(options);
    return snapshot.exists;
  });

  /// Fetches all documents matching the optional [queryBuilder].
  Future<List<T>> getAll({QueryBuilder<T>? queryBuilder, GetOptions? options}) => FirestoreHelper.execute(() async {
    Query<T> query = _queryRef;
    if (queryBuilder != null) {
      query = queryBuilder(query);
    }
    final querySnapshot = await query.get(options);
    return querySnapshot.docs.map((doc) => doc.data()).toList();
  });

  /// Streams real-time updates for a list of documents.
  Stream<List<T>> streamAll({QueryBuilder<T>? queryBuilder, bool includeMetadataChanges = false}) {
    Query<T> query = _queryRef;
    if (queryBuilder != null) {
      query = queryBuilder(query);
    }
    return FirestoreHelper.executeStream(
      query
          .snapshots(includeMetadataChanges: includeMetadataChanges)
          .map((snapshot) => snapshot.docs.map((d) => d.data()).toList()),
    );
  }

  /// Streams real-time updates for a single document.
  Stream<T?> streamDocument(String id, {bool includeMetadataChanges = false}) => FirestoreHelper.executeStream(
    collectionReference.doc(id).snapshots(includeMetadataChanges: includeMetadataChanges).map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return snapshot.data();
    }),
  );

  /// Performs a paginated query and returns the results along with the cursor for the next page.
  Future<FirestorePaginatedResult<T>> query(QueryBuilder<T>? queryBuilder, {GetOptions? options}) =>
      FirestoreHelper.execute(() async {
        Query<T> query = _queryRef;
        if (queryBuilder != null) {
          query = queryBuilder(query);
        }
        final querySnapshot = await query.get(options);
        final items = querySnapshot.docs.map((doc) => doc.data()).toList();
        final lastDoc = querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null;
        return FirestorePaginatedResult(items, lastDoc);
      });

  /// Creates a new document in the collection.
  ///
  /// If the [item] has a [ref] or an [id] already set, it will attempt to use that
  /// specific document location. Otherwise, a new random ID is generated.
  ///
  /// returns the ID of the created document.
  Future<String> create(T item) => FirestoreHelper.execute(() async {
    final docRef = FirestoreHelper.getDocumentRef(firestore: firestore, collectionPath: collectionPath, item: item);

    final data = toMap(item);

    await docRef.set(data);
    return docRef.id;
  });

  /// Updates an existing document in the collection.
  ///
  /// [item] must have a valid [id] or [ref]. If [merge] is true (default),
  /// the update mimics a PATCH operation, only updating the fields present in the map.
  /// If [merge] is false, it overwrites the entire document.
  ///
  /// Throws an [Exception] if the item has no identity.
  Future<void> update(T item, {bool merge = true}) => FirestoreHelper.execute(() async {
    if (item.id == null && item.ref == null) {
      throw FirestoreFailure('No se puede actualizar un documento sin ID o Referencia', code: 'invalid-argument');
    }

    final docRef = FirestoreHelper.getDocumentRef(firestore: firestore, collectionPath: collectionPath, item: item);

    final data = toMap(item);

    await docRef.set(data, SetOptions(merge: merge));
  });

  /// Updates specific fields of a document without overwriting the entire document.
  ///
  /// This method allows for atomic updates using [FieldValue]s (e.g., [FieldValue.increment],
  /// [FieldValue.arrayUnion]).
  ///
  /// [data] must not contain the `id` or `ref` as keys.
  Future<void> updatePartial(String id, Map<String, dynamic> data) => FirestoreHelper.execute(() async {
    final docRef = collectionReference.doc(id);

    final dataToUpdate = Map<String, dynamic>.from(data);

    await docRef.update(dataToUpdate);
  });

  /// Deletes a document by its [id].
  Future<void> delete(String id) => FirestoreHelper.execute(() async {
    if (id.isEmpty) {
      throw FirestoreFailure('El ID del documento no puede estar vacío', code: 'invalid-argument');
    }
    await collectionReference.doc(id).delete();
  });

  /// Provides access to transaction-scoped operations.
  ///
  /// Returns a [FirestoreTransactionOperations] helper to perform reads and writes
  /// within the context of the provided [transaction].
  FirestoreTransactionOperations<T> withTransaction(Transaction transaction) =>
      FirestoreTransactionOperations(transaction, collectionReference, firestore);
}
