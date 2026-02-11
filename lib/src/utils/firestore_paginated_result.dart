import 'firestore_cursor.dart';

/// Represents a page of results from a paginated query.
///
/// Contains the list of [items] for the current page and the [lastDocumentSnapshot]
/// which is used as a cursor to fetch the next page.
class FirestorePaginatedResult<T> {
  /// The list of items retrieved in this page.
  final List<T> items;

  /// The cursor for the next page of results.
  ///
  /// Use this cursor in the next `query` call to fetch the subsequent results.
  final FirestoreCursor? cursor;

  /// Creates a new [FirestorePaginatedResult].
  FirestorePaginatedResult(this.items, this.cursor);
}
