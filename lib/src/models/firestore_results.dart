import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a page of results from a paginated query.
///
/// Contains the list of [items] for the current page and the [lastDocumentSnapshot]
/// which is used as a cursor to fetch the next page.
class FirestorePaginatedResult<T> {
  /// The list of items retrieved in this page.
  final List<T> items;

  /// The snapshot of the last document in this page.
  ///
  /// This is used to continue pagination in subsequent requests.
  final DocumentSnapshot? lastDocumentSnapshot;

  /// Creates a new [FirestorePaginatedResult].
  FirestorePaginatedResult(this.items, this.lastDocumentSnapshot);
}

/// Represents a response from a Firestore operation, including metadata.
///
/// Wraps the [data] (the model instance) along with the raw [snapshot] and
/// metadata flags like [isFromCache] and [hasPendingWrites].
class FirestoreResponse<T> {
  /// The deserialized data model, if available.
  final T? data;

  /// The raw [DocumentSnapshot] from Firestore.
  final DocumentSnapshot? snapshot;

  /// Whether the data was served from the local cache.
  ///
  /// If `true`, the data might be stale compared to the server.
  final bool isFromCache;

  /// Whether the document has local changes that haven't been synchronized to the server yet.
  final bool hasPendingWrites;

  /// Creates a new [FirestoreResponse].
  FirestoreResponse({this.data, this.snapshot, this.isFromCache = false, this.hasPendingWrites = false});

  /// Creates a [FirestoreResponse] from a [DocumentSnapshot].
  ///
  /// Extracts metadata from the snapshot such as `isFromCache` and `hasPendingWrites`.
  factory FirestoreResponse.fromSnapshot(DocumentSnapshot snapshot, T? data) {
    return FirestoreResponse(
      data: data,
      snapshot: snapshot,
      isFromCache: snapshot.metadata.isFromCache,
      hasPendingWrites: snapshot.metadata.hasPendingWrites,
    );
  }
}
