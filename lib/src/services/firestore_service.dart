import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firestore_model_mixin.dart';
import '../utils/firestore_paginated_result.dart';
import '../utils/firestore_executor.dart';
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
  Future<T?> get(String id, {GetOptions? options}) => FirestoreExecutor.execute(() async {
    final docRef = collectionReference.doc(id);
    final snapshot = await docRef.get(options);
    if (!snapshot.exists || snapshot.data() == null) return null;
    return snapshot.data();
  });

  /// Checks if a document exists.
  Future<bool> exists(String id, {GetOptions? options}) => FirestoreExecutor.execute(() async {
    final docRef = firestore.collection(collectionPath).doc(id);
    final snapshot = await docRef.get(options);
    return snapshot.exists;
  });

  /// Fetches all documents matching the optional [queryBuilder].
  Future<List<T>> getAll({QueryBuilder<T>? queryBuilder, GetOptions? options}) => FirestoreExecutor.execute(() async {
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
    return FirestoreExecutor.executeStream(
      query
          .snapshots(includeMetadataChanges: includeMetadataChanges)
          .map((snapshot) => snapshot.docs.map((d) => d.data()).toList()),
    );
  }

  /// Streams real-time updates for a single document.
  Stream<T?> streamDocument(String id, {bool includeMetadataChanges = false}) => FirestoreExecutor.executeStream(
    collectionReference.doc(id).snapshots(includeMetadataChanges: includeMetadataChanges).map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return snapshot.data();
    }),
  );

  /// Performs a paginated query and returns the results along with the cursor for the next page.
  Future<FirestorePaginatedResult<T>> query(QueryBuilder<T>? queryBuilder, {GetOptions? options}) =>
      FirestoreExecutor.execute(() async {
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
  /// Returns the ID of the created document.
  Future<String> create(T item) => FirestoreExecutor.execute(() async {
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
  Future<void> update(T item, {bool merge = true}) => FirestoreExecutor.execute(() async {
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
  Future<void> delete(String id) => FirestoreExecutor.execute(() async => await collectionReference.doc(id).delete());

  /// Provides access to transaction-scoped operations.
  ///
  /// Returns a [FirestoreTransactionOperations] helper to perform reads and writes
  /// within the context of the provided [transaction].
  FirestoreTransactionOperations<T> withTransaction(Transaction transaction) =>
      FirestoreTransactionOperations(transaction, collectionReference, firestore);
}
