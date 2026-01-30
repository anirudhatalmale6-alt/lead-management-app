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
        return 'TL';
      case UserRole.coordinator:
        return 'Coordinator';
      case UserRole.member:
        return 'Emp';
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

// Role permissions model
class RolePermissions {
  final bool leadViewOwn;
  final bool leadEditOwn;
  final bool leadCreate;
  final bool leadDelete;
  final bool leadViewGroup;
  final bool leadViewTeam;
  final bool leadViewGlobal;

  const RolePermissions({
    this.leadViewOwn = true,
    this.leadEditOwn = false,
    this.leadCreate = false,
    this.leadDelete = false,
    this.leadViewGroup = false,
    this.leadViewTeam = false,
    this.leadViewGlobal = false,
  });

  factory RolePermissions.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const RolePermissions();
    return RolePermissions(
      leadViewOwn: data['lead_view_own'] ?? true,
      leadEditOwn: data['lead_edit_own'] ?? false,
      leadCreate: data['lead_create'] ?? false,
      leadDelete: data['lead_delete'] ?? false,
      leadViewGroup: data['lead_view_group'] ?? false,
      leadViewTeam: data['lead_view_team'] ?? false,
      leadViewGlobal: data['lead_view_global'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lead_view_own': leadViewOwn,
      'lead_edit_own': leadEditOwn,
      'lead_create': leadCreate,
      'lead_delete': leadDelete,
      'lead_view_group': leadViewGroup,
      'lead_view_team': leadViewTeam,
      'lead_view_global': leadViewGlobal,
    };
  }

  RolePermissions copyWith({
    bool? leadViewOwn,
    bool? leadEditOwn,
    bool? leadCreate,
    bool? leadDelete,
    bool? leadViewGroup,
    bool? leadViewTeam,
    bool? leadViewGlobal,
  }) {
    return RolePermissions(
      leadViewOwn: leadViewOwn ?? this.leadViewOwn,
      leadEditOwn: leadEditOwn ?? this.leadEditOwn,
      leadCreate: leadCreate ?? this.leadCreate,
      leadDelete: leadDelete ?? this.leadDelete,
      leadViewGroup: leadViewGroup ?? this.leadViewGroup,
      leadViewTeam: leadViewTeam ?? this.leadViewTeam,
      leadViewGlobal: leadViewGlobal ?? this.leadViewGlobal,
    );
  }
}

// Custom role model for role management
class CustomRole {
  final String id;
  final String name;
  final RolePermissions permissions;
  final int userCount;
  final DateTime? createdAt;

  const CustomRole({
    required this.id,
    required this.name,
    required this.permissions,
    this.userCount = 0,
    this.createdAt,
  });

  factory CustomRole.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CustomRole(
      id: doc.id,
      name: data['name'] ?? '',
      permissions: RolePermissions.fromMap(data['permissions']),
      userCount: data['user_count'] ?? 0,
      createdAt: (data['created_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'permissions': permissions.toMap(),
      'user_count': userCount,
      'created_at': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}

class AppUser {
  final String uid;
  final String name;
  final String firstName;
  final String lastName;
  final String email;
  final UserRole role;
  final String? customRoleId;
  final String? teamId;
  final String? groupId;
  final bool isActive;
  final bool isAdmin;
  final String? phone;
  final String? city;
  final String? country;
  final String? address;
  final String? tag;
  final String? profileImageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLoginAt;
  final String? createdBy;

  const AppUser({
    required this.uid,
    required this.name,
    this.firstName = '',
    this.lastName = '',
    required this.email,
    required this.role,
    this.customRoleId,
    this.teamId,
    this.groupId,
    this.isActive = true,
    this.isAdmin = false,
    this.phone,
    this.city,
    this.country,
    this.address,
    this.tag,
    this.profileImageUrl,
    this.createdAt,
    this.updatedAt,
    this.lastLoginAt,
    this.createdBy,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      name: data['display_name'] ?? '',
      firstName: data['first_name'] ?? '',
      lastName: data['last_name'] ?? '',
      email: data['email'] ?? '',
      role: UserRoleX.fromSnakeCase(data['role'] ?? 'member'),
      customRoleId: data['custom_role_id'],
      teamId: data['team_id'],
      groupId: data['group_id'],
      isActive: data['is_active'] ?? true,
      isAdmin: data['is_admin'] ?? false,
      phone: data['phone'],
      city: data['city'],
      country: data['country'],
      address: data['address'],
      tag: data['tag'],
      profileImageUrl: data['profile_image_url'],
      createdAt: (data['created_at'] as Timestamp?)?.toDate(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate(),
      lastLoginAt: (data['last_login_at'] as Timestamp?)?.toDate(),
      createdBy: data['created_by'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'display_name': name,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'role': role.toSnakeCase(),
      'custom_role_id': customRoleId,
      'team_id': teamId,
      'group_id': groupId,
      'is_active': isActive,
      'is_admin': isAdmin,
      'phone': phone,
      'city': city,
      'country': country,
      'address': address,
      'tag': tag,
      'profile_image_url': profileImageUrl,
      'created_at': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'last_login_at': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
      'created_by': createdBy,
    };
  }

  AppUser copyWith({
    String? uid,
    String? name,
    String? firstName,
    String? lastName,
    String? email,
    UserRole? role,
    String? customRoleId,
    String? teamId,
    String? groupId,
    bool? isActive,
    bool? isAdmin,
    String? phone,
    String? city,
    String? country,
    String? address,
    String? tag,
    String? profileImageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
    String? createdBy,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      role: role ?? this.role,
      customRoleId: customRoleId ?? this.customRoleId,
      teamId: teamId ?? this.teamId,
      groupId: groupId ?? this.groupId,
      isActive: isActive ?? this.isActive,
      isAdmin: isAdmin ?? this.isAdmin,
      phone: phone ?? this.phone,
      city: city ?? this.city,
      country: country ?? this.country,
      address: address ?? this.address,
      tag: tag ?? this.tag,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
