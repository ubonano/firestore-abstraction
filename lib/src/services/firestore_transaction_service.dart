import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';
import '../models/firestore_model.dart';

/// Servicio restringido para operaciones dentro de una transacción.
/// Oculta métodos inseguros como Queries y Streams que no son soportados
/// dentro de una transacción de cliente.
class FirestoreTransactionService<T extends FirestoreModelMixin> {
  final FirestoreService<T> _service;
  final Transaction _transaction;

  FirestoreTransactionService(this._service, this._transaction);

  /// Utiliza otro servicio dentro del contexto de esta misma transacción.
  /// Esto permite realizar operaciones atómicas multi-colección de manera tipada.
  ///
  /// Ejemplo:
  /// ```dart
  /// await serviceA.runTransactionScoped((scopeA) async {
  ///   scopeA.update(docA);
  ///   final scopeB = scopeA.use(serviceB);
  ///   scopeB.update(docB);
  /// });
  /// ```
  FirestoreTransactionService<S> use<S extends FirestoreModelMixin>(FirestoreService<S> otherService) {
    return FirestoreTransactionService<S>(otherService, _transaction);
  }

  /// Obtiene un documento por ID dentro de la transacción.
  Future<T?> get(String id) {
    return _service.get(id, transaction: _transaction);
  }

  /// Crea o sobrescribe un documento dentro de la transacción.
  void create(T item) {
    _service.create(item, transaction: _transaction);
  }

  /// Actualiza un documento dentro de la transacción.
  void update(T item, {bool merge = true}) {
    _service.update(item, merge: merge, transaction: _transaction);
  }

  /// Elimina un documento por ID dentro de la transacción.
  void delete(String id) {
    _service.delete(id, transaction: _transaction);
  }

  /// Elimina un item por referencia dentro de la transacción.
  void deleteItem(T item) {
    _service.deleteItem(item, transaction: _transaction);
  }
}
