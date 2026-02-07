import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/firestore_model.dart';
import '../models/firestore_results.dart';
import '../exceptions/firestore_exceptions.dart';

typedef FromMap<T> = T Function(DocumentSnapshot<Map<String, dynamic>> snapshot);
typedef ToMap<T> = Map<String, dynamic> Function(T item);
typedef QueryBuilder<T> = Query<T> Function(Query<T> query);

mixin FirestoreErrorHandler {
  Future<R> execute<R>(Future<R> Function() action) async {
    try {
      return await action();
    } on FirebaseException catch (e) {
      throw FirestoreFailure(e.message ?? 'Error de Firebase', code: e.code, originalError: e);
    } catch (e) {
      throw FirestoreFailure.unknown(e);
    }
  }

  Stream<R> executeStream<R>(Stream<R> stream) {
    return stream.handleError((e) {
      if (e is FirebaseException) {
        throw FirestoreFailure(e.message ?? 'Error de Stream Firebase', code: e.code, originalError: e);
      }
      throw FirestoreFailure.unknown(e);
    });
  }
}

class FirestoreReadOnlyService<T extends FirestoreModelMixin> with FirestoreErrorHandler {
  final FirebaseFirestore firestore;
  final String collectionPath;
  final FromMap<T> fromMap;
  final bool isCollectionGroup;

  FirestoreReadOnlyService({
    required this.collectionPath,
    required this.fromMap,
    this.isCollectionGroup = false,
    FirebaseFirestore? firestore,
  }) : firestore = firestore ?? FirebaseFirestore.instance;

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

  Future<bool> exists(String id, {GetOptions? options}) => execute(() async {
    if (isCollectionGroup) {
      final querySnap = await _queryRef.where(FieldPath.documentId, isEqualTo: id).limit(1).get(options);
      return querySnap.docs.isNotEmpty;
    }
    final docRef = firestore.collection(collectionPath).doc(id);
    final snapshot = await docRef.get(options);
    return snapshot.exists;
  });

  Future<List<T>> getAll({QueryBuilder<T>? queryBuilder, GetOptions? options}) => execute(() async {
    Query<T> query = _queryRef;
    if (queryBuilder != null) {
      query = queryBuilder(query);
    }
    final querySnapshot = await query.get(options);
    return querySnapshot.docs.map((doc) => doc.data()).toList();
  });

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
