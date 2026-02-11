import 'package:cloud_firestore/cloud_firestore.dart';

/// An opaque cursor for handling pagination in [FirestoreService].
///
/// Encapsulates a [DocumentSnapshot] to be used as a starting or ending point
/// in paginated queries, without directly exposing the `cloud_firestore` dependency
/// to the upper layers of the application.
class FirestoreCursor {
  /// The underlying Firestore snapshot.
  ///
  /// MUST NOT be used outside the infrastructure layer.
  final DocumentSnapshot snapshot;

  /// Creates a new [FirestoreCursor].
  const FirestoreCursor(this.snapshot);
}
