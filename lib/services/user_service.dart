import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'users';

  // Cache users to avoid repeated fetches
  List<AppUser>? _cachedUsers;
  DateTime? _cacheTime;
  static const _cacheDuration = Duration(minutes: 5);

  /// Get all users
  Future<List<AppUser>> getAllUsers({bool forceRefresh = false}) async {
    // Return cached if valid
    if (!forceRefresh && _cachedUsers != null && _cacheTime != null) {
      if (DateTime.now().difference(_cacheTime!) < _cacheDuration) {
        return _cachedUsers!;
      }
    }

    final snapshot = await _db.collection(_collection).get();
    _cachedUsers = snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList();
    _cacheTime = DateTime.now();
    return _cachedUsers!;
  }

  /// Get users by role
  Future<List<AppUser>> getUsersByRole(UserRole role) async {
    final users = await getAllUsers();
    return users.where((u) => u.role == role).toList();
  }

  /// Get all employees (members)
  Future<List<AppUser>> getEmployees() async {
    return getUsersByRole(UserRole.member);
  }

  /// Get all managers
  Future<List<AppUser>> getManagers() async {
    return getUsersByRole(UserRole.manager);
  }

  /// Get all team leads
  Future<List<AppUser>> getTeamLeads() async {
    return getUsersByRole(UserRole.teamLead);
  }

  /// Get user by email
  Future<AppUser?> getUserByEmail(String email) async {
    final users = await getAllUsers();
    try {
      return users.firstWhere((u) => u.email.toLowerCase() == email.toLowerCase());
    } catch (e) {
      return null;
    }
  }

  /// Get user by UID
  Future<AppUser?> getUserByUid(String uid) async {
    final doc = await _db.collection(_collection).doc(uid).get();
    if (doc.exists) {
      return AppUser.fromFirestore(doc);
    }
    return null;
  }

  /// Search users by name or email
  Future<List<AppUser>> searchUsers(String query) async {
    if (query.isEmpty) return [];
    final users = await getAllUsers();
    final lowerQuery = query.toLowerCase();
    return users.where((u) =>
      u.name.toLowerCase().contains(lowerQuery) ||
      u.email.toLowerCase().contains(lowerQuery) ||
      u.firstName.toLowerCase().contains(lowerQuery) ||
      u.lastName.toLowerCase().contains(lowerQuery)
    ).toList();
  }

  /// Get users by team ID
  Future<List<AppUser>> getUsersByTeam(String teamId) async {
    final users = await getAllUsers();
    return users.where((u) => u.teamId == teamId).toList();
  }

  /// Get users by group ID
  Future<List<AppUser>> getUsersByGroup(String groupId) async {
    final users = await getAllUsers();
    return users.where((u) => u.groupId == groupId).toList();
  }

  /// Clear cache
  void clearCache() {
    _cachedUsers = null;
    _cacheTime = null;
  }
}
