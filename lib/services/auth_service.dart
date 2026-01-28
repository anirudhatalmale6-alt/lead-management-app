import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';

class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream of Firebase Auth state changes (sign-in / sign-out).
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// The currently signed-in Firebase user, or null.
  User? get currentUser => _auth.currentUser;

  /// Fetches the current user's Firestore document and returns it as [AppUser].
  /// Returns null if no user is signed in or the document does not exist.
  Future<AppUser?> getCurrentAppUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;

    return AppUser.fromFirestore(doc);
  }

  /// Signs in an existing user with [email] and [password].
  Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Creates a new user account with [email] and [password].
  Future<UserCredential> signUp(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Signs the current user out of Firebase Auth.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Sends a password-reset email to the given [email] address.
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Creates a new user document in the Firestore 'users' collection.
  Future<void> createUserDocument(
    String uid,
    String email,
    String displayName,
    UserRole role, {
    String? teamId,
    String? groupId,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'display_name': displayName,
      'email': email,
      'role': role.toSnakeCase(),
      'team_id': teamId,
      'group_id': groupId,
      'is_active': true,
      'phone': null,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'created_by': _auth.currentUser?.uid,
    });
  }

  /// Updates the [role] field for the user identified by [uid].
  Future<void> updateUserRole(String uid, UserRole role) async {
    await _firestore.collection('users').doc(uid).update({
      'role': role.toSnakeCase(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// Fetches all user documents from Firestore and returns them as [AppUser] list.
  Future<List<AppUser>> getAllUsers() async {
    final snapshot = await _firestore.collection('users').get();
    return snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList();
  }

  /// Fetches users that belong to the given [teamId].
  Future<List<AppUser>> getUsersByTeam(String teamId) async {
    final snapshot = await _firestore
        .collection('users')
        .where('team_id', isEqualTo: teamId)
        .get();
    return snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList();
  }

  /// Fetches users that have the given [role].
  Future<List<AppUser>> getUsersByRole(UserRole role) async {
    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: role.toSnakeCase())
        .get();
    return snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList();
  }
}
