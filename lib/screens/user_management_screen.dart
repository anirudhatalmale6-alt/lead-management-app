import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  // Toggle this to true when Firebase is not configured / for demo purposes.
  final bool _useMockData = false;

  // ---------------------------------------------------------------------------
  // Mock data
  // ---------------------------------------------------------------------------

  final List<Map<String, dynamic>> _mockTeams = [
    {'id': 'team_1', 'name': 'North Region'},
    {'id': 'team_2', 'name': 'South Region'},
    {'id': 'team_3', 'name': 'Enterprise'},
  ];

  final List<Map<String, dynamic>> _mockGroups = [
    {'id': 'grp_1', 'name': 'Group Alpha', 'team_id': 'team_1'},
    {'id': 'grp_2', 'name': 'Group Beta', 'team_id': 'team_1'},
    {'id': 'grp_3', 'name': 'Group Gamma', 'team_id': 'team_2'},
    {'id': 'grp_4', 'name': 'Group Delta', 'team_id': 'team_3'},
  ];

  late List<AppUser> _mockUsers;

  @override
  void initState() {
    super.initState();
    _mockUsers = [
      AppUser(
        uid: 'u1',
        name: 'Alice Johnson',
        email: 'alice@company.com',
        role: UserRole.superAdmin,
        teamId: 'team_1',
        groupId: 'grp_1',
        isActive: true,
      ),
      AppUser(
        uid: 'u2',
        name: 'Bob Smith',
        email: 'bob@company.com',
        role: UserRole.admin,
        teamId: 'team_1',
        groupId: 'grp_2',
        isActive: true,
      ),
      AppUser(
        uid: 'u3',
        name: 'Carol Davis',
        email: 'carol@company.com',
        role: UserRole.manager,
        teamId: 'team_2',
        groupId: 'grp_3',
        isActive: true,
      ),
      AppUser(
        uid: 'u4',
        name: 'Dan Wilson',
        email: 'dan@company.com',
        role: UserRole.teamLead,
        teamId: 'team_2',
        groupId: 'grp_3',
        isActive: true,
      ),
      AppUser(
        uid: 'u5',
        name: 'Eve Martinez',
        email: 'eve@company.com',
        role: UserRole.coordinator,
        teamId: 'team_3',
        groupId: 'grp_4',
        isActive: false,
      ),
      AppUser(
        uid: 'u6',
        name: 'Frank Brown',
        email: 'frank@company.com',
        role: UserRole.member,
        teamId: 'team_3',
        groupId: 'grp_4',
        isActive: true,
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _teamNameById(String? teamId) {
    if (teamId == null) return 'Unassigned';
    final match = _mockTeams.where((t) => t['id'] == teamId);
    return match.isNotEmpty ? match.first['name'] as String : 'Unknown';
  }

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return Colors.red.shade700;
      case UserRole.admin:
        return Colors.deepPurple;
      case UserRole.manager:
        return Colors.indigo;
      case UserRole.teamLead:
        return Colors.teal;
      case UserRole.coordinator:
        return Colors.orange.shade800;
      case UserRole.member:
        return Colors.blueGrey;
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Add User',
            onPressed: () => _showAddUserDialog(context),
          ),
        ],
      ),
      body: _useMockData ? _buildMockList() : _buildFirestoreList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Mock list
  // ---------------------------------------------------------------------------

  Widget _buildMockList() {
    if (_mockUsers.isEmpty) {
      return const Center(child: Text('No users found.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _mockUsers.length,
      itemBuilder: (context, index) {
        final user = _mockUsers[index];
        return _buildUserCard(user);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Firestore list
  // ---------------------------------------------------------------------------

  Widget _buildFirestoreList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No users found.'));
        }

        final users = docs.map((doc) => AppUser.fromFirestore(doc)).toList();
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: users.length,
          itemBuilder: (context, index) => _buildUserCard(users[index]),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // User card
  // ---------------------------------------------------------------------------

  Widget _buildUserCard(AppUser user) {
    final theme = Theme.of(context);
    final roleColor = _roleColor(user.role);
    final initials = user.name.isNotEmpty ? user.name[0].toUpperCase() : '?';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: roleColor.withOpacity(0.15),
          child: Text(
            initials,
            style: TextStyle(
              color: roleColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                user.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: roleColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                user.role.label,
                style: TextStyle(
                  color: roleColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(Icons.email_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  user.email,
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.group_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                _teamNameById(user.teamId),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: user.isActive ? Colors.green : Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              user.isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                fontSize: 11,
                color: user.isActive ? Colors.green.shade700 : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        onTap: () => _showEditUserDialog(context, user),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Add user dialog
  // ---------------------------------------------------------------------------

  void _showAddUserDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    UserRole selectedRole = UserRole.member;
    String? selectedTeamId;
    String? selectedGroupId;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setDialogState) {
            final availableGroups = selectedTeamId != null
                ? _mockGroups.where((g) => g['team_id'] == selectedTeamId).toList()
                : <Map<String, dynamic>>[];

            return AlertDialog(
              title: const Text('Add New User'),
              content: SizedBox(
                width: 400,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Display name
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Display Name',
                            prefixIcon: Icon(Icons.person_outlined),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),

                        // Email
                        TextFormField(
                          controller: emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required';
                            if (!v.contains('@')) return 'Invalid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Password
                        TextFormField(
                          controller: passwordCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock_outlined),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required';
                            if (v.length < 6) return 'Min 6 characters';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Role dropdown
                        DropdownButtonFormField<UserRole>(
                          value: selectedRole,
                          decoration: const InputDecoration(
                            labelText: 'Role',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          items: UserRole.values.map((role) {
                            return DropdownMenuItem(
                              value: role,
                              child: Text(role.label),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setDialogState(() => selectedRole = v);
                            }
                          },
                        ),
                        const SizedBox(height: 12),

                        // Team dropdown
                        DropdownButtonFormField<String>(
                          value: selectedTeamId,
                          decoration: const InputDecoration(
                            labelText: 'Team',
                            prefixIcon: Icon(Icons.group_work_outlined),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('No Team'),
                            ),
                            ..._mockTeams.map((t) {
                              return DropdownMenuItem(
                                value: t['id'] as String,
                                child: Text(t['name'] as String),
                              );
                            }),
                          ],
                          onChanged: (v) {
                            setDialogState(() {
                              selectedTeamId = v;
                              selectedGroupId = null;
                            });
                          },
                        ),
                        const SizedBox(height: 12),

                        // Group dropdown
                        DropdownButtonFormField<String>(
                          value: selectedGroupId,
                          decoration: const InputDecoration(
                            labelText: 'Group',
                            prefixIcon: Icon(Icons.workspaces_outlined),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('No Group'),
                            ),
                            ...availableGroups.map((g) {
                              return DropdownMenuItem(
                                value: g['id'] as String,
                                child: Text(g['name'] as String),
                              );
                            }),
                          ],
                          onChanged: (v) {
                            setDialogState(() => selectedGroupId = v);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx2).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isLoading = true);

                          if (_useMockData) {
                            // Add to mock list
                            final newUser = AppUser(
                              uid: 'u${DateTime.now().millisecondsSinceEpoch}',
                              name: nameCtrl.text.trim(),
                              email: emailCtrl.text.trim(),
                              role: selectedRole,
                              teamId: selectedTeamId,
                              groupId: selectedGroupId,
                              isActive: true,
                              createdAt: DateTime.now(),
                            );
                            setState(() => _mockUsers.add(newUser));
                            if (ctx2.mounted) Navigator.of(ctx2).pop();
                            _showSnackBar('User created successfully');
                          } else {
                            try {
                              // Create Firebase Auth user
                              final cred = await _authService.signUp(
                                emailCtrl.text.trim(),
                                passwordCtrl.text.trim(),
                              );
                              // Create Firestore user document
                              await _authService.createUserDocument(
                                cred.user!.uid,
                                emailCtrl.text.trim(),
                                nameCtrl.text.trim(),
                                selectedRole,
                                teamId: selectedTeamId,
                                groupId: selectedGroupId,
                              );
                              if (ctx2.mounted) Navigator.of(ctx2).pop();
                              _showSnackBar('User created successfully');
                            } catch (e) {
                              setDialogState(() => isLoading = false);
                              _showSnackBar('Error: $e', isError: true);
                            }
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create User'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Edit user dialog
  // ---------------------------------------------------------------------------

  void _showEditUserDialog(BuildContext context, AppUser user) {
    final nameCtrl = TextEditingController(text: user.name);
    UserRole selectedRole = user.role;
    String? selectedTeamId = user.teamId;
    String? selectedGroupId = user.groupId;
    bool isActive = user.isActive;
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setSheetState) {
            final theme = Theme.of(context);
            final availableGroups = selectedTeamId != null
                ? _mockGroups.where((g) => g['team_id'] == selectedTeamId).toList()
                : <Map<String, dynamic>>[];

            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx2).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: _roleColor(user.role).withOpacity(0.15),
                          child: Text(
                            user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: _roleColor(user.role),
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Edit User',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                user.email,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Display name
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Display Name',
                        prefixIcon: Icon(Icons.person_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Role
                    DropdownButtonFormField<UserRole>(
                      value: selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      items: UserRole.values.map((role) {
                        return DropdownMenuItem(
                          value: role,
                          child: Text(role.label),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setSheetState(() => selectedRole = v);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Team
                    DropdownButtonFormField<String>(
                      value: selectedTeamId,
                      decoration: const InputDecoration(
                        labelText: 'Team',
                        prefixIcon: Icon(Icons.group_work_outlined),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('No Team'),
                        ),
                        ..._mockTeams.map((t) {
                          return DropdownMenuItem(
                            value: t['id'] as String,
                            child: Text(t['name'] as String),
                          );
                        }),
                      ],
                      onChanged: (v) {
                        setSheetState(() {
                          selectedTeamId = v;
                          selectedGroupId = null;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Group
                    DropdownButtonFormField<String>(
                      value: selectedGroupId,
                      decoration: const InputDecoration(
                        labelText: 'Group',
                        prefixIcon: Icon(Icons.workspaces_outlined),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('No Group'),
                        ),
                        ...availableGroups.map((g) {
                          return DropdownMenuItem(
                            value: g['id'] as String,
                            child: Text(g['name'] as String),
                          );
                        }),
                      ],
                      onChanged: (v) {
                        setSheetState(() => selectedGroupId = v);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Active toggle
                    SwitchListTile(
                      title: const Text('Active Status'),
                      subtitle: Text(isActive ? 'User is active' : 'User is inactive'),
                      value: isActive,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (v) {
                        setSheetState(() => isActive = v);
                      },
                    ),
                    const SizedBox(height: 20),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: isLoading
                            ? null
                            : () async {
                                setSheetState(() => isLoading = true);

                                if (_useMockData) {
                                  final idx = _mockUsers.indexWhere(
                                    (u) => u.uid == user.uid,
                                  );
                                  if (idx != -1) {
                                    setState(() {
                                      _mockUsers[idx] = user.copyWith(
                                        name: nameCtrl.text.trim(),
                                        role: selectedRole,
                                        teamId: selectedTeamId,
                                        groupId: selectedGroupId,
                                        isActive: isActive,
                                      );
                                    });
                                  }
                                  if (ctx2.mounted) Navigator.of(ctx2).pop();
                                  _showSnackBar('User updated successfully');
                                } else {
                                  try {
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(user.uid)
                                        .update({
                                      'display_name': nameCtrl.text.trim(),
                                      'role': selectedRole.toSnakeCase(),
                                      'team_id': selectedTeamId,
                                      'group_id': selectedGroupId,
                                      'is_active': isActive,
                                      'updated_at': FieldValue.serverTimestamp(),
                                    });
                                    if (ctx2.mounted) Navigator.of(ctx2).pop();
                                    _showSnackBar('User updated successfully');
                                  } catch (e) {
                                    setSheetState(() => isLoading = false);
                                    _showSnackBar('Error: $e', isError: true);
                                  }
                                }
                              },
                        child: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Save Changes'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Snack bar helper
  // ---------------------------------------------------------------------------

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
