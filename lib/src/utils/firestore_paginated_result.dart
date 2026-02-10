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
