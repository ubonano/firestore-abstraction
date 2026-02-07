import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/firestore_model.dart';
import '../exceptions/firestore_exceptions.dart';
import '../models/firestore_results.dart';

/// Definición de funciones para conversión de tipos
typedef FromMap<T> = T Function(DocumentSnapshot<Map<String, dynamic>> snapshot);
typedef ToMap<T> = Map<String, dynamic> Function(T item);
typedef QueryBuilder<T> = Query<T> Function(Query<T> query);

/// Mixin para manejar errores de Firebase de manera centralizada.
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

/// Servicio genérico para interactuar con Firestore con soporte robusto.
class FirestoreService<T extends FirestoreModelMixin> with FirestoreErrorHandler {
  final FirebaseFirestore _firestore;
  final String collectionPath;
  final FromMap<T> fromMap;
  final ToMap<T> toMap;
  final bool isCollectionGroup;

  final String? createdAtField;
  final String? updatedAtField;

  FirestoreService({
    required this.collectionPath,
    required this.fromMap,
    required this.toMap,
    this.isCollectionGroup = false,
    this.createdAtField = 'createdAt',
    this.updatedAtField = 'updatedAt',
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  // --- Referencias Públicas (Escape Hatches) ---

  /// Referencia tipada base para consultas (Colección o Grupo).
  Query<T> get queryReference {
    Query<Map<String, dynamic>> rawQuery;
    if (isCollectionGroup) {
      rawQuery = _firestore.collectionGroup(collectionPath);
    } else {
      rawQuery = _firestore.collection(collectionPath);
    }
    return rawQuery.withConverter<T>(
      fromFirestore: (snapshot, _) => fromMap(snapshot),
      toFirestore: (item, _) => toMap(item),
    );
  }

  /// Referencia tipada para escritura (Solo válida para Collection normal).
  CollectionReference<T> get collectionReference {
    if (isCollectionGroup) {
      throw FirestoreFailure(
        'No se puede obtener CollectionReference en modo Collection Group. Este modo es solo para consultas.',
        code: 'invalid-mode',
      );
    }
    return _firestore
        .collection(collectionPath)
        .withConverter<T>(fromFirestore: (snapshot, _) => fromMap(snapshot), toFirestore: (item, _) => toMap(item));
  }

  /// Creates a copy of this service but configured to query the Collection Group
  FirestoreService<T> asCollectionGroup() {
    return FirestoreService(
      collectionPath: collectionPath,
      fromMap: fromMap,
      toMap: toMap,
      firestore: _firestore,
      isCollectionGroup: true,
      createdAtField: createdAtField,
      updatedAtField: updatedAtField,
    );
  }

  /// Referencia cruda (para escritura manual sin converters).
  CollectionReference<Map<String, dynamic>> get rawCollectionReference {
    if (isCollectionGroup) {
      throw FirestoreFailure('No se pueden realizar escrituras en modo Collection Group.', code: 'invalid-mode');
    }
    return _firestore.collection(collectionPath);
  }

  /// Referencia para consultas crudas (`Map<String, dynamic>`).
  Query<Map<String, dynamic>> get rawQueryReference {
    if (isCollectionGroup) {
      return _firestore.collectionGroup(collectionPath);
    }
    return _firestore.collection(collectionPath);
  }

  // --- Referencias Internas (Aliases para uso interno) ---
  Query<T> get _queryRef => queryReference;
  CollectionReference<T> get _collectionRef => collectionReference;
  CollectionReference<Map<String, dynamic>> get _rawCollectionRef => rawCollectionReference;

  // --- Utilidades de Referencia ---

  DocumentReference<T> getRef(String id) => _collectionRef.doc(id);
  DocumentReference<T> get docRef => _collectionRef.doc();

  // --- Validaciones ---
  void _checkWritePermission() {
    if (isCollectionGroup) {
      throw FirestoreFailure(
        'Las operaciones de escritura no están permitidas en modo Collection Group.',
        code: 'invalid-mode',
      );
    }
  }

  // --- Escritura ---

  /// Crea un nuevo documento (o sobrescribe si ya tiene ref).
  Future<String> create(T item, {Transaction? transaction, WriteBatch? batch}) => execute(() async {
    final data = toMap(item);
    if (createdAtField != null) data[createdAtField!] = FieldValue.serverTimestamp();
    if (updatedAtField != null) data[updatedAtField!] = FieldValue.serverTimestamp();

    DocumentReference<Map<String, dynamic>> docRef;
    if (item.ref != null) {
      docRef = item.ref!;
    } else if (item.id != null && item.id!.isNotEmpty) {
      _checkWritePermission();
      docRef = _rawCollectionRef.doc(item.id);
    } else {
      _checkWritePermission();
      docRef = _rawCollectionRef.doc();
    }

    if (transaction != null) {
      transaction.set(docRef, data);
    } else if (batch != null) {
      batch.set(docRef, data);
    } else {
      await docRef.set(data);
    }
    return docRef.id;
  });

  /// Actualiza un documento completo REEMPLAZANDO su contenido (merge=true por defecto).
  Future<void> update(T item, {bool merge = true, Transaction? transaction, WriteBatch? batch}) => execute(() async {
    DocumentReference<Map<String, dynamic>> docRef;
    if (item.ref != null) {
      docRef = item.ref!;
    } else {
      _checkWritePermission();
      if (item.id == null || item.id!.isEmpty) {
        throw FirestoreFailure('No se puede actualizar un documento sin ID o Referencia', code: 'invalid-argument');
      }
      docRef = _rawCollectionRef.doc(item.id);
    }

    final data = toMap(item);
    if (updatedAtField != null) data[updatedAtField!] = FieldValue.serverTimestamp();
    if (createdAtField != null) data.remove(createdAtField);

    if (transaction != null) {
      transaction.set(docRef, data, SetOptions(merge: merge));
    } else if (batch != null) {
      batch.set(docRef, data, SetOptions(merge: merge));
    } else {
      await docRef.set(data, SetOptions(merge: merge));
    }
  });

  /// Elimina un documento por ID.
  Future<void> delete(String id, {Transaction? transaction, WriteBatch? batch}) => execute(() async {
    _checkWritePermission();
    final docRef = _rawCollectionRef.doc(id);

    if (transaction != null) {
      transaction.delete(docRef);
    } else if (batch != null) {
      batch.delete(docRef);
    } else {
      await docRef.delete();
    }
  });

  // --- Lectura ---

  Future<T?> get(String id, {Transaction? transaction, GetOptions? options}) => execute(() async {
    if (isCollectionGroup) {
      final querySnap = await _queryRef.where(FieldPath.documentId, isEqualTo: id).limit(1).get(options);
      if (querySnap.docs.isEmpty) return null;
      return querySnap.docs.first.data();
    }
    DocumentSnapshot<Map<String, dynamic>> snapshot;
    if (transaction != null) {
      snapshot = await transaction.get(_rawCollectionRef.doc(id));
    } else {
      snapshot = await _rawCollectionRef.doc(id).get(options);
    }
    if (!snapshot.exists || snapshot.data() == null) return null;
    return fromMap(snapshot);
  });

  Future<Map<String, dynamic>?> getRaw(String id, {Transaction? transaction, GetOptions? options}) => execute(() async {
    DocumentSnapshot<Map<String, dynamic>> snapshot;
    if (isCollectionGroup) {
      final querySnap = await _firestore
          .collectionGroup(collectionPath)
          .where(FieldPath.documentId, isEqualTo: id)
          .limit(1)
          .get(options);
      if (querySnap.docs.isEmpty) return null;
      snapshot = querySnap.docs.first;
    } else if (transaction != null) {
      snapshot = await transaction.get(_rawCollectionRef.doc(id));
    } else {
      snapshot = await _rawCollectionRef.doc(id).get(options);
    }
    if (!snapshot.exists) return null;
    return snapshot.data();
  });

  Future<bool> exists(String id, {GetOptions? options}) => execute(() async {
    if (isCollectionGroup) {
      final querySnap = await _queryRef.where(FieldPath.documentId, isEqualTo: id).limit(1).get(options);
      return querySnap.docs.isNotEmpty;
    }
    final snapshot = await _rawCollectionRef.doc(id).get(options);
    return snapshot.exists;
  });

  Stream<List<DocumentChange<T>>> streamChanges({QueryBuilder<T>? queryBuilder, bool includeMetadataChanges = false}) {
    Query<T> query = _queryRef;
    if (queryBuilder != null) {
      query = queryBuilder(query);
    }
    return executeStream(
      query.snapshots(includeMetadataChanges: includeMetadataChanges).map((snapshot) {
        return snapshot.docChanges;
      }),
    );
  }

  Stream<List<T>> streamAll({bool includeMetadataChanges = false}) => executeStream(
    _queryRef
        .snapshots(includeMetadataChanges: includeMetadataChanges)
        .map((snapshot) => snapshot.docs.map((d) => d.data()).toList()),
  );

  /// Ejecuta una consulta paginada.
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

  /// Ejecuta una consulta directa sobre la referencia cruda (`Map<String, dynamic>`).
  Future<QuerySnapshot<Map<String, dynamic>>> queryRaw(
    QueryBuilder<Map<String, dynamic>>? queryBuilder, {
    GetOptions? options,
  }) => execute(() async {
    Query<Map<String, dynamic>> query = rawQueryReference;
    if (queryBuilder != null) {
      query = queryBuilder(query);
    }
    return await query.get(options);
  });

  Stream<List<T>> streamQuery(QueryBuilder<T> queryBuilder, {bool includeMetadataChanges = false}) {
    final query = queryBuilder(_queryRef);
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
      _collectionRef.doc(id).snapshots(includeMetadataChanges: includeMetadataChanges).map((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) return null;
        return snapshot.data();
      }),
    );
  }

  // --- Agregaciones ---

  FirestoreService<S> subCollection<S extends FirestoreModelMixin>(
    String path, {
    required FromMap<S> fromMap,
    required ToMap<S> toMap,
  }) {
    final newPath = '$collectionPath/$path';
    return FirestoreService<S>(firestore: _firestore, collectionPath: newPath, fromMap: fromMap, toMap: toMap);
  }
}
