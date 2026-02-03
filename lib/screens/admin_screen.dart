import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class AdminScreen extends StatefulWidget {
  final AppUser? currentUser;

  const AdminScreen({super.key, this.currentUser});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  late TabController _tabController;

  final bool _useMockData = false;

  /// Whether current user can create/edit/delete in admin module
  bool get _canModify {
    final user = widget.currentUser;
    if (user == null) return false;
    return user.role == UserRole.superAdmin || user.role == UserRole.admin;
  }

  /// Whether current user is a Manager (view-only for teams/groups but no create/edit/delete)
  bool get _isManager {
    final user = widget.currentUser;
    if (user == null) return false;
    return user.role == UserRole.manager;
  }

  // Mock data
  List<Map<String, dynamic>> _mockTeams = [];
  List<Map<String, dynamic>> _mockGroups = [];
  List<Map<String, dynamic>> _mockRoles = [];
  List<AppUser> _mockUsers = [];
  List<Map<String, dynamic>> _allUsers = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initMockData();
    _loadUsersFromFirestore();
  }

  void _initMockData() {
    _mockTeams = [
      {
        'id': 'team_1',
        'name': 'North Region',
        'admin_uid': 'u1',
        'admin_name': 'Alice',
        'manager_uid': 'm1',
        'manager_name': 'Bob',
        'tl_uid': 'tl1',
        'tl_name': 'Charlie',
        'status': true,
      },
      {
        'id': 'team_2',
        'name': 'South Region',
        'admin_uid': 'u2',
        'admin_name': 'David',
        'manager_uid': 'm2',
        'manager_name': 'Eve',
        'tl_uid': 'tl2',
        'tl_name': 'Frank',
        'status': true,
      },
    ];

    _mockGroups = [
      {
        'id': 'grp_1',
        'name': 'Group Alpha',
        'sub_group_name': 'Sub Alpha',
        'sub_group_manager': 'George',
        'tl_name': 'Helen',
        'coordinator_name': 'Ivan',
        'members': ['Emp Reyaz (ID)', 'Eja (2)', 'Sanket (7)'],
        'status': true,
        'created_at': DateTime.now().subtract(const Duration(days: 30)),
      },
    ];

    _mockRoles = [
      {'id': 'role_1', 'name': 'Emp', 'user_count': 20, 'permissions': RolePermissions(leadViewOwn: true)},
      {'id': 'role_2', 'name': 'Coordinator', 'user_count': 11, 'permissions': RolePermissions(leadViewOwn: true, leadEditOwn: true, leadViewGroup: true)},
      {'id': 'role_3', 'name': 'TL', 'user_count': 4, 'permissions': RolePermissions(leadViewOwn: true, leadEditOwn: true, leadCreate: true, leadViewGroup: true, leadViewTeam: true)},
      {'id': 'role_4', 'name': 'Manager', 'user_count': 4, 'permissions': RolePermissions(leadViewOwn: true, leadEditOwn: true, leadCreate: true, leadDelete: true, leadViewGroup: true, leadViewTeam: true)},
      {'id': 'role_5', 'name': 'Admin', 'user_count': 2, 'permissions': RolePermissions(leadViewOwn: true, leadEditOwn: true, leadCreate: true, leadDelete: true, leadViewGroup: true, leadViewTeam: true, leadViewGlobal: true)},
    ];

    _mockUsers = [
      AppUser(uid: 'u1', name: 'Alice Johnson', firstName: 'Alice', lastName: 'Johnson', email: 'alice@company.com', role: UserRole.superAdmin, isActive: true, phone: '9876543210', city: 'Mumbai', country: 'India', tag: 'Agent'),
      AppUser(uid: 'u2', name: 'Bob Smith', firstName: 'Bob', lastName: 'Smith', email: 'bob@company.com', role: UserRole.admin, isActive: true, phone: '9876543211', city: 'Delhi', country: 'India', tag: 'Emp'),
      AppUser(uid: 'u3', name: 'Carol Davis', firstName: 'Carol', lastName: 'Davis', email: 'carol@company.com', role: UserRole.manager, isActive: true, phone: '9876543212', city: 'Bangalore', country: 'India', tag: 'Freelancer'),
      AppUser(uid: 'u4', name: 'Dan Wilson', firstName: 'Dan', lastName: 'Wilson', email: 'dan@company.com', role: UserRole.teamLead, isActive: true),
      AppUser(uid: 'u5', name: 'Eve Martinez', firstName: 'Eve', lastName: 'Martinez', email: 'eve@company.com', role: UserRole.coordinator, isActive: false),
      AppUser(uid: 'u6', name: 'Frank Brown', firstName: 'Frank', lastName: 'Brown', email: 'frank@company.com', role: UserRole.member, isActive: true),
    ];
  }

  Future<void> _loadUsersFromFirestore() async {
    if (_useMockData) return;
    try {
      final users = await _firestoreService.getAllUsers();
      if (mounted) {
        setState(() {
          _allUsers = users;
          // Convert Firestore users to AppUser objects and merge with mock
          if (users.isNotEmpty) {
            final firestoreUsers = users.map((u) {
              final roleStr = (u['role'] ?? 'member') as String;
              return AppUser(
                uid: (u['uid'] ?? u['id'] ?? '') as String,
                name: (u['display_name'] ?? u['name'] ?? u['email'] ?? '') as String,
                firstName: (u['first_name'] ?? '') as String,
                lastName: (u['last_name'] ?? '') as String,
                email: (u['email'] ?? '') as String,
                role: UserRoleX.fromSnakeCase(roleStr),
                isActive: (u['is_active'] ?? true) as bool,
                phone: (u['phone'] ?? '') as String?,
                city: (u['city'] ?? '') as String?,
                country: (u['country'] ?? '') as String?,
                address: (u['address'] ?? '') as String?,
                tag: (u['tag'] ?? '') as String?,
              );
            }).toList();
            // Use Firestore users if available, keep mock as fallback
            _mockUsers = firestoreUsers.isNotEmpty ? firestoreUsers : _mockUsers;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading users: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Menu'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.group_work), text: 'Team'),
            Tab(icon: Icon(Icons.workspaces), text: 'Group'),
            Tab(icon: Icon(Icons.admin_panel_settings), text: 'Role'),
            Tab(icon: Icon(Icons.people), text: 'User/Member/Emp'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTeamTab(),
          _buildGroupTab(),
          _buildRoleTab(),
          _buildUserTab(),
        ],
      ),
    );
  }

  // ===========================================================================
  // TEAM TAB
  // ===========================================================================
  Widget _buildTeamTab() {
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text('Team List', style: Theme.of(context).textTheme.titleLarge),
                  if (!_canModify) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('View Only', style: TextStyle(fontSize: 11, color: Colors.orange.shade800, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: _useMockData ? _buildMockTeamList() : _buildFirestoreTeamList(),
            ),
          ],
        ),
        if (_canModify)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.extended(
              heroTag: 'addTeam',
              onPressed: () => _showCreateTeamDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Create Team'),
            ),
          ),
      ],
    );
  }

  Widget _buildMockTeamList() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Team Name')),
            DataColumn(label: Text('Team Admin')),
            DataColumn(label: Text('Team Manager')),
            DataColumn(label: Text('Team TL')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Option')),
          ],
          rows: _mockTeams.map((team) {
            return DataRow(cells: [
              DataCell(Text(team['name'] ?? '')),
              DataCell(Text(team['admin_name'] ?? 'N/A')),
              DataCell(Text(team['manager_name'] ?? 'N/A')),
              DataCell(Text(team['tl_name'] ?? 'N/A')),
              DataCell(_buildStatusChip(team['status'] ?? false)),
              DataCell(_canModify
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _showEditTeamDialog(team)),
                      IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => _confirmDeleteTeam(team['id'], team['name'])),
                    ],
                  )
                : const Text('-', style: TextStyle(color: Colors.grey)),
              ),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFirestoreTeamList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.getTeamsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const Center(child: Text('No teams found.'));

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Team Name')),
                DataColumn(label: Text('Team Admin')),
                DataColumn(label: Text('Team Manager')),
                DataColumn(label: Text('Team TL')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Option')),
              ],
              rows: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                data['id'] = doc.id;
                return DataRow(cells: [
                  DataCell(Text(data['name'] ?? '')),
                  DataCell(Text(data['admin_name'] ?? 'N/A')),
                  DataCell(Text(data['manager_name'] ?? 'N/A')),
                  DataCell(Text(data['tl_name'] ?? 'N/A')),
                  DataCell(_buildStatusChip(data['status'] ?? false)),
                  DataCell(_canModify
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _showEditTeamDialog(data)),
                          IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => _confirmDeleteTeam(data['id'], data['name'])),
                        ],
                      )
                    : const Text('-', style: TextStyle(color: Colors.grey)),
                  ),
                ]);
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  void _showCreateTeamDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    String? selectedManager, selectedTL, selectedAdmin;
    bool status = true;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) => AlertDialog(
          title: const Text('Create Team'),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Team Name', prefixIcon: Icon(Icons.group_work)),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildUserDropdown('Select Manager', selectedManager, (v) => setDialogState(() => selectedManager = v), ['manager', 'admin', 'super_admin']),
                    const SizedBox(height: 12),
                    _buildUserDropdown('Select TL', selectedTL, (v) => setDialogState(() => selectedTL = v), ['team_lead', 'coordinator', 'manager']),
                    const SizedBox(height: 12),
                    _buildUserDropdown('Select Admin', selectedAdmin, (v) => setDialogState(() => selectedAdmin = v), ['admin', 'super_admin']),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Status'),
                      subtitle: Text(status ? 'Active' : 'Deactive'),
                      value: status,
                      onChanged: (v) => setDialogState(() => status = v),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('Cancel')),
            FilledButton(
              onPressed: isLoading ? null : () async {
                if (!formKey.currentState!.validate()) return;
                setDialogState(() => isLoading = true);
                // Get user names for display
                String? managerName = _getUserNameByUid(selectedManager);
                String? tlName = _getUserNameByUid(selectedTL);
                String? adminName = _getUserNameByUid(selectedAdmin);

                if (_useMockData) {
                  setState(() {
                    _mockTeams.add({
                      'id': 'team_${DateTime.now().millisecondsSinceEpoch}',
                      'name': nameCtrl.text.trim(),
                      'manager_uid': selectedManager,
                      'manager_name': managerName ?? 'N/A',
                      'tl_uid': selectedTL,
                      'tl_name': tlName ?? 'N/A',
                      'admin_uid': selectedAdmin,
                      'admin_name': adminName ?? 'N/A',
                      'status': status,
                    });
                  });
                  Navigator.pop(ctx2);
                  _showSnackBar('Team created');
                } else {
                  try {
                    await FirebaseFirestore.instance.collection('teams').add({
                      'name': nameCtrl.text.trim(),
                      'manager_uid': selectedManager,
                      'manager_name': managerName ?? 'N/A',
                      'tl_uid': selectedTL,
                      'tl_name': tlName ?? 'N/A',
                      'admin_uid': selectedAdmin,
                      'admin_name': adminName ?? 'N/A',
                      'status': status,
                      'created_at': FieldValue.serverTimestamp(),
                    });
                    Navigator.pop(ctx2);
                    _showSnackBar('Team created');
                  } catch (e) {
                    setDialogState(() => isLoading = false);
                    _showSnackBar('Error: $e', isError: true);
                  }
                }
              },
              child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTeamDialog(Map<String, dynamic> team) {
    final nameCtrl = TextEditingController(text: team['name']);
    String? selectedManager = team['manager_uid'];
    String? selectedTL = team['tl_uid'];
    String? selectedAdmin = team['admin_uid'];
    bool status = team['status'] ?? true;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) => AlertDialog(
          title: const Text('Edit Team'),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Team Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.group_work),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildUserDropdown('Select Manager', selectedManager, (v) => setDialogState(() => selectedManager = v), ['manager', 'admin', 'super_admin']),
                  const SizedBox(height: 16),
                  _buildUserDropdown('Select TL', selectedTL, (v) => setDialogState(() => selectedTL = v), ['team_lead', 'coordinator', 'manager']),
                  const SizedBox(height: 16),
                  _buildUserDropdown('Select Admin', selectedAdmin, (v) => setDialogState(() => selectedAdmin = v), ['admin', 'super_admin']),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Status'),
                    subtitle: Text(status ? 'Active' : 'Inactive'),
                    value: status,
                    onChanged: (v) => setDialogState(() => status = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('Cancel')),
            FilledButton(
              onPressed: isLoading ? null : () async {
                setDialogState(() => isLoading = true);

                // Get user names for display
                String? managerName = _getUserNameByUid(selectedManager);
                String? tlName = _getUserNameByUid(selectedTL);
                String? adminName = _getUserNameByUid(selectedAdmin);

                if (_useMockData) {
                  setState(() {
                    final idx = _mockTeams.indexWhere((t) => t['id'] == team['id']);
                    if (idx != -1) {
                      _mockTeams[idx] = {
                        ...team,
                        'name': nameCtrl.text.trim(),
                        'manager_uid': selectedManager,
                        'manager_name': managerName ?? 'N/A',
                        'tl_uid': selectedTL,
                        'tl_name': tlName ?? 'N/A',
                        'admin_uid': selectedAdmin,
                        'admin_name': adminName ?? 'N/A',
                        'status': status,
                      };
                    }
                  });
                  Navigator.pop(ctx2);
                  _showSnackBar('Team updated');
                } else {
                  try {
                    await FirebaseFirestore.instance.collection('teams').doc(team['id']).update({
                      'name': nameCtrl.text.trim(),
                      'manager_uid': selectedManager,
                      'manager_name': managerName ?? 'N/A',
                      'tl_uid': selectedTL,
                      'tl_name': tlName ?? 'N/A',
                      'admin_uid': selectedAdmin,
                      'admin_name': adminName ?? 'N/A',
                      'status': status,
                      'updated_at': FieldValue.serverTimestamp(),
                    });
                    Navigator.pop(ctx2);
                    _showSnackBar('Team updated');
                  } catch (e) {
                    setDialogState(() => isLoading = false);
                    _showSnackBar('Error: $e', isError: true);
                  }
                }
              },
              child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteTeam(String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Team'),
        content: Text('Delete "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              if (_useMockData) {
                setState(() => _mockTeams.removeWhere((t) => t['id'] == id));
              } else {
                await FirebaseFirestore.instance.collection('teams').doc(id).delete();
              }
              _showSnackBar('Team deleted');
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // GROUP TAB (Group is part of Team - no sub-groups)
  // ===========================================================================
  Widget _buildGroupTab() {
    final dateFormat = DateFormat('dd MMM yyyy');
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text('Group List', style: Theme.of(context).textTheme.titleLarge),
                  if (!_canModify) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('View Only', style: TextStyle(fontSize: 11, color: Colors.orange.shade800, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('ID')),
                      DataColumn(label: Text('Group Name')),
                      DataColumn(label: Text('Team')),
                      DataColumn(label: Text('Manager')),
                      DataColumn(label: Text('Team Leader')),
                      DataColumn(label: Text('Coordinator')),
                      DataColumn(label: Text('Members / Employees')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Created At')),
                      DataColumn(label: Text('Options')),
                    ],
                    rows: _mockGroups.asMap().entries.map((entry) {
                      final idx = entry.key + 1;
                      final grp = entry.value;
                      // Get member names for display
                      final memberDisplay = grp['member_names'] != null
                          ? (grp['member_names'] as List).join(', ')
                          : (grp['members'] as List?)?.map((uid) => _getUserNameByUid(uid as String) ?? uid).join(', ') ?? '';
                      return DataRow(cells: [
                        DataCell(SelectableText('$idx')),
                        DataCell(SelectableText(grp['name'] ?? '')),
                        DataCell(SelectableText(grp['team_name'] ?? 'N/A')),
                        DataCell(SelectableText(grp['manager_name'] ?? _getUserNameByUid(grp['manager_uid']) ?? 'N/A')),
                        DataCell(SelectableText(grp['tl_name'] ?? _getUserNameByUid(grp['tl_uid']) ?? 'N/A')),
                        DataCell(SelectableText(grp['coordinator_name'] ?? _getUserNameByUid(grp['coordinator_uid']) ?? 'N/A')),
                        DataCell(SizedBox(
                          width: 200,
                          child: SelectableText(memberDisplay.isNotEmpty ? memberDisplay : 'N/A', maxLines: 2),
                        )),
                        DataCell(_buildStatusChip(grp['status'] ?? false)),
                        DataCell(SelectableText(grp['created_at'] != null ? dateFormat.format(grp['created_at']) : '')),
                        DataCell(_canModify
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _showEditGroupDialog(grp)),
                                IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => _confirmDeleteGroup(grp['id'], grp['name'])),
                              ],
                            )
                          : const Text('-', style: TextStyle(color: Colors.grey)),
                        ),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_canModify)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.extended(
              heroTag: 'addGroup',
              onPressed: () => _showAddGroupDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Group'),
            ),
          ),
      ],
    );
  }

  void _showAddGroupDialog() {
    final nameCtrl = TextEditingController();
    String? selectedTeam, manager, tl, coordinator;
    List<String> selectedMembers = [];
    bool status = true;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) => AlertDialog(
          title: const Text('Add Group'),
          content: SizedBox(
            width: 500,
            height: 550,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Group Name *',
                      prefixIcon: Icon(Icons.group),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Team selection dropdown - auto-fills Manager and TL from team
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestoreService.getTeamsStream(),
                    builder: (context, snapshot) {
                      List<DropdownMenuItem<String>> teamItems = [
                        const DropdownMenuItem(value: null, child: Text('Select Team')),
                      ];
                      Map<String, Map<String, dynamic>> teamDataMap = {};
                      if (snapshot.hasData) {
                        for (final doc in snapshot.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          teamItems.add(DropdownMenuItem(
                            value: doc.id,
                            child: Text(data['name'] ?? doc.id),
                          ));
                          teamDataMap[doc.id] = data;
                        }
                      }
                      return DropdownButtonFormField<String>(
                        value: selectedTeam,
                        decoration: const InputDecoration(
                          labelText: 'Belongs to Team',
                          prefixIcon: Icon(Icons.group_work),
                          border: OutlineInputBorder(),
                        ),
                        items: teamItems,
                        onChanged: (v) {
                          setDialogState(() {
                            selectedTeam = v;
                            // Auto-fill Manager and TL from team data
                            if (v != null && teamDataMap.containsKey(v)) {
                              final teamData = teamDataMap[v]!;
                              manager = teamData['manager_uid'] as String?;
                              tl = teamData['tl_uid'] as String?;
                            }
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildUserDropdown('Manager', manager, (v) => setDialogState(() => manager = v), ['manager', 'admin', 'super_admin']),
                  const SizedBox(height: 16),
                  _buildUserDropdown('Team Leader (TL)', tl, (v) => setDialogState(() => tl = v), ['team_lead', 'coordinator', 'manager']),
                  const SizedBox(height: 16),
                  _buildUserDropdown('Coordinator', coordinator, (v) => setDialogState(() => coordinator = v), ['coordinator', 'team_lead', 'member']),
                  const SizedBox(height: 16),
                  const Text('Select Members / Employees:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  // Show all users
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: const BoxConstraints(maxHeight: 150),
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: _mockUsers.map((u) {
                          final selected = selectedMembers.contains(u.uid);
                          return FilterChip(
                            avatar: CircleAvatar(
                              radius: 12,
                              child: Text(u.name.isNotEmpty ? u.name[0] : '?', style: const TextStyle(fontSize: 10)),
                            ),
                            label: Text('${u.name} (${u.role.label})'),
                            selected: selected,
                            onSelected: (v) => setDialogState(() {
                              if (v) selectedMembers.add(u.uid);
                              else selectedMembers.remove(u.uid);
                            }),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Status'),
                    subtitle: Text(status ? 'Active' : 'Inactive'),
                    value: status,
                    onChanged: (v) => setDialogState(() => status = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('Cancel')),
            FilledButton(
              onPressed: isLoading ? null : () async {
                if (nameCtrl.text.trim().isEmpty) {
                  _showSnackBar('Please enter group name', isError: true);
                  return;
                }
                setDialogState(() => isLoading = true);

                // Get names for display
                String? managerName = _getUserNameByUid(manager);
                String? tlName = _getUserNameByUid(tl);
                String? coordinatorName = _getUserNameByUid(coordinator);
                List<String> memberNames = _getMemberNamesByUids(selectedMembers);
                String? teamName;

                // Get team name
                if (selectedTeam != null) {
                  final teamDoc = await FirebaseFirestore.instance.collection('teams').doc(selectedTeam).get();
                  if (teamDoc.exists) {
                    teamName = (teamDoc.data() as Map<String, dynamic>)['name'];
                  }
                }

                final groupData = {
                  'name': nameCtrl.text.trim(),
                  'team_id': selectedTeam,
                  'team_name': teamName ?? 'N/A',
                  'manager_uid': manager,
                  'manager_name': managerName ?? 'N/A',
                  'tl_uid': tl,
                  'tl_name': tlName ?? 'N/A',
                  'coordinator_uid': coordinator,
                  'coordinator_name': coordinatorName ?? 'N/A',
                  'members': selectedMembers,
                  'member_names': memberNames,
                  'status': status,
                  'created_at': DateTime.now(),
                };

                if (_useMockData) {
                  groupData['id'] = 'grp_${DateTime.now().millisecondsSinceEpoch}';
                  setState(() {
                    _mockGroups.add(groupData);
                  });
                } else {
                  try {
                    await FirebaseFirestore.instance.collection('groups').add({
                      ...groupData,
                      'created_at': FieldValue.serverTimestamp(),
                    });
                    // Also add to local mock for display
                    groupData['id'] = 'grp_${DateTime.now().millisecondsSinceEpoch}';
                    setState(() => _mockGroups.add(groupData));
                  } catch (e) {
                    setDialogState(() => isLoading = false);
                    _showSnackBar('Error: $e', isError: true);
                    return;
                  }
                }
                Navigator.pop(ctx2);
                _showSnackBar('Group created');
              },
              child: isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditGroupDialog(Map<String, dynamic> grp) {
    final nameCtrl = TextEditingController(text: grp['name']);
    String? selectedTeam = grp['team_id'];
    String? manager = grp['manager_uid'];
    String? tl = grp['tl_uid'];
    String? coordinator = grp['coordinator_uid'];
    List<String> selectedMembers = List<String>.from(grp['members'] ?? []);
    bool status = grp['status'] ?? true;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) => AlertDialog(
          title: const Text('Edit Group'),
          content: SizedBox(
            width: 500,
            height: 550,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Group Name *',
                      prefixIcon: Icon(Icons.group),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Team selection dropdown - auto-fills Manager and TL from team
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestoreService.getTeamsStream(),
                    builder: (context, snapshot) {
                      List<DropdownMenuItem<String>> teamItems = [
                        const DropdownMenuItem(value: null, child: Text('Select Team')),
                      ];
                      Map<String, Map<String, dynamic>> teamDataMap = {};
                      if (snapshot.hasData) {
                        for (final doc in snapshot.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          teamItems.add(DropdownMenuItem(
                            value: doc.id,
                            child: Text(data['name'] ?? doc.id),
                          ));
                          teamDataMap[doc.id] = data;
                        }
                      }
                      return DropdownButtonFormField<String>(
                        value: selectedTeam,
                        decoration: const InputDecoration(
                          labelText: 'Belongs to Team',
                          prefixIcon: Icon(Icons.group_work),
                          border: OutlineInputBorder(),
                        ),
                        items: teamItems,
                        onChanged: (v) {
                          setDialogState(() {
                            selectedTeam = v;
                            // Auto-fill Manager and TL from team data
                            if (v != null && teamDataMap.containsKey(v)) {
                              final teamData = teamDataMap[v]!;
                              manager = teamData['manager_uid'] as String?;
                              tl = teamData['tl_uid'] as String?;
                            }
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildUserDropdown('Manager', manager, (v) => setDialogState(() => manager = v), ['manager', 'admin', 'super_admin']),
                  const SizedBox(height: 16),
                  _buildUserDropdown('Team Leader (TL)', tl, (v) => setDialogState(() => tl = v), ['team_lead', 'coordinator', 'manager']),
                  const SizedBox(height: 16),
                  _buildUserDropdown('Coordinator', coordinator, (v) => setDialogState(() => coordinator = v), ['coordinator', 'team_lead', 'member']),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Members / Employees:', style: TextStyle(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      TextButton.icon(
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text('Add New'),
                        onPressed: () {
                          // Show user selection dialog to add more members
                          _showAddMemberToGroupDialog(selectedMembers, (newMembers) {
                            setDialogState(() => selectedMembers = newMembers);
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: const BoxConstraints(maxHeight: 150),
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: _mockUsers.map((u) {
                          final selected = selectedMembers.contains(u.uid);
                          return FilterChip(
                            avatar: CircleAvatar(
                              radius: 12,
                              child: Text(u.name.isNotEmpty ? u.name[0] : '?', style: const TextStyle(fontSize: 10)),
                            ),
                            label: Text('${u.name} (${u.role.label})'),
                            selected: selected,
                            onSelected: (v) => setDialogState(() {
                              if (v) selectedMembers.add(u.uid);
                              else selectedMembers.remove(u.uid);
                            }),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Status'),
                    subtitle: Text(status ? 'Active' : 'Inactive'),
                    value: status,
                    onChanged: (v) => setDialogState(() => status = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('Cancel')),
            FilledButton(
              onPressed: isLoading ? null : () async {
                if (nameCtrl.text.trim().isEmpty) {
                  _showSnackBar('Please enter group name', isError: true);
                  return;
                }
                setDialogState(() => isLoading = true);

                // Get names for display
                String? managerName = _getUserNameByUid(manager);
                String? tlName = _getUserNameByUid(tl);
                String? coordinatorName = _getUserNameByUid(coordinator);
                List<String> memberNames = _getMemberNamesByUids(selectedMembers);
                String? teamName;

                // Get team name
                if (selectedTeam != null) {
                  final teamDoc = await FirebaseFirestore.instance.collection('teams').doc(selectedTeam).get();
                  if (teamDoc.exists) {
                    teamName = (teamDoc.data() as Map<String, dynamic>)['name'];
                  }
                }

                setState(() {
                  final idx = _mockGroups.indexWhere((g) => g['id'] == grp['id']);
                  if (idx != -1) {
                    _mockGroups[idx] = {
                      ...grp,
                      'name': nameCtrl.text.trim(),
                      'team_id': selectedTeam,
                      'team_name': teamName ?? grp['team_name'] ?? 'N/A',
                      'manager_uid': manager,
                      'manager_name': managerName ?? 'N/A',
                      'tl_uid': tl,
                      'tl_name': tlName ?? 'N/A',
                      'coordinator_uid': coordinator,
                      'coordinator_name': coordinatorName ?? 'N/A',
                      'members': selectedMembers,
                      'member_names': memberNames,
                      'status': status,
                    };
                  }
                });

                if (!_useMockData && grp['id'] != null && !grp['id'].toString().startsWith('grp_')) {
                  try {
                    await FirebaseFirestore.instance.collection('groups').doc(grp['id']).update({
                      'name': nameCtrl.text.trim(),
                      'team_id': selectedTeam,
                      'team_name': teamName,
                      'manager_uid': manager,
                      'manager_name': managerName,
                      'tl_uid': tl,
                      'tl_name': tlName,
                      'coordinator_uid': coordinator,
                      'coordinator_name': coordinatorName,
                      'members': selectedMembers,
                      'member_names': memberNames,
                      'status': status,
                      'updated_at': FieldValue.serverTimestamp(),
                    });
                  } catch (e) {
                    debugPrint('Error updating group in Firestore: $e');
                  }
                }

                Navigator.pop(ctx2);
                _showSnackBar('Group updated');
              },
              child: isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMemberToGroupDialog(List<String> currentMembers, Function(List<String>) onUpdate) {
    List<String> tempMembers = List.from(currentMembers);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) => AlertDialog(
          title: const Text('Select Members'),
          content: SizedBox(
            width: 400,
            height: 400,
            child: Column(
              children: [
                Text('${tempMembers.length} members selected', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: _mockUsers.map((u) {
                      final selected = tempMembers.contains(u.uid);
                      return CheckboxListTile(
                        title: Text(u.name),
                        subtitle: Text('${u.email} • ${u.role.label}'),
                        value: selected,
                        onChanged: (v) => setDialogState(() {
                          if (v == true) tempMembers.add(u.uid);
                          else tempMembers.remove(u.uid);
                        }),
                        secondary: CircleAvatar(child: Text(u.name.isNotEmpty ? u.name[0] : '?')),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                onUpdate(tempMembers);
                Navigator.pop(ctx2);
              },
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteGroup(String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Group'),
        content: Text('Delete "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() => _mockGroups.removeWhere((g) => g['id'] == id));
              Navigator.pop(ctx);
              _showSnackBar('Group deleted');
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // ROLE TAB
  // ===========================================================================
  Widget _buildRoleTab() {
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Role List', style: Theme.of(context).textTheme.titleLarge),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Role Name')),
                    DataColumn(label: Text('Number of users')),
                    DataColumn(label: Text('Option')),
                  ],
                  rows: _mockRoles.map((role) {
                    return DataRow(cells: [
                      DataCell(Text(role['name'] ?? '')),
                      DataCell(Text('${role['user_count']}')),
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _showEditRoleDialog(role)),
                          IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => _confirmDeleteRole(role['id'], role['name'])),
                        ],
                      )),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            heroTag: 'addRole',
            onPressed: () => _showAddRoleDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Add Role'),
          ),
        ),
      ],
    );
  }

  void _showAddRoleDialog() {
    final nameCtrl = TextEditingController();
    RolePermissions perms = const RolePermissions();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) => AlertDialog(
          title: const Text('Add Role'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Role Name')),
                  const SizedBox(height: 16),
                  const Text('Features', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Lead', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  const Text('Capabilities (Check box permission)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  CheckboxListTile(title: const Text('View Own'), value: perms.leadViewOwn, onChanged: (v) => setDialogState(() => perms = perms.copyWith(leadViewOwn: v)), dense: true),
                  CheckboxListTile(title: const Text('Edit Own'), value: perms.leadEditOwn, onChanged: (v) => setDialogState(() => perms = perms.copyWith(leadEditOwn: v)), dense: true),
                  CheckboxListTile(title: const Text('Create'), value: perms.leadCreate, onChanged: (v) => setDialogState(() => perms = perms.copyWith(leadCreate: v)), dense: true),
                  CheckboxListTile(title: const Text('Delete'), value: perms.leadDelete, onChanged: (v) => setDialogState(() => perms = perms.copyWith(leadDelete: v)), dense: true),
                  CheckboxListTile(title: const Text('View Group'), value: perms.leadViewGroup, onChanged: (v) => setDialogState(() => perms = perms.copyWith(leadViewGroup: v)), dense: true),
                  CheckboxListTile(title: const Text('View Team'), value: perms.leadViewTeam, onChanged: (v) => setDialogState(() => perms = perms.copyWith(leadViewTeam: v)), dense: true),
                  CheckboxListTile(title: const Text('View Global'), value: perms.leadViewGlobal, onChanged: (v) => setDialogState(() => perms = perms.copyWith(leadViewGlobal: v)), dense: true),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                setState(() {
                  _mockRoles.add({
                    'id': 'role_${DateTime.now().millisecondsSinceEpoch}',
                    'name': nameCtrl.text.trim(),
                    'user_count': 0,
                    'permissions': perms,
                  });
                });
                Navigator.pop(ctx2);
                _showSnackBar('Role created');
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditRoleDialog(Map<String, dynamic> role) {
    final nameCtrl = TextEditingController(text: role['name']);
    RolePermissions perms = role['permissions'] ?? const RolePermissions();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) => AlertDialog(
          title: const Text('Edit Role'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Role Name')),
                  const SizedBox(height: 16),
                  const Text('Lead Permissions', style: TextStyle(fontWeight: FontWeight.bold)),
                  CheckboxListTile(title: const Text('View Own'), value: perms.leadViewOwn, onChanged: (v) => setDialogState(() => perms = perms.copyWith(leadViewOwn: v)), dense: true),
                  CheckboxListTile(title: const Text('Edit Own'), value: perms.leadEditOwn, onChanged: (v) => setDialogState(() => perms = perms.copyWith(leadEditOwn: v)), dense: true),
                  CheckboxListTile(title: const Text('Create'), value: perms.leadCreate, onChanged: (v) => setDialogState(() => perms = perms.copyWith(leadCreate: v)), dense: true),
                  CheckboxListTile(title: const Text('Delete'), value: perms.leadDelete, onChanged: (v) => setDialogState(() => perms = perms.copyWith(leadDelete: v)), dense: true),
                  CheckboxListTile(title: const Text('View Group'), value: perms.leadViewGroup, onChanged: (v) => setDialogState(() => perms = perms.copyWith(leadViewGroup: v)), dense: true),
                  CheckboxListTile(title: const Text('View Team'), value: perms.leadViewTeam, onChanged: (v) => setDialogState(() => perms = perms.copyWith(leadViewTeam: v)), dense: true),
                  CheckboxListTile(title: const Text('View Global'), value: perms.leadViewGlobal, onChanged: (v) => setDialogState(() => perms = perms.copyWith(leadViewGlobal: v)), dense: true),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                setState(() {
                  final idx = _mockRoles.indexWhere((r) => r['id'] == role['id']);
                  if (idx != -1) {
                    _mockRoles[idx]['name'] = nameCtrl.text.trim();
                    _mockRoles[idx]['permissions'] = perms;
                  }
                });
                Navigator.pop(ctx2);
                _showSnackBar('Role updated');
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteRole(String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Role'),
        content: Text('Delete "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() => _mockRoles.removeWhere((r) => r['id'] == id));
              Navigator.pop(ctx);
              _showSnackBar('Role deleted');
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // USER TAB
  // ===========================================================================
  Widget _buildUserTab() {
    final dateFormat = DateFormat('dd MMM yyyy HH:mm');
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('User / Member / Emp', style: Theme.of(context).textTheme.titleLarge),
            ),
            Expanded(
              child: _useMockData ? _buildMockUserTable(dateFormat) : _buildFirestoreUserTable(dateFormat),
            ),
          ],
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            heroTag: 'addMember',
            onPressed: () => _showAddMemberDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Add Member'),
          ),
        ),
      ],
    );
  }

  Widget _buildMockUserTable(DateFormat dateFormat) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          showCheckboxColumn: true,
          columns: const [
            DataColumn(label: Text('', )),  // Checkbox column
            DataColumn(label: Text('ID')),
            DataColumn(label: Text('Full Name')),
            DataColumn(label: Text('Mobile')),
            DataColumn(label: Text('Email')),
            DataColumn(label: Text('City')),
            DataColumn(label: Text('Country')),
            DataColumn(label: Text('Address')),
            DataColumn(label: Text('Tag')),
            DataColumn(label: Text('Role')),
            DataColumn(label: Text('Last Login')),
            DataColumn(label: Text('Status')),
          ],
          rows: _mockUsers.asMap().entries.map((entry) {
            final idx = entry.key + 1;
            final u = entry.value;
            return DataRow(
              onSelectChanged: (_) => _showEditMemberDialog(u),
              cells: [
                DataCell(Checkbox(value: false, onChanged: (_) {})),
                DataCell(SelectableText('$idx')),
                DataCell(SelectableText(u.name)),
                DataCell(SelectableText(u.phone ?? '')),
                DataCell(SelectableText(u.email)),
                DataCell(SelectableText(u.city ?? '')),
                DataCell(SelectableText(u.country ?? '')),
                DataCell(SelectableText(u.address ?? '')),
                DataCell(SelectableText(u.tag ?? '')),
                DataCell(SelectableText(u.role.label)),
                DataCell(SelectableText(u.lastLoginAt != null ? dateFormat.format(u.lastLoginAt!) : '')),
                DataCell(_buildStatusChip(u.isActive)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFirestoreUserTable(DateFormat dateFormat) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // Fallback to mock data on error
          return _buildMockUserTable(dateFormat);
        }
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data?.docs ?? [];
        // If only 1 user returned (likely self due to Firestore rules), show mock data for demo
        if (docs.isEmpty || docs.length == 1) {
          return _buildMockUserTable(dateFormat);
        }

        final users = docs.map((doc) => AppUser.fromFirestore(doc)).toList();
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: DataTable(
              showCheckboxColumn: true,
              columns: const [
                DataColumn(label: Text('')),  // Checkbox column
                DataColumn(label: Text('ID')),
                DataColumn(label: Text('Full Name')),
                DataColumn(label: Text('Mobile')),
                DataColumn(label: Text('Email')),
                DataColumn(label: Text('City')),
                DataColumn(label: Text('Country')),
                DataColumn(label: Text('Address')),
                DataColumn(label: Text('Tag')),
                DataColumn(label: Text('Role')),
                DataColumn(label: Text('Last Login')),
                DataColumn(label: Text('Status')),
              ],
              rows: users.asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final u = entry.value;
                return DataRow(
                  onSelectChanged: (_) => _showEditMemberDialog(u),
                  cells: [
                    DataCell(Checkbox(value: false, onChanged: (_) {})),
                    DataCell(SelectableText('$idx')),
                    DataCell(SelectableText(u.name)),
                    DataCell(SelectableText(u.phone ?? '')),
                    DataCell(SelectableText(u.email)),
                    DataCell(SelectableText(u.city ?? '')),
                    DataCell(SelectableText(u.country ?? '')),
                    DataCell(SelectableText(u.address ?? '')),
                    DataCell(SelectableText(u.tag ?? '')),
                    DataCell(SelectableText(u.role.label)),
                    DataCell(SelectableText(u.lastLoginAt != null ? dateFormat.format(u.lastLoginAt!) : '')),
                    DataCell(_buildStatusChip(u.isActive)),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  void _showAddMemberDialog() {
    final formKey = GlobalKey<FormState>();
    final firstNameCtrl = TextEditingController();
    final lastNameCtrl = TextEditingController();
    final mobileCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    final countryCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final tagCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    UserRole selectedRole = UserRole.member;
    bool makeAdmin = false;
    bool sendWelcome = false;
    bool status = true;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) => AlertDialog(
          title: const Text('Add Member'),
          content: SizedBox(
            width: 500,
            height: 500,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CheckboxListTile(
                      title: const Text('Make Admin'),
                      subtitle: const Text('Optional'),
                      value: makeAdmin,
                      onChanged: (v) => setDialogState(() => makeAdmin = v ?? false),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    // Profile image placeholder
                    Center(
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.grey.shade200,
                        child: const Icon(Icons.camera_alt, size: 32, color: Colors.grey),
                      ),
                    ),
                    const Center(child: Text('Profile image', style: TextStyle(fontSize: 12, color: Colors.grey))),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: firstNameCtrl,
                      decoration: const InputDecoration(labelText: '* First Name'),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: lastNameCtrl,
                      decoration: const InputDecoration(labelText: '* Last Name'),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(controller: mobileCtrl, decoration: const InputDecoration(labelText: 'Mobile'), keyboardType: TextInputType.phone),
                    const SizedBox(height: 12),
                    TextFormField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 12),
                    TextFormField(controller: cityCtrl, decoration: const InputDecoration(labelText: 'City')),
                    const SizedBox(height: 12),
                    TextFormField(controller: countryCtrl, decoration: const InputDecoration(labelText: 'Country')),
                    const SizedBox(height: 12),
                    TextFormField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address'), maxLines: 2),
                    const SizedBox(height: 12),
                    TextFormField(controller: tagCtrl, decoration: const InputDecoration(labelText: 'Tag', hintText: 'Emp / Agent / Freelancer')),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<UserRole>(
                      value: selectedRole,
                      decoration: const InputDecoration(labelText: 'Select Role'),
                      items: UserRole.values.map((r) => DropdownMenuItem(value: r, child: Text(r.label))).toList(),
                      onChanged: (v) => setDialogState(() => selectedRole = v ?? UserRole.member),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(controller: passwordCtrl, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      title: const Text('Send welcome message'),
                      subtitle: const Text('Optional'),
                      value: sendWelcome,
                      onChanged: (v) => setDialogState(() => sendWelcome = v ?? false),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: const Text('Status'),
                      subtitle: Text(status ? 'Active' : 'Deactive'),
                      value: status,
                      onChanged: (v) => setDialogState(() => status = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('Cancel')),
            FilledButton(
              onPressed: isLoading ? null : () async {
                if (!formKey.currentState!.validate()) return;
                setDialogState(() => isLoading = true);
                final fullName = '${firstNameCtrl.text.trim()} ${lastNameCtrl.text.trim()}';
                if (_useMockData) {
                  setState(() {
                    _mockUsers.add(AppUser(
                      uid: 'u${DateTime.now().millisecondsSinceEpoch}',
                      name: fullName,
                      firstName: firstNameCtrl.text.trim(),
                      lastName: lastNameCtrl.text.trim(),
                      email: emailCtrl.text.trim(),
                      role: selectedRole,
                      isActive: status,
                      isAdmin: makeAdmin,
                      phone: mobileCtrl.text.trim(),
                      city: cityCtrl.text.trim(),
                      country: countryCtrl.text.trim(),
                      address: addressCtrl.text.trim(),
                      tag: tagCtrl.text.trim(),
                    ));
                  });
                  Navigator.pop(ctx2);
                  _showSnackBar('Member added');
                } else {
                  try {
                    final cred = await _authService.signUp(emailCtrl.text.trim(), passwordCtrl.text.trim());
                    await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
                      'display_name': fullName,
                      'first_name': firstNameCtrl.text.trim(),
                      'last_name': lastNameCtrl.text.trim(),
                      'email': emailCtrl.text.trim(),
                      'role': selectedRole.toSnakeCase(),
                      'is_active': status,
                      'is_admin': makeAdmin,
                      'phone': mobileCtrl.text.trim(),
                      'city': cityCtrl.text.trim(),
                      'country': countryCtrl.text.trim(),
                      'address': addressCtrl.text.trim(),
                      'tag': tagCtrl.text.trim(),
                      'created_at': FieldValue.serverTimestamp(),
                    });
                    Navigator.pop(ctx2);
                    _showSnackBar('Member added');
                  } catch (e) {
                    setDialogState(() => isLoading = false);
                    _showSnackBar('Error: $e', isError: true);
                  }
                }
              },
              child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditMemberDialog(AppUser user) {
    final firstNameCtrl = TextEditingController(text: user.firstName.isNotEmpty ? user.firstName : user.name.split(' ').first);
    final lastNameCtrl = TextEditingController(text: user.lastName.isNotEmpty ? user.lastName : (user.name.split(' ').length > 1 ? user.name.split(' ').skip(1).join(' ') : ''));
    final mobileCtrl = TextEditingController(text: user.phone ?? '');
    final emailCtrl = TextEditingController(text: user.email);
    final cityCtrl = TextEditingController(text: user.city ?? '');
    final countryCtrl = TextEditingController(text: user.country ?? '');
    final addressCtrl = TextEditingController(text: user.address ?? '');
    final tagCtrl = TextEditingController(text: user.tag ?? '');
    UserRole selectedRole = user.role;
    bool makeAdmin = user.isAdmin;
    bool status = user.isActive;
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSheetState) => Padding(
          padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(ctx2).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text('Edit Member', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                Text(user.email, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 16),
                CheckboxListTile(title: const Text('Make Admin'), value: makeAdmin, onChanged: (v) => setSheetState(() => makeAdmin = v ?? false), contentPadding: EdgeInsets.zero),
                TextFormField(controller: firstNameCtrl, decoration: const InputDecoration(labelText: 'First Name')),
                const SizedBox(height: 12),
                TextFormField(controller: lastNameCtrl, decoration: const InputDecoration(labelText: 'Last Name')),
                const SizedBox(height: 12),
                TextFormField(controller: mobileCtrl, decoration: const InputDecoration(labelText: 'Mobile')),
                const SizedBox(height: 12),
                TextFormField(controller: cityCtrl, decoration: const InputDecoration(labelText: 'City')),
                const SizedBox(height: 12),
                TextFormField(controller: countryCtrl, decoration: const InputDecoration(labelText: 'Country')),
                const SizedBox(height: 12),
                TextFormField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address')),
                const SizedBox(height: 12),
                TextFormField(controller: tagCtrl, decoration: const InputDecoration(labelText: 'Tag')),
                const SizedBox(height: 12),
                DropdownButtonFormField<UserRole>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: UserRole.values.map((r) => DropdownMenuItem(value: r, child: Text(r.label))).toList(),
                  onChanged: (v) => setSheetState(() => selectedRole = v ?? user.role),
                ),
                const SizedBox(height: 12),
                SwitchListTile(title: const Text('Status'), subtitle: Text(status ? 'Active' : 'Deactive'), value: status, onChanged: (v) => setSheetState(() => status = v), contentPadding: EdgeInsets.zero),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: isLoading ? null : () async {
                      setSheetState(() => isLoading = true);
                      final fullName = '${firstNameCtrl.text.trim()} ${lastNameCtrl.text.trim()}';
                      if (_useMockData) {
                        setState(() {
                          final idx = _mockUsers.indexWhere((u) => u.uid == user.uid);
                          if (idx != -1) {
                            _mockUsers[idx] = user.copyWith(
                              name: fullName, firstName: firstNameCtrl.text.trim(), lastName: lastNameCtrl.text.trim(),
                              phone: mobileCtrl.text.trim(), city: cityCtrl.text.trim(), country: countryCtrl.text.trim(),
                              address: addressCtrl.text.trim(), tag: tagCtrl.text.trim(), role: selectedRole, isActive: status, isAdmin: makeAdmin,
                            );
                          }
                        });
                        Navigator.pop(ctx2);
                        _showSnackBar('Member updated');
                      } else {
                        try {
                          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                            'display_name': fullName, 'first_name': firstNameCtrl.text.trim(), 'last_name': lastNameCtrl.text.trim(),
                            'phone': mobileCtrl.text.trim(), 'city': cityCtrl.text.trim(), 'country': countryCtrl.text.trim(),
                            'address': addressCtrl.text.trim(), 'tag': tagCtrl.text.trim(), 'role': selectedRole.toSnakeCase(),
                            'is_active': status, 'is_admin': makeAdmin, 'updated_at': FieldValue.serverTimestamp(),
                          });
                          Navigator.pop(ctx2);
                          _showSnackBar('Member updated');
                        } catch (e) {
                          setSheetState(() => isLoading = false);
                          _showSnackBar('Error: $e', isError: true);
                        }
                      }
                    },
                    child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save Changes'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================
  Widget _buildStatusChip(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isActive ? 'Active' : 'Deactive',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: isActive ? Colors.green.shade700 : Colors.grey.shade600),
      ),
    );
  }

  Widget _buildUserDropdown(String label, String? value, ValueChanged<String?> onChanged, List<String> roleFilters) {
    return _SearchableUserDropdown(
      label: label,
      value: value,
      onChanged: onChanged,
      roleFilters: roleFilters,
      mockUsers: _mockUsers,
      allUsers: _allUsers,
      useMockData: _useMockData,
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  /// Helper to get user name by UID from mock or Firestore data
  String? _getUserNameByUid(String? uid) {
    if (uid == null) return null;

    // Check mock users first
    final mockUser = _mockUsers.where((u) => u.uid == uid).firstOrNull;
    if (mockUser != null) return mockUser.name;

    // Check Firestore users
    final fsUser = _allUsers.where((u) => (u['uid'] ?? u['id']) == uid).firstOrNull;
    if (fsUser != null) return (fsUser['name'] ?? fsUser['display_name'] ?? fsUser['email']) as String?;

    return null;
  }

  /// Get list of member names from UIDs
  List<String> _getMemberNamesByUids(List<String> uids) {
    return uids.map((uid) => _getUserNameByUid(uid) ?? uid).toList();
  }
}

/// Searchable User Dropdown Widget with Name + ID display
class _SearchableUserDropdown extends StatefulWidget {
  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;
  final List<String> roleFilters;
  final List<AppUser> mockUsers;
  final List<Map<String, dynamic>> allUsers;
  final bool useMockData;

  const _SearchableUserDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.roleFilters,
    required this.mockUsers,
    required this.allUsers,
    required this.useMockData,
  });

  @override
  State<_SearchableUserDropdown> createState() => _SearchableUserDropdownState();
}

class _SearchableUserDropdownState extends State<_SearchableUserDropdown> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<Map<String, String>> _getFilteredUsers() {
    List<Map<String, String>> users = [];

    if (widget.useMockData) {
      final filteredUsers = widget.mockUsers.where((u) => widget.roleFilters.contains(u.role.toSnakeCase())).toList();
      for (final u in filteredUsers) {
        users.add({'uid': u.uid, 'name': u.name, 'email': u.email});
      }
    } else {
      final filteredUsers = widget.allUsers.where((u) => widget.roleFilters.contains(u['role'])).toList();
      for (final u in filteredUsers) {
        final uid = (u['uid'] ?? u['id'] ?? '') as String;
        final name = (u['name'] ?? u['display_name'] ?? u['email'] ?? '') as String;
        final email = (u['email'] ?? '') as String;
        users.add({'uid': uid, 'name': name, 'email': email});
      }
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      users = users.where((u) {
        final name = u['name']!.toLowerCase();
        final email = u['email']!.toLowerCase();
        final uid = u['uid']!.toLowerCase();
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || email.contains(query) || uid.contains(query);
      }).toList();
    }

    return users;
  }

  String? _getSelectedUserDisplay() {
    if (widget.value == null) return null;
    final users = _getFilteredUsers();
    final selected = users.where((u) => u['uid'] == widget.value).firstOrNull;
    if (selected != null) {
      return '${selected['name']} (${selected['email']})';
    }
    return widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => _showUserSelectionDialog(context),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: widget.label,
              suffixIcon: const Icon(Icons.arrow_drop_down),
              border: const OutlineInputBorder(),
            ),
            child: Text(
              _getSelectedUserDisplay() ?? 'None',
              style: TextStyle(
                color: widget.value == null ? Colors.grey : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showUserSelectionDialog(BuildContext context) {
    _searchController.clear();
    _searchQuery = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) {
          final users = _getFilteredUsers();
          return AlertDialog(
            title: Text('Select ${widget.label}'),
            content: SizedBox(
              width: 450,
              height: 400,
              child: Column(
                children: [
                  // Search field
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by name, email, or ID...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (v) {
                      setDialogState(() => _searchQuery = v);
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                  // User list
                  Expanded(
                    child: ListView(
                      children: [
                        // None option
                        ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.close, size: 18)),
                          title: const Text('None'),
                          subtitle: const Text('Clear selection'),
                          selected: widget.value == null,
                          onTap: () {
                            widget.onChanged(null);
                            Navigator.pop(ctx2);
                          },
                        ),
                        const Divider(),
                        ...users.map((u) => ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            child: Text(
                              u['name']!.isNotEmpty ? u['name']![0].toUpperCase() : '?',
                              style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
                            ),
                          ),
                          title: Text(u['name']!, style: const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: Text('${u['email']}\nID: ${u['uid']}', style: const TextStyle(fontSize: 12)),
                          isThreeLine: true,
                          selected: widget.value == u['uid'],
                          selectedTileColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                          onTap: () {
                            widget.onChanged(u['uid']);
                            Navigator.pop(ctx2);
                          },
                        )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx2),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Role Permissions class
class RolePermissions {
  final bool leadViewOwn;
  final bool leadEditOwn;
  final bool leadCreate;
  final bool leadDelete;
  final bool leadViewGroup;
  final bool leadViewTeam;
  final bool leadViewGlobal;

  const RolePermissions({
    this.leadViewOwn = false,
    this.leadEditOwn = false,
    this.leadCreate = false,
    this.leadDelete = false,
    this.leadViewGroup = false,
    this.leadViewTeam = false,
    this.leadViewGlobal = false,
  });

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
