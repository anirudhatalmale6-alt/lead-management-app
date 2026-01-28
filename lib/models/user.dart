import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { superAdmin, admin, manager, teamLead, coordinator, member }

extension UserRoleX on UserRole {
  String get label {
    switch (this) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.admin:
        return 'Admin';
      case UserRole.manager:
        return 'Manager';
      case UserRole.teamLead:
        return 'Team Lead';
      case UserRole.coordinator:
        return 'Coordinator';
      case UserRole.member:
        return 'Member';
    }
  }

  String toSnakeCase() {
    switch (this) {
      case UserRole.superAdmin:
        return 'super_admin';
      case UserRole.admin:
        return 'admin';
      case UserRole.manager:
        return 'manager';
      case UserRole.teamLead:
        return 'team_lead';
      case UserRole.coordinator:
        return 'coordinator';
      case UserRole.member:
        return 'member';
    }
  }

  static UserRole fromSnakeCase(String value) {
    switch (value) {
      case 'super_admin':
        return UserRole.superAdmin;
      case 'admin':
        return UserRole.admin;
      case 'manager':
        return UserRole.manager;
      case 'team_lead':
        return UserRole.teamLead;
      case 'coordinator':
        return UserRole.coordinator;
      case 'member':
        return UserRole.member;
      default:
        return UserRole.member;
    }
  }
}

class AppUser {
  final String uid;
  final String name;
  final String email;
  final UserRole role;
  final String? teamId;
  final String? groupId;
  final bool isActive;
  final String? phone;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.teamId,
    this.groupId,
    this.isActive = true,
    this.phone,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      name: data['display_name'] ?? '',
      email: data['email'] ?? '',
      role: UserRoleX.fromSnakeCase(data['role'] ?? 'member'),
      teamId: data['team_id'],
      groupId: data['group_id'],
      isActive: data['is_active'] ?? true,
      phone: data['phone'],
      createdAt: (data['created_at'] as Timestamp?)?.toDate(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate(),
      createdBy: data['created_by'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'display_name': name,
      'email': email,
      'role': role.toSnakeCase(),
      'team_id': teamId,
      'group_id': groupId,
      'is_active': isActive,
      'phone': phone,
      'created_at': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'created_by': createdBy,
    };
  }

  AppUser copyWith({
    String? uid,
    String? name,
    String? email,
    UserRole? role,
    String? teamId,
    String? groupId,
    bool? isActive,
    String? phone,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      teamId: teamId ?? this.teamId,
      groupId: groupId ?? this.groupId,
      isActive: isActive ?? this.isActive,
      phone: phone ?? this.phone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
