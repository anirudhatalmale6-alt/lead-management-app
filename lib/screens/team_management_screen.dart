import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/firestore_service.dart';

class TeamManagementScreen extends StatefulWidget {
  const TeamManagementScreen({super.key});

  @override
  State<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends State<TeamManagementScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  late TabController _tabController;

  // Toggle this to true when Firebase is not configured / for demo purposes.
  final bool _useMockData = false;

  // ---------------------------------------------------------------------------
  // Mock data
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> _mockManagers = [
    {'uid': 'm1', 'name': 'Alice Johnson'},
    {'uid': 'm2', 'name': 'Carol Davis'},
    {'uid': 'm3', 'name': 'George Lee'},
  ];

  List<Map<String, dynamic>> _mockTeamLeads = [
    {'uid': 'tl1', 'name': 'Dan Wilson'},
    {'uid': 'tl2', 'name': 'Hana Patel'},
    {'uid': 'tl3', 'name': 'Ivan Chen'},
  ];

  // Firebase loaded users
  List<Map<String, dynamic>> _firestoreUsers = [];

  late List<Map<String, dynamic>> _mockTeams;
  late List<Map<String, dynamic>> _mockGroups;

  // Groups tab filter
  String? _selectedTeamFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUsersFromFirestore();

    _mockTeams = [
      {
        'id': 'team_1',
        'name': 'North Region',
        'description': 'Covers the northern sales territory.',
        'manager_uid': 'm1',
        'manager_name': 'Alice Johnson',
        'member_count': 12,
      },
      {
        'id': 'team_2',
        'name': 'South Region',
        'description': 'Covers the southern sales territory.',
        'manager_uid': 'm2',
        'manager_name': 'Carol Davis',
        'member_count': 9,
      },
      {
        'id': 'team_3',
        'name': 'Enterprise',
        'description': 'Handles enterprise-level accounts.',
        'manager_uid': 'm3',
        'manager_name': 'George Lee',
        'member_count': 6,
      },
    ];

