import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as cf;
import '../models/firestore_model.dart';
import '../exceptions/firestore_exceptions.dart';
import '../models/firestore_results.dart';
import 'firestore_transaction_service.dart';

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

  final Transaction? _activeTransaction;
  final WriteBatch? _activeBatch;

  FirestoreService({
    required this.collectionPath,
    required this.fromMap,
    required this.toMap,
    this.isCollectionGroup = false,
    this.createdAtField = 'createdAt',
    this.updatedAtField = 'updatedAt',
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _activeTransaction = null,
       _activeBatch = null;

  /// Constructor for scoped instances (Internal use for subclasses).
  FirestoreService.protected({
    required this.collectionPath,
    required this.fromMap,
    required this.toMap,
    required FirebaseFirestore firestore,
    required this.isCollectionGroup,
    required this.createdAtField,
    required this.updatedAtField,
    Transaction? transaction,
    WriteBatch? batch,
  }) : _firestore = firestore,
       _activeTransaction = transaction,
       _activeBatch = batch;

  /// Creates a copy of this service with the given transaction or batch.
  FirestoreService<T> copyWith({Transaction? transaction, WriteBatch? batch}) {
    return FirestoreService.protected(
      collectionPath: collectionPath,
      fromMap: fromMap,
      toMap: toMap,
      firestore: _firestore,
      isCollectionGroup: isCollectionGroup,
      createdAtField: createdAtField,
      updatedAtField: updatedAtField,
      transaction: transaction,
      batch: batch,
    );
  }

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
    return FirestoreService.protected(
      collectionPath: collectionPath,
      fromMap: fromMap,
      toMap: toMap,
      firestore: _firestore,
      isCollectionGroup: true,
      createdAtField: createdAtField,
      updatedAtField: updatedAtField,
      transaction: _activeTransaction,
      batch: _activeBatch,
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

  // --- Transacciones ---

  /// Internal: Runs a transaction. exposed only for advanced usage within library.
  Future<R> _runTransaction<R>(Future<R> Function(Transaction transaction) action) {
    _checkWritePermission();
    return execute(() => _firestore.runTransaction(action));
  }

  /// Ejecuta un conjunto de escrituras de manera atómica y eficiente.
  Future<void> runBatch(Future<void> Function(WriteBatch batch) action) {
    _checkWritePermission();
    return execute(() async {
      final batch = _firestore.batch();
      await action(batch);
      await batch.commit();
    });
  }

  /// Run a transaction providing a restricted scoped service.
  /// Safest way to perform transactions.
  Future<R> runTransactionScoped<R>(Future<R> Function(FirestoreTransactionService<T> service) action) {
    return _runTransaction((transaction) {
      // Creamos el helper restringido
      final scopedService = FirestoreTransactionService(this, transaction);
      return action(scopedService);
    });
  }

  /// Ejecuta un batch y proporciona un servicio scoped que usa dicho batch automáticamente.
  Future<void> runBatchScoped(Future<void> Function(FirestoreService<T> service) action) {
    return runBatch((batch) async {
      final scopedService = copyWith(batch: batch);
      await action(scopedService);
    });
  }

  // --- Escritura ---

  /// Crea un nuevo documento (o sobrescribe si ya tiene ref).
  Future<String> create(T item, {Transaction? transaction, WriteBatch? batch}) => execute(() async {
    final data = toMap(item);
    if (createdAtField != null) data[createdAtField!] = FieldValue.serverTimestamp();
    if (updatedAtField != null) data[updatedAtField!] = FieldValue.serverTimestamp();

    final activeTransaction = _activeTransaction ?? transaction;
    final activeBatch = _activeBatch ?? batch;

    if (item.ref != null) {
      final docRef = item.ref!;
      if (activeTransaction != null) {
        activeTransaction.set(docRef, data);
        return docRef.id;
      } else if (activeBatch != null) {
        activeBatch.set(docRef, data);
        return docRef.id;
      } else {
        await docRef.set(data);
        return docRef.id;
      }
    } else {
      _checkWritePermission();
      if (item.id != null && item.id!.isNotEmpty) {
        final docRef = _rawCollectionRef.doc(item.id);
        if (activeTransaction != null) {
          activeTransaction.set(docRef, data);
          return item.id!;
        } else if (activeBatch != null) {
          activeBatch.set(docRef, data);
          return item.id!;
        } else {
          await docRef.set(data);
          return item.id!;
        }
      } else {
        final docRef = _rawCollectionRef.doc();
        if (activeTransaction != null) {
          activeTransaction.set(docRef, data);
          return docRef.id;
        } else if (activeBatch != null) {
          activeBatch.set(docRef, data);
          return docRef.id;
        } else {
          await docRef.set(data);
          return docRef.id;
        }
      }
    }
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

    final activeTransaction = _activeTransaction ?? transaction;
    final activeBatch = _activeBatch ?? batch;

    if (activeTransaction != null) {
      activeTransaction.set(docRef, data, SetOptions(merge: merge));
    } else if (activeBatch != null) {
      activeBatch.set(docRef, data, SetOptions(merge: merge));
    } else {
      await docRef.set(data, SetOptions(merge: merge));
    }
  });

  /// Elimina un documento por ID.
  Future<void> delete(String id, {Transaction? transaction, WriteBatch? batch}) => execute(() async {
    _checkWritePermission();
    final docRef = _rawCollectionRef.doc(id);

    final activeTransaction = _activeTransaction ?? transaction;
    final activeBatch = _activeBatch ?? batch;

    if (activeTransaction != null) {
      activeTransaction.delete(docRef);
    } else if (activeBatch != null) {
      activeBatch.delete(docRef);
    } else {
      await docRef.delete();
    }
  });

  /// Elimina un item usando su referencia.
  Future<void> deleteItem(T item, {Transaction? transaction, WriteBatch? batch}) => execute(() async {
    if (item.ref == null) {
      if (item.id != null) {
        return delete(item.id!, transaction: transaction, batch: batch);
      }
      throw FirestoreFailure('No se puede eliminar un item sin referencia ni ID', code: 'invalid-argument');
    }
    final docRef = item.ref!;
    final activeTransaction = _activeTransaction ?? transaction;
    final activeBatch = _activeBatch ?? batch;

    if (activeTransaction != null) {
      activeTransaction.delete(docRef);
    } else if (activeBatch != null) {
      activeBatch.delete(docRef);
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

  Future<FirestoreResponse<T>?> getWithResponse(String id, {Transaction? transaction, GetOptions? options}) =>
      execute(() async {
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
        if (!snapshot.exists || snapshot.data() == null) return null;
        return FirestoreResponse.fromSnapshot(snapshot, fromMap(snapshot));
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

  Stream<List<FirestoreResponse<T>>> streamQueryWithResponse(
    QueryBuilder<T> queryBuilder, {
    bool includeMetadataChanges = true,
  }) {
    final query = queryBuilder(_queryRef);
    return executeStream(
      query.snapshots(includeMetadataChanges: includeMetadataChanges).map((snapshot) {
        return snapshot.docs.map((d) => FirestoreResponse.fromSnapshot(d, d.data())).toList();
      }),
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

  Stream<FirestoreResponse<T>?> streamDocumentWithResponse(String id, {bool includeMetadataChanges = true}) {
    if (isCollectionGroup) {
      return executeStream(
        _queryRef
            .where(FieldPath.documentId, isEqualTo: id)
            .limit(1)
            .snapshots(includeMetadataChanges: includeMetadataChanges)
            .map((snapshot) {
              if (snapshot.docs.isEmpty) return null;
              final doc = snapshot.docs.first;
              return FirestoreResponse.fromSnapshot(doc, doc.data());
            }),
      );
    }
    return executeStream(
      _collectionRef.doc(id).snapshots(includeMetadataChanges: includeMetadataChanges).map((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) return null;
        return FirestoreResponse.fromSnapshot(snapshot, snapshot.data());
      }),
    );
  }

  // --- Agregaciones ---

  /// Realiza múltiples agregaciones en una sola llamada eficiente.
  Future<FirestoreAggregationResult> aggregate(
    QueryBuilder<T>? queryBuilder, {
    bool count = true,
    List<String> sum = const [],
    List<String> average = const [],
  }) {
    return execute(() async {
      Query<T> query = _queryRef;
      if (queryBuilder != null) {
        query = queryBuilder(query);
      }

      AggregateQuery aggQuery; // No default init needed properly if we use count correctly below

      if (!count && sum.isEmpty && average.isEmpty) {
        return FirestoreAggregationResult(count: 0);
      }

      final List<AggregateField> fields = [];
      AggregateField? countField;
      if (count) {
        countField = cf.count();
        fields.add(countField);
      }
      for (final s in sum) {
        fields.add(cf.sum(s));
      }
      for (final a in average) {
        fields.add(cf.average(a));
      }

      if (fields.isEmpty) return FirestoreAggregationResult(count: 0);

      // Usamos Function.apply para pasar la lista de argumentos posicionales
      // ya que query.aggregate espera (field1, [field2, ...])
      // ignore: avoid_dynamic_calls
      aggQuery = Function.apply(query.aggregate, fields) as AggregateQuery;

      final snapshot = await aggQuery.get();

      return FirestoreAggregationResult(
        count: count ? snapshot.count : null,
        sums: {for (final s in sum) s: snapshot.getSum(s) ?? 0.0},
        averages: {for (final a in average) a: snapshot.getAverage(a) ?? 0.0},
      );
    });
  }

  FirestoreService<S> subCollection<S extends FirestoreModelMixin>(
    String path, {
    String? parentId,
    required FromMap<S> fromMap,
    required ToMap<S> toMap,
  }) {
    final newPath = parentId != null ? '$collectionPath/$parentId/$path' : '$collectionPath/$path';

    if (_activeTransaction != null) {
      return FirestoreService<S>.protected(
        firestore: _firestore,
        collectionPath: newPath,
        fromMap: fromMap,
        toMap: toMap,
        isCollectionGroup: false,
        createdAtField: createdAtField,
        updatedAtField: updatedAtField,
        transaction: _activeTransaction,
      );
    }
    return FirestoreService<S>(firestore: _firestore, collectionPath: newPath, fromMap: fromMap, toMap: toMap);
  }

  Future<void> disableNetwork() => execute(() => _firestore.disableNetwork());
  Future<void> enableNetwork() => execute(() => _firestore.enableNetwork());
  Future<void> clearPersistence() => execute(() => _firestore.clearPersistence());
  Future<void> waitForPendingWrites() => execute(() => _firestore.waitForPendingWrites());
}

extension AggregateQuerySnapshotX on AggregateQuerySnapshot {
  // Helper extension methods since the API might return different types
  // or to standardize access.
  double? getSum(String field) {
    try {
      // ignore: avoid_dynamic_calls
      return (this as dynamic).get(cf.sum(field))?.toDouble();
    } catch (_) {
      return null;
    }
  }

  double? getAverage(String field) {
    try {
      // ignore: avoid_dynamic_calls
      return (this as dynamic).get(cf.average(field))?.toDouble();
    } catch (_) {
      return null;
    }
  }
}
