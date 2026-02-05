import 'package:cloud_firestore/cloud_firestore.dart';

/// Clase base abstracta para todos los modelos de Firestore.
/// Ahora almacena la referencia completa del documento para permitir operaciones
/// independientes del path original (utile para Collection Groups).
/// Mixin que contiene la lógica base para los modelos de Firestore.
/// Usar este mixin permite desacoplar los modelos de la herencia obligatoria de [FirestoreModel].
mixin FirestoreModelMixin {
  /// Referencia al documento en Firestore.
  DocumentReference<Map<String, dynamic>>? ref;

  /// ID temporal o manual.
  String? _id;

  /// Identificador único del documento.
  String? get id => ref?.id ?? _id;
  set id(String? value) => _id = value;

  /// Fecha de creación.
  DateTime? createdAt;

  /// Fecha de última modificación.
  DateTime? updatedAt;

  /// Convierte el objeto a un Map para Firestore.
  Map<String, dynamic> toMap();
}

/// Clase base abstracta compatible con código legado.
/// Los nuevos modelos pueden preferir usar `with FirestoreModelMixin` directamente.
abstract class FirestoreModel with FirestoreModelMixin {
  FirestoreModel({DocumentReference<Map<String, dynamic>>? ref, String? id, DateTime? createdAt, DateTime? updatedAt}) {
    this.ref = ref;
    _id = id;
    this.createdAt = createdAt;
    this.updatedAt = updatedAt;
  }
}
