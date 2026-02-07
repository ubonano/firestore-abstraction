import 'package:cloud_firestore/cloud_firestore.dart';

mixin FirestoreModelMixin {
  DocumentReference<Map<String, dynamic>>? ref;

  String? _id;

  String? get id => ref?.id ?? _id;
  set id(String? value) => _id = value;

  DateTime? createdAt;

  DateTime? updatedAt;

  Map<String, dynamic> toMap();
}

abstract class FirestoreModel with FirestoreModelMixin {
  FirestoreModel({DocumentReference<Map<String, dynamic>>? ref, String? id, DateTime? createdAt, DateTime? updatedAt}) {
    this.ref = ref;
    _id = id;
    this.createdAt = createdAt;
    this.updatedAt = updatedAt;
  }
}
