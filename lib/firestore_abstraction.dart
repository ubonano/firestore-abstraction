/// A generic, type-safe abstraction layer for Cloud Firestore.
///
/// This package provides a set of services and models to simplify interactions with
/// Firestore, enforcing type safety, standardized error handling, and cleaner code.
///
/// To get started, define your models by extending [FirestoreModel] (or mixing in
/// [FirestoreModelMixin]) and use [FirestoreService] to perform operations.
library;

export 'src/services/firestore_service.dart';
export 'src/utils/firestore_model_mixin.dart';
export 'src/utils/firestore_paginated_result.dart';

export 'src/utils/firestore_failure.dart';
export 'src/utils/firestore_helper.dart';
