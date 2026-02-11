import 'package:test/test.dart';
import 'package:firestore_abstraction/firestore_abstraction.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Mock model for testing
class TestModel with FirestoreModelMixin {
  final String name;

  TestModel({required this.name, String? id}) {
    this.id = id;
  }

  @override
  Map<String, dynamic> toMap() {
    return {'name': name};
  }

  static TestModel fromMap(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    return TestModel(name: data?['name'] ?? '', id: snapshot.id);
  }
}

void main() {
  group('FirestoreAbstraction', () {
    test('FirestoreModelMixin handles ID correctly', () {
      final model = TestModel(name: 'Test', id: '123');
      expect(model.id, equals('123'));

      model.id = '456';
      expect(model.id, equals('456'));
    });

    test('FirestoreFailure constants are correct', () {
      expect(FirestoreFailure.codeNotFound, equals('not-found'));
      expect(FirestoreFailure.codePermissionDenied, equals('permission-denied'));
    });
  });
}
