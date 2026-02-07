import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/firestore_model.dart';
import '../models/firestore_results.dart';
import '../exceptions/firestore_exceptions.dart';

typedef FromMap<T> = T Function(DocumentSnapshot<Map<String, dynamic>> snapshot);
typedef ToMap<T> = Map<String, dynamic> Function(T item);
typedef QueryBuilder<T> = Query<T> Function(Query<T> query);

/// Mixin for handling exceptions standardized across Firestore services.
///
/// Wraps generic [FirebaseException]s into domain-specific [FirestoreFailure]s.
mixin FirestoreErrorHandler {
  /// Executes a future and handles errors.
  Future<R> execute<R>(Future<R> Function() action) async {
    try {
      return await action();
    } on FirebaseException catch (e) {
      throw FirestoreFailure(e.message ?? 'Error de Firebase', code: e.code, originalError: e);
    } catch (e) {
      throw FirestoreFailure.unknown(e);
    }
  }

  /// Wraps a stream to handle errors effectively.
  Stream<R> executeStream<R>(Stream<R> stream) {
    return stream.handleError((e) {
      if (e is FirebaseException) {
        throw FirestoreFailure(e.message ?? 'Error de Stream Firebase', code: e.code, originalError: e);
      }
      throw FirestoreFailure.unknown(e);
    });
  }
}

/// Base service for read-only Firestore access.
///
/// Provides methods to fetch ([get]), check existence ([exists]), and query ([query], [getAll])
/// documents. It does not contain any methods that modify data.
class FirestoreReadOnlyService<T extends FirestoreModelMixin> with FirestoreErrorHandler {
  /// The underlying Firestore instance.
  final FirebaseFirestore firestore;

  /// The path to the collection (e.g., 'users' or 'users/123/orders').
  final String collectionPath;

  /// Function to deserialize data into model [T].
  final FromMap<T> fromMap;

  /// Whether this service targets a Collection Group query.
  final bool isCollectionGroup;

  /// Creates a new [FirestoreReadOnlyService].
  FirestoreReadOnlyService({
    required this.collectionPath,
    required this.fromMap,
    this.isCollectionGroup = false,
    FirebaseFirestore? firestore,
  }) : firestore = firestore ?? FirebaseFirestore.instance;

  /// Returns the base [Query] for reading.
  ///
  /// Handles `collection` vs `collectionGroup` logic and applies the type converter.
  Query<T> get queryReference {
    Query<Map<String, dynamic>> rawQuery;
    if (isCollectionGroup) {
      rawQuery = firestore.collectionGroup(collectionPath);
    } else {
      rawQuery = firestore.collection(collectionPath);
    }
    return rawQuery.withConverter<T>(
      fromFirestore: (snapshot, _) => fromMap(snapshot),
      toFirestore: (item, _) => throw UnimplementedError('ReadOnlyService no soporta toFirestore'),
    );
  }

  Query<T> get _queryRef => queryReference;

  /// Fetches a single document by its [id].
  ///
  /// Returns `null` if the document does not exist.
  Future<T?> get(String id, {GetOptions? options}) => execute(() async {
    if (isCollectionGroup) {
      final querySnap = await _queryRef.where(FieldPath.documentId, isEqualTo: id).limit(1).get(options);
      if (querySnap.docs.isEmpty) return null;
      return querySnap.docs.first.data();
    }
    final docRef = firestore.collection(collectionPath).doc(id);
    final snapshot = await docRef.get(options);
    if (!snapshot.exists || snapshot.data() == null) return null;
    return fromMap(snapshot);
  });

  /// Checks if a document exists.
  Future<bool> exists(String id, {GetOptions? options}) => execute(() async {
    if (isCollectionGroup) {
      final querySnap = await _queryRef.where(FieldPath.documentId, isEqualTo: id).limit(1).get(options);
      return querySnap.docs.isNotEmpty;
    }
    final docRef = firestore.collection(collectionPath).doc(id);
    final snapshot = await docRef.get(options);
    return snapshot.exists;
  });

  /// Fetches all documents matching the optional [queryBuilder].
  Future<List<T>> getAll({QueryBuilder<T>? queryBuilder, GetOptions? options}) => execute(() async {
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
    return executeStream(
      query
          .snapshots(includeMetadataChanges: includeMetadataChanges)
          .map((snapshot) => snapshot.docs.map((d) => d.data()).toList()),
    );
  }

  /// Streams real-time updates for a single document.
  Stream<T?> streamDocument(String id, {bool includeMetadataChanges = false}) {
    if (isCollectionGroup) {
      return executeStream(
        _queryRef
            .where(FieldPath.documentId, isEqualTo: id)
            .limit(1)
            .snapshots(includeMetadataChanges: includeMetadataChanges)
            .map((snapshot) {
              if (snapshot.docs.isEmpty) return null;
              return snapshot.docs.first.data();
            }),
      );
    }
    return executeStream(
      firestore.collection(collectionPath).doc(id).snapshots(includeMetadataChanges: includeMetadataChanges).map((
        snapshot,
      ) {
        if (!snapshot.exists || snapshot.data() == null) return null;
        return fromMap(snapshot);
      }),
    );
  }

  /// Performs a paginated query and returns the results along with the cursor for the next page.
  Future<FirestorePaginatedResult<T>> query(QueryBuilder<T>? queryBuilder, {GetOptions? options}) => execute(() async {
    Query<T> query = _queryRef;
    if (queryBuilder != null) {
      query = queryBuilder(query);
    }
    final querySnapshot = await query.get(options);
    final items = querySnapshot.docs.map((doc) => doc.data()).toList();
    final lastDoc = querySnapshot.docs.isNotEmpty ? querySnapshot.docs.last : null;
    return FirestorePaginatedResult(items, lastDoc);
  });
}
