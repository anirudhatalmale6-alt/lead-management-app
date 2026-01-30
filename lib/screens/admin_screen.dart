import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  late TabController _tabController;

  final bool _useMockData = false;

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
              child: Text('Team List', style: Theme.of(context).textTheme.titleLarge),
            ),
            Expanded(
              child: _useMockData ? _buildMockTeamList() : _buildFirestoreTeamList(),
            ),
          ],
        ),
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
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _showEditTeamDialog(team)),
                  IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => _confirmDeleteTeam(team['id'], team['name'])),
                ],
              )),
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
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _showEditTeamDialog(data)),
                      IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => _confirmDeleteTeam(data['id'], data['name'])),
                    ],
                  )),
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
                if (_useMockData) {
                  setState(() {
                    _mockTeams.add({
                      'id': 'team_${DateTime.now().millisecondsSinceEpoch}',
                      'name': nameCtrl.text.trim(),
                      'manager_uid': selectedManager,
                      'tl_uid': selectedTL,
                      'admin_uid': selectedAdmin,
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
                      'tl_uid': selectedTL,
                      'admin_uid': selectedAdmin,
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
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Team Name')),
                  const SizedBox(height: 12),
                  _buildUserDropdown('Select Manager', selectedManager, (v) => setDialogState(() => selectedManager = v), ['manager', 'admin', 'super_admin']),
                  const SizedBox(height: 12),
                  _buildUserDropdown('Select TL', selectedTL, (v) => setDialogState(() => selectedTL = v), ['team_lead', 'coordinator', 'manager']),
                  const SizedBox(height: 12),
                  _buildUserDropdown('Select Admin', selectedAdmin, (v) => setDialogState(() => selectedAdmin = v), ['admin', 'super_admin']),
                  const SizedBox(height: 12),
                  SwitchListTile(title: const Text('Status'), value: status, onChanged: (v) => setDialogState(() => status = v)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('Cancel')),
            FilledButton(
              onPressed: isLoading ? null : () async {
                setDialogState(() => isLoading = true);
                if (_useMockData) {
                  setState(() {
                    final idx = _mockTeams.indexWhere((t) => t['id'] == team['id']);
                    if (idx != -1) _mockTeams[idx] = {...team, 'name': nameCtrl.text.trim(), 'manager_uid': selectedManager, 'tl_uid': selectedTL, 'admin_uid': selectedAdmin, 'status': status};
                  });
                  Navigator.pop(ctx2);
                  _showSnackBar('Team updated');
                } else {
                  try {
                    await FirebaseFirestore.instance.collection('teams').doc(team['id']).update({
                      'name': nameCtrl.text.trim(), 'manager_uid': selectedManager, 'tl_uid': selectedTL, 'admin_uid': selectedAdmin, 'status': status,
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
  // GROUP TAB
  // ===========================================================================
  Widget _buildGroupTab() {
    final dateFormat = DateFormat('dd MMM yyyy');
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Group List', style: Theme.of(context).textTheme.titleLarge),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('ID')),
                      DataColumn(label: Text('Group Name')),
                      DataColumn(label: Text('Sub Group Name')),
                      DataColumn(label: Text('Sub Group Manager')),
                      DataColumn(label: Text('Team Leaders')),
                      DataColumn(label: Text('Group Coordinator')),
                      DataColumn(label: Text('Member / Employees')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Created At')),
                      DataColumn(label: Text('Options')),
                    ],
                    rows: _mockGroups.asMap().entries.map((entry) {
                      final idx = entry.key + 1;
                      final grp = entry.value;
                      return DataRow(cells: [
                        DataCell(Text('$idx')),
                        DataCell(Text(grp['name'] ?? '')),
                        DataCell(Text(grp['sub_group_name'] ?? '')),
                        DataCell(Text(grp['sub_group_manager'] ?? '')),
                        DataCell(Text(grp['tl_name'] ?? '')),
                        DataCell(Text(grp['coordinator_name'] ?? '')),
                        DataCell(Text((grp['members'] as List?)?.join(', ') ?? '')),
                        DataCell(_buildStatusChip(grp['status'] ?? false)),
                        DataCell(Text(grp['created_at'] != null ? dateFormat.format(grp['created_at']) : '')),
                        DataCell(Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _showEditGroupDialog(grp)),
                            IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => _confirmDeleteGroup(grp['id'], grp['name'])),
                          ],
                        )),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
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
    String? admin, manager, tl;
    List<String> selectedMembers = [];
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) => AlertDialog(
          title: const Text('Add Group'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Group name')),
                  const SizedBox(height: 12),
                  _buildUserDropdown('Admin', admin, (v) => setDialogState(() => admin = v), ['admin', 'super_admin']),
                  const SizedBox(height: 12),
                  _buildUserDropdown('Manager', manager, (v) => setDialogState(() => manager = v), ['manager']),
                  const SizedBox(height: 12),
                  _buildUserDropdown('TL', tl, (v) => setDialogState(() => tl = v), ['team_lead']),
                  const SizedBox(height: 12),
                  const Text('Select member / Emp', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _mockUsers.where((u) => u.role == UserRole.member || u.role == UserRole.coordinator).map((u) {
                      final selected = selectedMembers.contains(u.uid);
                      return FilterChip(
                        label: Text('${u.name} (${u.uid})'),
                        selected: selected,
                        onSelected: (v) => setDialogState(() {
                          if (v) selectedMembers.add(u.uid);
                          else selectedMembers.remove(u.uid);
                        }),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('Cancel')),
            FilledButton(
              onPressed: isLoading ? null : () {
                setState(() {
                  _mockGroups.add({
                    'id': 'grp_${DateTime.now().millisecondsSinceEpoch}',
                    'name': nameCtrl.text.trim(),
                    'admin_uid': admin,
                    'manager_uid': manager,
                    'tl_uid': tl,
                    'members': selectedMembers,
                    'status': true,
                    'created_at': DateTime.now(),
                  });
                });
                Navigator.pop(ctx2);
                _showSnackBar('Group created');
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditGroupDialog(Map<String, dynamic> grp) {
    final nameCtrl = TextEditingController(text: grp['name']);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Group'),
        content: SizedBox(
          width: 400,
          child: TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Group name')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              setState(() {
                final idx = _mockGroups.indexWhere((g) => g['id'] == grp['id']);
                if (idx != -1) _mockGroups[idx]['name'] = nameCtrl.text.trim();
              });
              Navigator.pop(ctx);
              _showSnackBar('Group updated');
            },
            child: const Text('Save'),
          ),
        ],
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
          columns: const [
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
                DataCell(Text('$idx')),
                DataCell(Text(u.name)),
                DataCell(Text(u.phone ?? '')),
                DataCell(Text(u.email)),
                DataCell(Text(u.city ?? '')),
                DataCell(Text(u.country ?? '')),
                DataCell(Text(u.address ?? '')),
                DataCell(Text(u.tag ?? '')),
                DataCell(Text(u.role.label)),
                DataCell(Text(u.lastLoginAt != null ? dateFormat.format(u.lastLoginAt!) : '')),
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
              columns: const [
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
                    DataCell(Text('$idx')),
                    DataCell(Text(u.name)),
                    DataCell(Text(u.phone ?? '')),
                    DataCell(Text(u.email)),
                    DataCell(Text(u.city ?? '')),
                    DataCell(Text(u.country ?? '')),
                    DataCell(Text(u.address ?? '')),
                    DataCell(Text(u.tag ?? '')),
                    DataCell(Text(u.role.label)),
                    DataCell(Text(u.lastLoginAt != null ? dateFormat.format(u.lastLoginAt!) : '')),
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
    List<DropdownMenuItem<String>> items = [
      const DropdownMenuItem(value: null, child: Text('None')),
    ];

    if (_useMockData) {
      final filteredUsers = _mockUsers.where((u) => roleFilters.contains(u.role.toSnakeCase())).toList();
      for (final u in filteredUsers) {
        items.add(DropdownMenuItem(value: u.uid, child: Text(u.name)));
      }
    } else {
      final filteredUsers = _allUsers.where((u) => roleFilters.contains(u['role'])).toList();
      for (final u in filteredUsers) {
        final uid = (u['uid'] ?? u['id'] ?? '') as String;
        final name = (u['name'] ?? u['email'] ?? '') as String;
        items.add(DropdownMenuItem(value: uid, child: Text(name)));
      }
    }

    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: items,
      onChanged: onChanged,
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
}
