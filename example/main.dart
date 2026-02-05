import 'package:firestore_abstraction/firestore_abstraction.dart';

class User with FirestoreModelMixin {
  final String name;
  final int age;

  User({required this.name, required this.age});

  @override
  Map<String, dynamic> toMap() {
    return {'name': name, 'age': age};
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(name: map['name'] as String, age: map['age'] as int);
  }
}

void main() async {
  print('Hola Mundo desde Firestore Abstraction!');

  // Example usage (pseudo-code since we don't have a real Firebase instance here)
  /*
  final userService = FirestoreService<User>(
    collectionPath: 'users',
    fromMap: (snapshot) => User.fromMap(snapshot.data()!),
    toMap: (user) => user.toMap(),
  );

  await userService.create(User(name: 'Alice', age: 30));
  */
}
