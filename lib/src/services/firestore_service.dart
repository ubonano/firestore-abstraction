import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firestore_model_mixin.dart';
import '../utils/firestore_paginated_result.dart';

import '../utils/firestore_failure.dart';

import '../utils/firestore_cursor.dart';
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
  /// The internal reference to the Firestore collection with converter applied.
  ///
  /// This is used for all read and write operations to ensure type safety.
  CollectionReference<T> get _collectionRef => firestore
      .collection(collectionPath)
      .withConverter<T>(fromFirestore: (snapshot, _) => fromMap(snapshot), toFirestore: (item, _) => toMap(item));

  Future<R> _execute<R>(Future<R> Function() action) async {
    try {
      return await action();
    } on FirebaseException catch (e) {
      throw FirestoreFailure(e.message ?? 'Firebase Error', code: e.code, originalError: e);
    } catch (e) {
      throw FirestoreFailure.unknown(e);
    }
  }

  Stream<R> _executeStream<R>(Stream<R> stream) => stream.handleError((e) {
    if (e is FirebaseException) {
      throw FirestoreFailure(e.message ?? 'Firebase Stream Error', code: e.code, originalError: e);
    }
    throw FirestoreFailure.unknown(e);
  });

  /// Executes a Firestore transaction with standardized error handling.
  Future<R> runTransaction<R>(Future<R> Function(Transaction transaction) action) async =>
      _execute(() async => await firestore.runTransaction(action));

  /// Fetches a single document by its [id].
  ///
  /// Returns `null` if the document does not exist.
  Future<T?> get(String id) => _execute(() async {
    final docRef = _collectionRef.doc(id);
    final snapshot = await docRef.get();
    if (!snapshot.exists || snapshot.data() == null) return null;
    return snapshot.data();
  });

  /// Checks if a document exists.
  Future<bool> exists(String id) => _execute(() async {
    final docRef = firestore.collection(collectionPath).doc(id);
    final snapshot = await docRef.get();
    return snapshot.exists;
  });

  /// Streams real-time updates for a list of documents.
  ///
  /// [limit] defaults to 20.
  Stream<FirestorePaginatedResult<T>> streamList({
    QueryBuilder<T>? queryBuilder,
    int limit = 20,
    FirestoreCursor? startAfter,
  }) {
    Query<T> query = _collectionRef;
    if (queryBuilder != null) {
      query = queryBuilder(query);
    }

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter.snapshot);
    }

    // Apply limit
    query = query.limit(limit);

    return _executeStream(
      query.snapshots().map((snapshot) {
        final items = snapshot.docs.map((d) => d.data()).toList();
        final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        return FirestorePaginatedResult(items, lastDoc != null ? FirestoreCursor(lastDoc) : null);
      }),
    );
  }

  /// Streams real-time updates for a single document.
  Stream<T?> streamDocument(String id) => _executeStream(
    _collectionRef.doc(id).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return snapshot.data();
    }),
  );

  /// Performs a paginated query and returns the results along with the cursor for the next page.
  ///
  /// [limit] defaults to 20 and is capped at 100.
  Future<FirestorePaginatedResult<T>> query({
    QueryBuilder<T>? queryBuilder,
    int limit = 20,
    FirestoreCursor? startAfter,
  }) => _execute(() async {
    Query<T> query = _collectionRef;
    if (queryBuilder != null) {
      query = queryBuilder(query);
    }

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter.snapshot);
    }

    // Apply limit
    query = query.limit(limit);

    final querySnapshot = await query.get();
    final items = querySnapshot.docs.map((doc) => doc.data()).toList();
    final lastDoc = querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null;
    return FirestorePaginatedResult(items, lastDoc != null ? FirestoreCursor(lastDoc) : null);
  });

  /// Provides access to transaction-scoped operations.
  ///
  /// Returns a [FirestoreTransactionOperations] helper to perform reads and writes
  /// within the context of the provided [transaction].
  FirestoreTransactionOperations<T> withTransaction(Transaction transaction) =>
      FirestoreTransactionOperations(transaction, _collectionRef, firestore);
}
