import 'package:cloud_firestore/cloud_firestore.dart';
import '../mixins/firestore_model_mixin.dart';

export '../mixins/firestore_model_mixin.dart'; // Exporting so existing imports don't break immediately

/// Base class for all Firestore models.
///
/// This abstract class implements [FirestoreModelMixin] and provides a standard
/// constructor for initializing the base fields. All data models that represent
/// a Firestore document should extend this class.
abstract class FirestoreModel with FirestoreModelMixin {
  /// Creates a new [FirestoreModel] instance.
  ///
  /// [ref]: The document reference.
  /// [id]: The document ID.
  /// [createdAt]: The creation timestamp.
  /// [updatedAt]: The last update timestamp.
  FirestoreModel({DocumentReference<Map<String, dynamic>>? ref, String? id, DateTime? createdAt, DateTime? updatedAt}) {
    this.ref = ref;
    this.id = id;
    this.createdAt = createdAt;
    this.updatedAt = updatedAt;
  }
}
