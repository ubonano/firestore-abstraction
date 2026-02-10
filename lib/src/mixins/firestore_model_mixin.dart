import 'package:cloud_firestore/cloud_firestore.dart';

/// Mixin that adds Firestore-specific fields to a class.
///
/// This mixin provides the common fields required for any object stored in Firestore,
/// such as the document reference [ref], the document ID [id], and timestamps
/// [createdAt] and [updatedAt].
mixin FirestoreModelMixin {
  /// The reference to the Firestore document.
  ///
  /// This is `null` if the object has not yet been saved to Firestore or if
  /// it was created locally without being attached to a document.
  DocumentReference<Map<String, dynamic>>? ref;

  String? _id;

  /// The unique identifier of the document.
  ///
  /// Returns the ID from [ref] if available, otherwise returns the locally set ID.
  String? get id => ref?.id ?? _id;

  /// Sets the unique identifier of the document.
  set id(String? value) => _id = value;

  /// The date and time when the document was created.
  DateTime? createdAt;

  /// The date and time when the document was last updated.
  DateTime? updatedAt;

  /// Converts the object to a [Map] representation for Firestore.
  ///
  /// This method must be implemented by consuming classes to define how
  /// the object properties are mapped to Firestore fields.
  Map<String, dynamic> toMap();
}
