import 'package:cloud_firestore/cloud_firestore.dart';

class FirestorePaginatedResult<T> {
  final List<T> items;

  final DocumentSnapshot? lastDocumentSnapshot;

  FirestorePaginatedResult(this.items, this.lastDocumentSnapshot);
}

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
