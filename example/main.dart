import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firestore_abstraction/firestore_abstraction.dart';

/// Example model representing a User.
///
/// Uses [FirestoreModelMixin] to gain access to Standard Firestore fields like `id` and `ref`.
class User with FirestoreModelMixin {
  final String name;
  final int age;

  User({required this.name, required this.age});

  @override
  Map<String, dynamic> toMap() {
    return {'name': name, 'age': age};
  }

  factory User.fromMap(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final map = snapshot.data()!;
    return User(name: map['name'] as String, age: map['age'] as int);
  }
}

void main() async {
  // 1. Initialize Firebase (Required in a real app)
  // await Firebase.initializeApp();

  // 2. Create the service instance
  // Pass the generic type <User> and the serialization logic.
  final userService = FirestoreService<User>(
    collectionPath: 'users',
    fromMap: (snapshot) => User.fromMap(snapshot),
    toMap: (user) => user.toMap(),
  );

  print('Firestore Abstraction Service Initialized!');

  // 3. Usage Examples
  try {
    // Create
    final newUser = User(name: 'Alice', age: 30);
    final userId = await userService.create(newUser);
    print('Created user with ID: $userId');

    // Read
    final fetchedUser = await userService.get(userId);
    if (fetchedUser != null) {
      print('Fetched User: ${fetchedUser.name}');
    }

    // Update
    if (fetchedUser != null) {
      // Modifying the object locally doesn't update Firestore automatically.
      // We must call update().
      // Note: In a real app, you'd likely use copyWith() to create a new instance.
      await userService.update(fetchedUser, merge: true);
    }

    // Delete
    await userService.delete(userId);
    print('User deleted');
  } catch (e) {
    // All errors are wrapped in FirestoreFailure for easier handling
    print('An error occurred: $e');
  }
}
