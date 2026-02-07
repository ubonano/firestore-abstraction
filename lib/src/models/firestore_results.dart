import 'package:cloud_firestore/cloud_firestore.dart';

/// Encapsula los resultados de una consulta paginada de Firestore.
///
/// Contiene la lista de items tipados [items] y el [lastDocumentSnapshot]
/// que sirve como cursor para solicitar la siguiente página.
class FirestorePaginatedResult<T> {
  /// Lista de documentos convertidos al modelo [T].
  final List<T> items;

  /// El último DocumentSnapshot de esta página.
  /// Usar este valor en `FirestoreQuery.startAfterDocument` para obtener la siguiente página.
  /// Es `null` si la lista está vacía.
  final DocumentSnapshot? lastDocumentSnapshot;

  FirestorePaginatedResult(this.items, this.lastDocumentSnapshot);
}

/// Wrapper que incluye el dato y su metadata (origen, cambios, etc).
class FirestoreResponse<T> {
  final T? data;
  final DocumentSnapshot? snapshot;
  final bool isFromCache;
  final bool hasPendingWrites;

  FirestoreResponse({this.data, this.snapshot, this.isFromCache = false, this.hasPendingWrites = false});

  factory FirestoreResponse.fromSnapshot(DocumentSnapshot snapshot, T? data) {
    return FirestoreResponse(
      data: data,
      snapshot: snapshot,
      isFromCache: snapshot.metadata.isFromCache,
      hasPendingWrites: snapshot.metadata.hasPendingWrites,
    );
  }
}
