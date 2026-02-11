import 'package:cloud_firestore/cloud_firestore.dart';

/// Un cursor opaco para manejar la paginación en [FirestoreService].
///
/// Encapsula un [DocumentSnapshot] para ser usado como punto de inicio o término
/// en consultas paginadas, sin exponer directamente la dependencia de `cloud_firestore`
/// a las capas superiores de la aplicación.
class FirestoreCursor {
  /// El snapshot subyacente de Firestore.
  ///
  /// NO debe ser usado fuera de la capa de infraestructura.
  final DocumentSnapshot snapshot;

  /// Crea un nuevo [FirestoreCursor].
  const FirestoreCursor(this.snapshot);
}