    _mockGroups = [
      {
        'id': 'grp_1',
        'name': 'Group Alpha',
        'description': 'Inbound leads for North Region.',
        'team_id': 'team_1',
        'team_name': 'North Region',
        'lead_uid': 'tl1',
        'lead_name': 'Dan Wilson',
        'member_count': 5,
      },
      {
        'id': 'grp_2',
        'name': 'Group Beta',
        'description': 'Outbound leads for North Region.',
        'team_id': 'team_1',
        'team_name': 'North Region',
        'lead_uid': 'tl2',
        'lead_name': 'Hana Patel',
        'member_count': 7,
      },
      {
        'id': 'grp_3',
        'name': 'Group Gamma',
        'description': 'South Region primary group.',
        'team_id': 'team_2',
        'team_name': 'South Region',
        'lead_uid': 'tl1',
        'lead_name': 'Dan Wilson',
        'member_count': 9,
      },
      {
        'id': 'grp_4',
        'name': 'Group Delta',
        'description': 'Enterprise accounts group.',
        'team_id': 'team_3',
        'team_name': 'Enterprise',
        'lead_uid': 'tl3',
        'lead_name': 'Ivan Chen',
        'member_count': 6,
      },
    ];
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUsersFromFirestore() async {
    if (_useMockData) return;
    try {
      final users = await _firestoreService.getAllUsers();
      if (mounted) {
        setState(() {
          _firestoreUsers = users;
          // Update managers and team leads lists from Firestore users
          _mockManagers = users
              .where((u) =>
                  u['role'] == 'manager' ||
                  u['role'] == 'admin' ||
                  u['role'] == 'super_admin')
              .map((u) => {
                    'uid': u['uid'] ?? u['id'] ?? '',
                    'name': u['name'] ?? u['email'] ?? 'Unknown',
                  })
              .toList();
          _mockTeamLeads = users
              .where((u) =>
                  u['role'] == 'team_lead' ||
                  u['role'] == 'coordinator' ||
                  u['role'] == 'manager' ||
                  u['role'] == 'admin')
              .map((u) => {
                    'uid': u['uid'] ?? u['id'] ?? '',
                    'name': u['name'] ?? u['email'] ?? 'Unknown',
                  })
              .toList();
          // If no managers/leads found, use all users
          if (_mockManagers.isEmpty) {
            _mockManagers = users
                .map((u) => {
                      'uid': u['uid'] ?? u['id'] ?? '',
                      'name': u['name'] ?? u['email'] ?? 'Unknown',
                    })
                .toList();
          }
          if (_mockTeamLeads.isEmpty) {
            _mockTeamLeads = users
                .map((u) => {
                      'uid': u['uid'] ?? u['id'] ?? '',
                      'name': u['name'] ?? u['email'] ?? 'Unknown',
                    })
                .toList();
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading users: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _teamNameById(String? teamId) {
    if (teamId == null) return 'Unassigned';
    final match = _mockTeams.where((t) => t['id'] == teamId);
    return match.isNotEmpty ? match.first['name'] as String : 'Unknown';
  }

  String _managerNameByUid(String? uid) {
    if (uid == null) return 'None';
    final match = _mockManagers.where((m) => m['uid'] == uid);
    return match.isNotEmpty ? match.first['name'] as String : 'Unknown';
  }

  String _leadNameByUid(String? uid) {
    if (uid == null) return 'None';
    final match = _mockTeamLeads.where((l) => l['uid'] == uid);
    return match.isNotEmpty ? match.first['name'] as String : 'Unknown';
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teams & Groups'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.group_work), text: 'Teams'),
            Tab(icon: Icon(Icons.workspaces), text: 'Groups'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTeamsTab(theme),
          _buildGroupsTab(theme),
        ],
      ),
    );
  }

  // ===========================================================================
  // TEAMS TAB
  // ===========================================================================

  Widget _buildTeamsTab(ThemeData theme) {
    return _useMockData ? _buildMockTeams(theme) : _buildFirestoreTeams(theme);
  }

  Widget _buildMockTeams(ThemeData theme) {
    return Stack(
      children: [
        if (_mockTeams.isEmpty)
          const Center(child: Text('No teams found.'))
        else
          ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
            itemCount: _mockTeams.length,
            itemBuilder: (context, index) {
              return _buildTeamCard(_mockTeams[index], theme);
            },
          ),
        _buildFab(
          onPressed: () => _showAddTeamDialog(context),
          tooltip: 'Add Team',
        ),
      ],
    );
  }

  Widget _buildFirestoreTeams(ThemeData theme) {
    return Stack(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: _firestoreService.getTeamsStream(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Center(child: Text('No teams found.'));
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                data['id'] = docs[index].id;
                return _buildTeamCard(data, theme);
              },
            );
          },
        ),
        _buildFab(
          onPressed: () => _showAddTeamDialog(context),
          tooltip: 'Add Team',
        ),
      ],
    );
  }

  Widget _buildTeamCard(Map<String, dynamic> team, ThemeData theme) {
    final teamId = team['id'] as String;
    final name = team['name'] as String? ?? '';
    final description = team['description'] as String? ?? '';
    final managerName = team['manager_name'] as String? ??
        _managerNameByUid(team['manager_uid'] as String?);
    final memberCount = team['member_count'] as int? ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.group_work,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (description.isNotEmpty)
                        Text(
                          description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (action) {
                    if (action == 'edit') {
                      _showEditTeamDialog(context, team);
                    } else if (action == 'delete') {
                      _confirmDeleteTeam(teamId, name);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Info chips
            Row(
              children: [
                _infoChip(Icons.manage_accounts, 'Manager: $managerName', theme),
                const SizedBox(width: 12),
                _infoChip(Icons.people, '$memberCount members', theme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // GROUPS TAB
  // ===========================================================================

  Widget _buildGroupsTab(ThemeData theme) {
    return _useMockData
        ? _buildMockGroups(theme)
        : _buildFirestoreGroups(theme);
  }

  Widget _buildMockGroups(ThemeData theme) {
    final filteredGroups = _selectedTeamFilter != null
        ? _mockGroups.where((g) => g['team_id'] == _selectedTeamFilter).toList()
        : _mockGroups;

    return Stack(
      children: [
        Column(
          children: [
            _buildTeamFilterDropdown(theme),
            Expanded(
              child: filteredGroups.isEmpty
                  ? const Center(child: Text('No groups found.'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                      itemCount: filteredGroups.length,
                      itemBuilder: (context, index) {
                        return _buildGroupCard(filteredGroups[index], theme);
                      },
                    ),
            ),
          ],
        ),
        _buildFab(
          onPressed: () => _showAddGroupDialog(context),
          tooltip: 'Add Group',
        ),
      ],
    );
  }

  Widget _buildFirestoreGroups(ThemeData theme) {
    return Stack(
      children: [
        Column(
          children: [
            _buildTeamFilterDropdown(theme),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestoreService.getGroupsStream(
                  teamId: _selectedTeamFilter,
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(child: Text('No groups found.'));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      data['id'] = docs[index].id;
                      return _buildGroupCard(data, theme);
                    },
                  );
                },
              ),
            ),
          ],
        ),
        _buildFab(
          onPressed: () => _showAddGroupDialog(context),
          tooltip: 'Add Group',
        ),
      ],
    );
  }

  Widget _buildTeamFilterDropdown(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: DropdownButtonFormField<String>(
        value: _selectedTeamFilter,
        decoration: InputDecoration(
          labelText: 'Filter by Team',
          prefixIcon: const Icon(Icons.filter_list),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
        items: [
          const DropdownMenuItem(
            value: null,
            child: Text('All Teams'),
          ),
          ..._mockTeams.map((t) {
            return DropdownMenuItem(
              value: t['id'] as String,
              child: Text(t['name'] as String),
            );
          }),
        ],
        onChanged: (v) {
          setState(() => _selectedTeamFilter = v);
        },
      ),
    );
  }

  Widget _buildGroupCard(Map<String, dynamic> group, ThemeData theme) {
    final groupId = group['id'] as String;
    final name = group['name'] as String? ?? '';
    final description = group['description'] as String? ?? '';
    final teamName = group['team_name'] as String? ??
        _teamNameById(group['team_id'] as String?);
    final leadName = group['lead_name'] as String? ??
        _leadNameByUid(group['lead_uid'] as String?);
    final memberCount = group['member_count'] as int? ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.workspaces,
                    color: theme.colorScheme.onTertiaryContainer,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (description.isNotEmpty)
                        Text(
                          description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (action) {
                    if (action == 'edit') {
                      _showEditGroupDialog(context, group);
                    } else if (action == 'delete') {
                      _confirmDeleteGroup(groupId, name);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Info chips
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                _infoChip(Icons.group_work, 'Team: $teamName', theme),
                _infoChip(Icons.person, 'Lead: $leadName', theme),
                _infoChip(Icons.people, '$memberCount members', theme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SHARED WIDGETS
  // ===========================================================================

  Widget _infoChip(IconData icon, String label, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildFab({required VoidCallback onPressed, required String tooltip}) {
    return Positioned(
      bottom: 16,
      right: 16,
      child: FloatingActionButton.extended(
        onPressed: onPressed,
        icon: const Icon(Icons.add),
        label: Text(tooltip),
        heroTag: tooltip,
      ),
    );
  }

  // ===========================================================================
  // ADD TEAM DIALOG
  // ===========================================================================

  void _showAddTeamDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? selectedManagerUid;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setDialogState) {
            return AlertDialog(
              title: const Text('Add New Team'),
              content: SizedBox(
                width: 400,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Team Name',
                          prefixIcon: Icon(Icons.group_work_outlined),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          prefixIcon: Icon(Icons.description_outlined),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedManagerUid,
                        decoration: const InputDecoration(
                          labelText: 'Manager',
                          prefixIcon: Icon(Icons.manage_accounts_outlined),
                        ),
                        items: _mockManagers.map((m) {
                          return DropdownMenuItem(
                            value: m['uid'] as String,
                            child: Text(m['name'] as String),
                          );
                        }).toList(),
                        onChanged: (v) {
                          setDialogState(() => selectedManagerUid = v);
                        },
                        validator: (v) => v == null ? 'Select a manager' : null,
                      ),
                    ],
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
                            final newTeam = {
                              'id': 'team_${DateTime.now().millisecondsSinceEpoch}',
                              'name': nameCtrl.text.trim(),
                              'description': descCtrl.text.trim(),
                              'manager_uid': selectedManagerUid,
                              'manager_name':
                                  _managerNameByUid(selectedManagerUid),
                              'member_count': 0,
                            };
                            setState(() => _mockTeams.add(newTeam));
                            if (ctx2.mounted) Navigator.of(ctx2).pop();
                            _showSnackBar('Team created successfully');
                          } else {
                            try {
                              await _firestoreService.createTeam(
                                nameCtrl.text.trim(),
                                descCtrl.text.trim(),
                                selectedManagerUid!,
                              );
                              if (ctx2.mounted) Navigator.of(ctx2).pop();
                              _showSnackBar('Team created successfully');
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
                      : const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // EDIT TEAM DIALOG
  // ===========================================================================

  void _showEditTeamDialog(BuildContext context, Map<String, dynamic> team) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: team['name'] as String? ?? '');
    final descCtrl =
        TextEditingController(text: team['description'] as String? ?? '');
    String? selectedManagerUid = team['manager_uid'] as String?;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Team'),
              content: SizedBox(
                width: 400,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Team Name',
                          prefixIcon: Icon(Icons.group_work_outlined),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          prefixIcon: Icon(Icons.description_outlined),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedManagerUid,
                        decoration: const InputDecoration(
                          labelText: 'Manager',
                          prefixIcon: Icon(Icons.manage_accounts_outlined),
                        ),
                        items: _mockManagers.map((m) {
                          return DropdownMenuItem(
                            value: m['uid'] as String,
                            child: Text(m['name'] as String),
                          );
                        }).toList(),
                        onChanged: (v) {
                          setDialogState(() => selectedManagerUid = v);
                        },
                        validator: (v) => v == null ? 'Select a manager' : null,
                      ),
                    ],
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
                            final idx = _mockTeams.indexWhere(
                              (t) => t['id'] == team['id'],
                            );
                            if (idx != -1) {
                              setState(() {
                                _mockTeams[idx] = {
                                  ..._mockTeams[idx],
                                  'name': nameCtrl.text.trim(),
                                  'description': descCtrl.text.trim(),
                                  'manager_uid': selectedManagerUid,
                                  'manager_name':
                                      _managerNameByUid(selectedManagerUid),
                                };
                              });
                            }
                            if (ctx2.mounted) Navigator.of(ctx2).pop();
                            _showSnackBar('Team updated successfully');
                          } else {
                            try {
                              await _firestoreService.updateTeam(
                                team['id'] as String,
                                {
                                  'name': nameCtrl.text.trim(),
                                  'description': descCtrl.text.trim(),
                                  'manager_uid': selectedManagerUid,
                                },
                              );
                              if (ctx2.mounted) Navigator.of(ctx2).pop();
                              _showSnackBar('Team updated successfully');
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
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // DELETE TEAM
  // ===========================================================================

  void _confirmDeleteTeam(String teamId, String teamName) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Team'),
          content: Text(
            'Are you sure you want to delete "$teamName"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () async {
                Navigator.of(ctx).pop();
                if (_useMockData) {
                  setState(() {
                    _mockTeams.removeWhere((t) => t['id'] == teamId);
                  });
                  _showSnackBar('Team deleted');
                } else {
                  try {
                    await _firestoreService.deleteTeam(teamId);
                    _showSnackBar('Team deleted');
                  } catch (e) {
                    _showSnackBar('Error: $e', isError: true);
                  }
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // ADD GROUP DIALOG
  // ===========================================================================

  void _showAddGroupDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? selectedTeamId;
    String? selectedLeadUid;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setDialogState) {
            return AlertDialog(
              title: const Text('Add New Group'),
              content: SizedBox(
                width: 400,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Group Name',
                          prefixIcon: Icon(Icons.workspaces_outlined),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          prefixIcon: Icon(Icons.description_outlined),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedTeamId,
                        decoration: const InputDecoration(
                          labelText: 'Parent Team',
                          prefixIcon: Icon(Icons.group_work_outlined),
                        ),
                        items: _mockTeams.map((t) {
                          return DropdownMenuItem(
                            value: t['id'] as String,
                            child: Text(t['name'] as String),
                          );
                        }).toList(),
                        onChanged: (v) {
                          setDialogState(() => selectedTeamId = v);
                        },
                        validator: (v) => v == null ? 'Select a team' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedLeadUid,
                        decoration: const InputDecoration(
                          labelText: 'Team Lead',
                          prefixIcon: Icon(Icons.person_outlined),
                        ),
                        items: _mockTeamLeads.map((l) {
                          return DropdownMenuItem(
                            value: l['uid'] as String,
                            child: Text(l['name'] as String),
                          );
                        }).toList(),
                        onChanged: (v) {
                          setDialogState(() => selectedLeadUid = v);
                        },
                        validator: (v) =>
                            v == null ? 'Select a team lead' : null,
                      ),
                    ],
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
                            final newGroup = {
                              'id':
                                  'grp_${DateTime.now().millisecondsSinceEpoch}',
                              'name': nameCtrl.text.trim(),
                              'description': descCtrl.text.trim(),
                              'team_id': selectedTeamId,
                              'team_name': _teamNameById(selectedTeamId),
                              'lead_uid': selectedLeadUid,
                              'lead_name': _leadNameByUid(selectedLeadUid),
                              'member_count': 0,
                            };
                            setState(() => _mockGroups.add(newGroup));
                            if (ctx2.mounted) Navigator.of(ctx2).pop();
                            _showSnackBar('Group created successfully');
                          } else {
                            try {
                              await _firestoreService.createGroup(
                                nameCtrl.text.trim(),
                                descCtrl.text.trim(),
                                selectedTeamId!,
                                selectedLeadUid!,
                              );
                              if (ctx2.mounted) Navigator.of(ctx2).pop();
                              _showSnackBar('Group created successfully');
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
                      : const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // EDIT GROUP DIALOG
  // ===========================================================================

  void _showEditGroupDialog(BuildContext context, Map<String, dynamic> group) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: group['name'] as String? ?? '');
    final descCtrl =
        TextEditingController(text: group['description'] as String? ?? '');
    String? selectedTeamId = group['team_id'] as String?;
    String? selectedLeadUid = group['lead_uid'] as String?;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Group'),
              content: SizedBox(
                width: 400,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Group Name',
                          prefixIcon: Icon(Icons.workspaces_outlined),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          prefixIcon: Icon(Icons.description_outlined),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedTeamId,
                        decoration: const InputDecoration(
                          labelText: 'Parent Team',
                          prefixIcon: Icon(Icons.group_work_outlined),
                        ),
                        items: _mockTeams.map((t) {
                          return DropdownMenuItem(
                            value: t['id'] as String,
                            child: Text(t['name'] as String),
                          );
                        }).toList(),
                        onChanged: (v) {
                          setDialogState(() => selectedTeamId = v);
                        },
                        validator: (v) => v == null ? 'Select a team' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedLeadUid,
                        decoration: const InputDecoration(
                          labelText: 'Team Lead',
                          prefixIcon: Icon(Icons.person_outlined),
                        ),
                        items: _mockTeamLeads.map((l) {
                          return DropdownMenuItem(
                            value: l['uid'] as String,
                            child: Text(l['name'] as String),
                          );
                        }).toList(),
                        onChanged: (v) {
                          setDialogState(() => selectedLeadUid = v);
                        },
                        validator: (v) =>
                            v == null ? 'Select a team lead' : null,
                      ),
                    ],
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
                            final idx = _mockGroups.indexWhere(
                              (g) => g['id'] == group['id'],
                            );
                            if (idx != -1) {
                              setState(() {
                                _mockGroups[idx] = {
                                  ..._mockGroups[idx],
                                  'name': nameCtrl.text.trim(),
                                  'description': descCtrl.text.trim(),
                                  'team_id': selectedTeamId,
                                  'team_name': _teamNameById(selectedTeamId),
                                  'lead_uid': selectedLeadUid,
                                  'lead_name': _leadNameByUid(selectedLeadUid),
                                };
                              });
                            }
                            if (ctx2.mounted) Navigator.of(ctx2).pop();
                            _showSnackBar('Group updated successfully');
                          } else {
                            try {
                              await _firestoreService.updateGroup(
                                group['id'] as String,
                                {
                                  'name': nameCtrl.text.trim(),
                                  'description': descCtrl.text.trim(),
                                  'team_id': selectedTeamId,
                                  'lead_uid': selectedLeadUid,
                                },
                              );
                              if (ctx2.mounted) Navigator.of(ctx2).pop();
                              _showSnackBar('Group updated successfully');
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
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // DELETE GROUP
  // ===========================================================================

  void _confirmDeleteGroup(String groupId, String groupName) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Group'),
          content: Text(
            'Are you sure you want to delete "$groupName"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () async {
                Navigator.of(ctx).pop();
                if (_useMockData) {
                  setState(() {
                    _mockGroups.removeWhere((g) => g['id'] == groupId);
                  });
                  _showSnackBar('Group deleted');
                } else {
                  try {
                    await _firestoreService.deleteGroup(groupId);
                    _showSnackBar('Group deleted');
                  } catch (e) {
                    _showSnackBar('Error: $e', isError: true);
                  }
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // SNACK BAR HELPER
  // ===========================================================================

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
