import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/meeting.dart';
import '../models/user.dart';
import '../models/lead.dart';
import '../services/calendar_service.dart';
import '../services/firestore_service.dart';
import '../services/lead_service.dart';
import '../services/user_service.dart';
import '../widgets/schedule_meeting_dialog.dart';
import 'lead_detail_screen.dart';

class CalendarScreen extends StatefulWidget {
  final AppUser currentUser;

  const CalendarScreen({super.key, required this.currentUser});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

enum CalendarViewType { month, week, day }

class _CalendarScreenState extends State<CalendarScreen> {
  final CalendarService _calendarService = CalendarService();

  DateTime _currentMonth = DateTime.now();
  DateTime? _selectedDate;
  List<Meeting> _meetings = [];
  bool _isLoading = true;

  // View and filter state
  CalendarViewType _viewType = CalendarViewType.month;
  String? _filterPartyName;
  MeetingStatus? _filterStatus;
  bool _showFilters = false;

  // Team filter state
  String _calendarScope = 'my'; // 'my', 'team', 'all'
  List<AppUser> _visibleUsers = []; // Users visible based on role hierarchy
  String? _selectedMemberUid; // Selected team member UID for filtering (null = all)
  final UserService _userService = UserService();

  // Hierarchy filter: Team > Group > User
  List<Map<String, dynamic>> _teams = [];
  List<Map<String, dynamic>> _groups = [];
  List<AppUser> _allUsers = [];
  String? _filterTeamId;
  String? _filterGroupId;
  String? _filterUserId;

  // Cache: leadId -> assignedTo email/uid for checking lead assignment visibility
  Map<String, String> _leadAssigneeCache = {};

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadMeetings();
    _loadVisibleUsers();
    _loadHierarchyData();
  }

  Future<void> _loadHierarchyData() async {
    try {
      final fs = FirestoreService();
      final teams = await fs.getTeams();
      final groups = await fs.getGroups();
      final users = await _userService.getAllUsers();
      if (mounted) {
        setState(() {
          _teams = teams;
          _groups = groups;
          _allUsers = users;
        });
      }
    } catch (e) {
      debugPrint('Error loading hierarchy data: $e');
    }
  }

  Future<void> _loadVisibleUsers() async {
    // Load users visible to current user based on role hierarchy:
    // Super Admin → can see everyone
    // Admin → own + their manager + manager's team
    // Manager/TL → own + their team members
    // Coordinator → own + their group members
    // Employee → only self (no dropdown needed)
    try {
      final currentUser = widget.currentUser;
      final role = currentUser.role;
      List<AppUser> users = [];

      switch (role) {
        case UserRole.superAdmin:
          // Can see all users
          users = await _userService.getAllUsers();
          break;
        case UserRole.admin:
          // Can see own team members only
          if (currentUser.teamId != null && currentUser.teamId!.isNotEmpty) {
            users = await _userService.getUsersByTeam(currentUser.teamId!);
          }
          // Always include self
          if (!users.any((u) => u.uid == currentUser.uid)) {
            users.insert(0, currentUser);
          }
          break;
        case UserRole.manager:
        case UserRole.teamLead:
          // Can see own + team members
          if (currentUser.teamId != null && currentUser.teamId!.isNotEmpty) {
            users = await _userService.getUsersByTeam(currentUser.teamId!);
          }
          // Always include self
          if (!users.any((u) => u.uid == currentUser.uid)) {
            users.insert(0, currentUser);
          }
          break;
        case UserRole.coordinator:
          // Can see own + group members
          if (currentUser.groupId != null && currentUser.groupId!.isNotEmpty) {
            users = await _userService.getUsersByGroup(currentUser.groupId!);
          } else if (currentUser.teamId != null && currentUser.teamId!.isNotEmpty) {
            users = await _userService.getUsersByTeam(currentUser.teamId!);
          }
          // Always include self
          if (!users.any((u) => u.uid == currentUser.uid)) {
            users.insert(0, currentUser);
          }
          break;
        case UserRole.member:
          // Can see only self — no dropdown needed
          users = [currentUser];
          break;
      }

      // Sort: current user first, then by role hierarchy, then alphabetically
      users.sort((a, b) {
        if (a.uid == currentUser.uid) return -1;
        if (b.uid == currentUser.uid) return 1;
        final roleOrder = {
          UserRole.superAdmin: 0, UserRole.admin: 1, UserRole.manager: 2,
          UserRole.teamLead: 3, UserRole.coordinator: 4, UserRole.member: 5,
        };
        final roleCompare = (roleOrder[a.role] ?? 5).compareTo(roleOrder[b.role] ?? 5);
        if (roleCompare != 0) return roleCompare;
        return a.name.compareTo(b.name);
      });

      if (mounted) {
        setState(() => _visibleUsers = users);
      }
    } catch (e) {
      debugPrint('Error loading visible users: $e');
      // Fallback: at minimum show current user
      if (mounted) {
        setState(() => _visibleUsers = [widget.currentUser]);
      }
    }
  }

  Future<void> _loadMeetings() async {
    setState(() => _isLoading = true);
    try {
      List<Meeting> meetings;
      final user = widget.currentUser;
      final role = user.role;

      // Load ALL meetings for all roles.
      // _filteredMeetings handles scope filtering (my vs team) including
      // lead assignment checks (e.g. manager creates meeting on lead assigned to employee).
      // Previously members only loaded their own meetings, missing meetings
      // created by managers on leads assigned to them.
      meetings = await _calendarService.getAllMeetings();

      debugPrint('Calendar: Got ${meetings.length} meetings from meetings collection');

      // Always load meetings from lead documents (leads with meetingDate set)
      // and merge them with meetings collection (avoiding duplicates by leadId)
      try {
        final leadMeetings = await _loadMeetingsFromLeads(meetings);
        if (leadMeetings.isNotEmpty) {
          meetings.addAll(leadMeetings);
          debugPrint('Calendar: Added ${leadMeetings.length} meetings from lead documents');
        }
      } catch (e) {
        debugPrint('Calendar: Error loading lead meetings: $e');
      }

      if (mounted) {
        setState(() {
          _meetings = meetings;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Calendar: Error loading meetings: $e');
      // Fallback: try loading from lead documents only
      try {
        final leadMeetings = await _loadMeetingsFromLeads([]);
        if (mounted) {
          setState(() {
            _meetings = leadMeetings;
            _isLoading = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  /// Load meetings from lead documents that have meeting_date set.
  /// Avoids duplicates by checking existing meeting IDs.
  Future<List<Meeting>> _loadMeetingsFromLeads(List<Meeting> existingMeetings) async {
    final leadService = LeadService();
    final existingLeadIds = existingMeetings
        .where((m) => m.leadId != null)
        .map((m) => m.leadId!)
        .toSet();

    final allLeads = await leadService.getAllLeads();
    final leadMeetings = <Meeting>[];

    // Build lead assignee cache for all leads (used by _filteredMeetings)
    final newCache = <String, String>{};
    for (final lead in allLeads) {
      if (lead.assignedTo.isNotEmpty) {
        newCache[lead.id] = lead.assignedTo;
      }
    }
    _leadAssigneeCache = newCache;

    for (final lead in allLeads) {
      // Skip if no meeting scheduled or if we already have a meeting for this lead
      if (lead.meetingDate == null || existingLeadIds.contains(lead.id)) continue;

      final timeParts = lead.meetingTime.split(':');
      final hour = timeParts.isNotEmpty ? int.tryParse(timeParts[0]) ?? 0 : 0;
      final minute = timeParts.length > 1 ? int.tryParse(timeParts[1]) ?? 0 : 0;
      final startTime = DateTime(
        lead.meetingDate!.year,
        lead.meetingDate!.month,
        lead.meetingDate!.day,
        hour,
        minute,
      );

      leadMeetings.add(Meeting(
        id: 'lead_${lead.id}',
        title: '${lead.meetingAgenda.label} - ${lead.clientName}',
        description: lead.meetingAgenda.label,
        startTime: startTime,
        endTime: startTime.add(const Duration(minutes: 30)),
        type: MeetingType.googleMeet,
        status: MeetingStatus.scheduled,
        leadId: lead.id,
        leadName: lead.clientName,
        meetLink: lead.meetingLink.isNotEmpty ? lead.meetingLink : null,
        createdBy: '',
        createdAt: startTime,
        organizerUid: lead.assignedTo.isNotEmpty ? lead.assignedTo : null,
        teamId: lead.teamId.isNotEmpty ? lead.teamId : null,
        groupId: lead.groupId.isNotEmpty ? lead.groupId : null,
      ));
    }

    return leadMeetings;
  }

  /// Check if current user is the assignee of a lead (for meeting visibility)
  bool _isCurrentUserAssignedToLead(String leadId) {
    final assignee = _leadAssigneeCache[leadId];
    if (assignee == null) return false;
    return assignee == widget.currentUser.uid ||
        assignee == widget.currentUser.email;
  }

  List<Meeting> get _filteredMeetings {
    var results = _meetings;

    // 'my' scope: show only meetings where user is directly involved
    if (_calendarScope == 'my') {
      final uid = widget.currentUser.uid;
      final email = widget.currentUser.email;
      results = results.where((m) {
        final isOrganizer = m.organizerUid == uid;
        final isGuest = m.guests.any((g) => g.email == email);
        final isAssigned = m.assignedTo == uid || m.assignedTo == email;
        final isCreator = m.createdBy == email || m.createdBy == uid;
        // Also check if the meeting's lead is assigned to current user
        // This handles: manager creates meeting on a lead assigned to employee
        bool isLeadAssignee = false;
        if (m.leadId != null) {
          isLeadAssignee = _isCurrentUserAssignedToLead(m.leadId!);
        }
        return isOrganizer || isGuest || isAssigned || isCreator || isLeadAssignee;
      }).toList();
    }
    // 'team' scope: show team/group meetings with hierarchy filter dropdowns
    if (_calendarScope == 'team') {
      final userRole = widget.currentUser.role;
      final userTeamId = widget.currentUser.teamId;
      final userGroupId = widget.currentUser.groupId;

      // Build lookup sets for checking if a user belongs to a team/group
      final teamUserUids = <String, Set<String>>{};
      final teamUserEmails = <String, Set<String>>{};
      final groupUserUids = <String, Set<String>>{};
      final groupUserEmails = <String, Set<String>>{};
      for (final u in _allUsers) {
        if (u.teamId != null && u.teamId!.isNotEmpty) {
          teamUserUids.putIfAbsent(u.teamId!, () => {}).add(u.uid);
          teamUserEmails.putIfAbsent(u.teamId!, () => {}).add(u.email);
        }
        if (u.groupId != null && u.groupId!.isNotEmpty) {
          groupUserUids.putIfAbsent(u.groupId!, () => {}).add(u.uid);
          groupUserEmails.putIfAbsent(u.groupId!, () => {}).add(u.email);
        }
      }

      // Helper: check if meeting belongs to a specific team
      bool meetingBelongsToTeam(Meeting m, String tid) {
        if (m.teamId == tid) return true;
        final uids = teamUserUids[tid] ?? {};
        final emails = teamUserEmails[tid] ?? {};
        return uids.contains(m.organizerUid) || emails.contains(m.createdBy) ||
               (m.assignedTo != null && (uids.contains(m.assignedTo) || emails.contains(m.assignedTo)));
      }

      // Helper: check if meeting belongs to a specific group
      bool meetingBelongsToGroup(Meeting m, String gid) {
        if (m.groupId == gid) return true;
        final uids = groupUserUids[gid] ?? {};
        final emails = groupUserEmails[gid] ?? {};
        return uids.contains(m.organizerUid) || emails.contains(m.createdBy) ||
               (m.assignedTo != null && (uids.contains(m.assignedTo) || emails.contains(m.assignedTo)));
      }

      // Step 1: For non-super-admin, ALWAYS scope to their team/group first
      if (userRole != UserRole.superAdmin) {
        if (userRole == UserRole.coordinator && userGroupId != null && userGroupId.isNotEmpty) {
          // Coordinator: restrict to their group
          results = results.where((m) =>
            meetingBelongsToGroup(m, userGroupId) ||
            m.organizerUid == widget.currentUser.uid ||
            m.createdBy == widget.currentUser.email ||
            m.guests.any((g) => g.email == widget.currentUser.email)
          ).toList();
        } else if (userTeamId != null && userTeamId.isNotEmpty) {
          // Admin/Manager/TL: restrict to their team
          results = results.where((m) =>
            meetingBelongsToTeam(m, userTeamId) ||
            m.organizerUid == widget.currentUser.uid ||
            m.createdBy == widget.currentUser.email ||
            m.guests.any((g) => g.email == widget.currentUser.email)
          ).toList();
        }
      }

      // Step 2: Apply hierarchy filter dropdowns (narrows further within allowed scope)
      if (_filterTeamId != null) {
        results = results.where((m) => meetingBelongsToTeam(m, _filterTeamId!)).toList();
      }
      if (_filterGroupId != null) {
        results = results.where((m) => meetingBelongsToGroup(m, _filterGroupId!)).toList();
      }
      // Filter by specific user
      if (_filterUserId != null) {
        final selectedUser = _allUsers.where((u) => u.uid == _filterUserId).firstOrNull;
        if (selectedUser != null) {
          results = results.where((m) {
            final isOrganizer = m.organizerUid == selectedUser.uid;
            final isGuest = m.guests.any((g) => g.email == selectedUser.email);
            final isAssigned = m.assignedTo == selectedUser.uid || m.assignedTo == selectedUser.email;
            final isCreator = m.createdBy == selectedUser.email;
            // Also check lead assignment
            bool isLeadAssignee = false;
            if (m.leadId != null) {
              final assignee = _leadAssigneeCache[m.leadId!];
              isLeadAssignee = assignee == selectedUser.uid || assignee == selectedUser.email;
            }
            return isOrganizer || isGuest || isAssigned || isCreator || isLeadAssignee;
          }).toList();
        }
      }
    }

    if (_filterPartyName != null && _filterPartyName!.isNotEmpty) {
      final query = _filterPartyName!.toLowerCase();
      results = results.where((m) {
        return m.title.toLowerCase().contains(query) ||
            (m.leadName?.toLowerCase().contains(query) ?? false) ||
            m.guests.any((g) => g.email.toLowerCase().contains(query) ||
                (g.name?.toLowerCase().contains(query) ?? false));
      }).toList();
    }
    if (_filterStatus != null) {
      results = results.where((m) => m.status == _filterStatus).toList();
    }
    return results;
  }

  List<Meeting> _getMeetingsForDate(DateTime date) {
    return _filteredMeetings.where((m) {
      return m.startTime.year == date.year &&
          m.startTime.month == date.month &&
          m.startTime.day == date.day;
    }).toList();
  }

  List<Meeting> _getMeetingsForWeek(DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 7));
    return _filteredMeetings.where((m) {
      return m.startTime.isAfter(weekStart.subtract(const Duration(days: 1))) &&
          m.startTime.isBefore(weekEnd);
    }).toList();
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  void _goToToday() {
    setState(() {
      _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
      _selectedDate = DateTime.now();
    });
  }

  void _openScheduleDialog({DateTime? preselectedDate}) {
    showDialog(
      context: context,
      builder: (ctx) => ScheduleMeetingDialog(
        currentUser: widget.currentUser,
        onMeetingCreated: _loadMeetings,
        preselectedDate: preselectedDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          // View type toggle
          if (MediaQuery.of(context).size.width > 500)
            SegmentedButton<CalendarViewType>(
              segments: const [
                ButtonSegment(
                  value: CalendarViewType.month,
                  label: Text('Month'),
                  icon: Icon(Icons.calendar_view_month, size: 18),
                ),
                ButtonSegment(
                  value: CalendarViewType.week,
                  label: Text('Week'),
                  icon: Icon(Icons.calendar_view_week, size: 18),
                ),
                ButtonSegment(
                  value: CalendarViewType.day,
                  label: Text('Day'),
                  icon: Icon(Icons.calendar_view_day, size: 18),
                ),
              ],
              selected: {_viewType},
              onSelectionChanged: (selection) {
                setState(() => _viewType = selection.first);
              },
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
              ),
            )
          else
            PopupMenuButton<CalendarViewType>(
              icon: const Icon(Icons.calendar_view_month),
              tooltip: 'View',
              onSelected: (v) => setState(() => _viewType = v),
              itemBuilder: (ctx) => [
                PopupMenuItem(value: CalendarViewType.month, child: Text('Month${_viewType == CalendarViewType.month ? " ✓" : ""}')),
                PopupMenuItem(value: CalendarViewType.week, child: Text('Week${_viewType == CalendarViewType.week ? " ✓" : ""}')),
                PopupMenuItem(value: CalendarViewType.day, child: Text('Day${_viewType == CalendarViewType.day ? " ✓" : ""}')),
              ],
            ),
          IconButton(
            icon: Badge(
              isLabelVisible: _filterPartyName != null || _filterStatus != null || _filterTeamId != null || _filterGroupId != null || _filterUserId != null,
              smallSize: 8,
              child: Icon(
                _showFilters ? Icons.filter_list_off : Icons.filter_list,
              ),
            ),
            onPressed: () => setState(() => _showFilters = !_showFilters),
            tooltip: 'Filters',
          ),
          if (MediaQuery.of(context).size.width > 400)
            TextButton.icon(
              onPressed: _goToToday,
              icon: const Icon(Icons.today),
              label: const Text('Today'),
            )
          else
            IconButton(
              icon: const Icon(Icons.today),
              onPressed: _goToToday,
              tooltip: 'Today',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMeetings,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filters panel
                if (_showFilters) _buildFiltersPanel(cs),
                // Month navigation header
                _buildMonthHeader(cs),
                // Calendar view based on type
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Calendar view
                      Expanded(
                        flex: 3,
                        child: _viewType == CalendarViewType.month
                            ? _buildCalendarGrid(cs)
                            : _viewType == CalendarViewType.week
                                ? _buildWeekView(cs)
                                : _buildDayView(cs),
                      ),
                      // Selected day panel (on wide screens)
                      if (MediaQuery.of(context).size.width > 800)
                        Container(
                          width: 320,
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                          child: _buildSelectedDayPanel(cs),
                        ),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: () => _openScheduleDialog(preselectedDate: _selectedDate),
        tooltip: 'New Meeting',
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
    );
  }

  Widget _buildCalendarHierarchyFilter() {
    final userRole = widget.currentUser.role;
    final userTeamId = widget.currentUser.teamId;
    final userGroupId = widget.currentUser.groupId;

    // For non-superadmin, restrict teams/groups to their own hierarchy
    var visibleTeams = _teams.toList();
    var visibleGroups = _groups.toList();
    if (userRole != UserRole.superAdmin) {
      if (userTeamId != null && userTeamId.isNotEmpty) {
        visibleTeams = _teams.where((t) => t['id'] == userTeamId).toList();
      } else {
        visibleTeams = [];
      }
      if (userRole == UserRole.coordinator && userGroupId != null && userGroupId.isNotEmpty) {
        visibleGroups = _groups.where((g) => g['id'] == userGroupId).toList();
      } else if (userTeamId != null && userTeamId.isNotEmpty) {
        visibleGroups = _groups.where((g) => g['team_id'] == userTeamId).toList();
      }
    }

    // Filter groups by selected team
    final filteredGroups = _filterTeamId != null
        ? visibleGroups.where((g) => g['team_id'] == _filterTeamId).toList()
        : visibleGroups;
    // Filter users by selected team/group
    var filteredUsers = _allUsers.toList();
    // Non-superadmin: restrict visible users to their team
    if (userRole != UserRole.superAdmin && userTeamId != null && userTeamId.isNotEmpty) {
      filteredUsers = filteredUsers.where((u) => u.teamId == userTeamId).toList();
    }
    if (_filterTeamId != null) {
      filteredUsers = filteredUsers.where((u) => u.teamId == _filterTeamId).toList();
    }
    if (_filterGroupId != null) {
      filteredUsers = filteredUsers.where((u) => u.groupId == _filterGroupId).toList();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Team dropdown
          SizedBox(
            width: 160,
            child: DropdownButtonFormField<String>(
              value: _filterTeamId,
              isDense: true,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Team',
                labelStyle: const TextStyle(fontSize: 12),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
              ),
              items: [
                const DropdownMenuItem<String>(value: null, child: Text('All Teams', style: TextStyle(fontSize: 12))),
                ...visibleTeams.map((t) => DropdownMenuItem<String>(
                  value: t['id'] as String,
                  child: Text(t['name'] as String? ?? '', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                )),
              ],
              onChanged: (v) => setState(() {
                _filterTeamId = v;
                _filterGroupId = null;
                _filterUserId = null;
                _selectedMemberUid = null;
              }),
            ),
          ),
          const SizedBox(width: 8),
          // Group dropdown
          SizedBox(
            width: 160,
            child: DropdownButtonFormField<String>(
              value: _filterGroupId,
              isDense: true,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Group',
                labelStyle: const TextStyle(fontSize: 12),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
              ),
              items: [
                const DropdownMenuItem<String>(value: null, child: Text('All Groups', style: TextStyle(fontSize: 12))),
                ...filteredGroups.map((g) => DropdownMenuItem<String>(
                  value: g['id'] as String,
                  child: Text(g['name'] as String? ?? '', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                )),
              ],
              onChanged: (v) => setState(() {
                _filterGroupId = v;
                _filterUserId = null;
                _selectedMemberUid = null;
              }),
            ),
          ),
          const SizedBox(width: 8),
          // User dropdown
          SizedBox(
            width: 160,
            child: DropdownButtonFormField<String>(
              value: _filterUserId,
              isDense: true,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'User',
                labelStyle: const TextStyle(fontSize: 12),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
              ),
              items: [
                const DropdownMenuItem<String>(value: null, child: Text('All Users', style: TextStyle(fontSize: 12))),
                ...filteredUsers.map((u) => DropdownMenuItem<String>(
                  value: u.uid,
                  child: Text(u.name.isNotEmpty ? u.name : u.email, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                )),
              ],
              onChanged: (v) => setState(() {
                _filterUserId = v;
                _selectedMemberUid = v; // Sync with legacy member filter
              }),
            ),
          ),
          // Clear button
          if (_filterTeamId != null || _filterGroupId != null || _filterUserId != null) ...[
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => setState(() {
                _filterTeamId = null;
                _filterGroupId = null;
                _filterUserId = null;
                _selectedMemberUid = null;
              }),
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Clear', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange.shade700,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFiltersPanel(ColorScheme cs) {
    final isNarrow = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Calendar View: My / Team toggle
            if (widget.currentUser.role != UserRole.member) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Text('Calendar View: ', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                    const SizedBox(width: 8),
                    SegmentedButton<String>(
                      segments: [
                        const ButtonSegment(value: 'my', label: Text('My Calendar'), icon: Icon(Icons.person, size: 16)),
                        ButtonSegment(
                          value: 'team',
                          label: Text(widget.currentUser.role == UserRole.coordinator ? 'Group Calendar' : 'Team Calend..'),
                          icon: const Icon(Icons.groups, size: 16),
                        ),
                      ],
                      selected: {_calendarScope},
                      onSelectionChanged: (selection) {
                        setState(() {
                          _calendarScope = selection.first;
                          if (_calendarScope == 'my') {
                            _selectedMemberUid = null;
                            _filterTeamId = null;
                            _filterGroupId = null;
                            _filterUserId = null;
                          }
                        });
                      },
                      style: const ButtonStyle(visualDensity: VisualDensity.compact),
                    ),
                  ],
                ),
              ),
            ],
            // Hierarchy filter: Team > Group > User (when team view is selected)
            if (_calendarScope == 'team') ...[
              const SizedBox(height: 12),
              _buildCalendarHierarchyFilter(),
            ],
            const SizedBox(height: 12),
            // Existing filters - responsive layout
            if (isNarrow) ...[
              // Stack filters vertically on mobile
              TextField(
                decoration: InputDecoration(
                  labelText: 'Search by name/party',
                  hintText: 'Enter name...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (value) {
                  setState(() {
                    _filterPartyName = value.isEmpty ? null : value;
                  });
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<MeetingStatus?>(
                value: _filterStatus,
                decoration: InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All Status'),
                  ),
                  ...MeetingStatus.values.map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.label),
                      )),
                ],
                onChanged: (value) {
                  setState(() => _filterStatus = value);
                },
              ),
              if (_filterPartyName != null || _filterStatus != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _filterPartyName = null;
                      _filterStatus = null;
                    });
                  },
                  icon: const Icon(Icons.clear, size: 18),
                  label: const Text('Clear filters'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ] else ...[
              Row(
                children: [
                  // Party/Name search
                  SizedBox(
                    width: 250,
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'Search by name/party',
                        hintText: 'Enter name...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _filterPartyName = value.isEmpty ? null : value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Status filter
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<MeetingStatus?>(
                      value: _filterStatus,
                      decoration: InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Status'),
                        ),
                        ...MeetingStatus.values.map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(s.label),
                            )),
                      ],
                      onChanged: (value) {
                        setState(() => _filterStatus = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Clear filters button
                  if (_filterPartyName != null || _filterStatus != null)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _filterPartyName = null;
                          _filterStatus = null;
                        });
                      },
                      icon: const Icon(Icons.clear, size: 18),
                      label: const Text('Clear'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWeekView(ColorScheme cs) {
    // Get the start of the week (Monday) for the selected date
    final selected = _selectedDate ?? DateTime.now();
    final weekStart =
        selected.subtract(Duration(days: selected.weekday - 1));
    final weekMeetings = _getMeetingsForWeek(weekStart);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Week header with day names
          Row(
            children: List.generate(7, (index) {
              final day = weekStart.add(Duration(days: index));
              final isToday = day.year == DateTime.now().year &&
                  day.month == DateTime.now().month &&
                  day.day == DateTime.now().day;
              final isSelected = _selectedDate != null &&
                  day.year == _selectedDate!.year &&
                  day.month == _selectedDate!.month &&
                  day.day == _selectedDate!.day;

              return Expanded(
                child: InkWell(
                  onTap: () => setState(() => _selectedDate = day),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? cs.primaryContainer
                          : isToday
                              ? cs.secondaryContainer.withOpacity(0.5)
                              : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          DateFormat('EEE').format(day),
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: isSelected ? cs.onPrimaryContainer : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? cs.onPrimaryContainer : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          const Divider(),
          // Week meetings list
          if (weekMeetings.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No meetings this week',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ...weekMeetings.map((meeting) => _buildMeetingCard(meeting, cs)),
        ],
      ),
    );
  }

  Widget _buildDayView(ColorScheme cs) {
    final selected = _selectedDate ?? DateTime.now();
    final dayMeetings = _getMeetingsForDate(selected);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE').format(selected),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      DateFormat('MMMM d, yyyy').format(selected),
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  '${dayMeetings.length} meeting${dayMeetings.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Day meetings
          if (dayMeetings.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No meetings scheduled for this day',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ...dayMeetings.map((meeting) => _buildMeetingCard(meeting, cs)),
        ],
      ),
    );
  }

  Widget _buildMeetingCard(Meeting meeting, ColorScheme cs) {
    final statusColor = meeting.status == MeetingStatus.confirmed
        ? Colors.green
        : meeting.status == MeetingStatus.cancelled
            ? Colors.red
            : meeting.status == MeetingStatus.completed
                ? Colors.blue
                : Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: meeting.leadId != null ? () => _navigateToLeadDetail(meeting.leadId!) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meeting.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              meeting.leadName ?? '',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                              ),
                            ),
                            if (meeting.leadId != null) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.open_in_new, size: 14, color: cs.primary),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      meeting.status.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '${DateFormat('MMM d').format(meeting.startTime)} - ${DateFormat('h:mm a').format(meeting.startTime)}',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 16),
                  if (meeting.location?.isNotEmpty == true) ...[
                    Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        meeting.location ?? '',
                        style: TextStyle(color: Colors.grey.shade600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToLeadDetail(String leadId) async {
    try {
      final leadService = LeadService();
      final lead = await leadService.getLeadById(leadId);
      if (lead != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LeadDetailScreen(
              lead: lead,
              currentUser: widget.currentUser,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load lead details: $e')),
        );
      }
    }
  }

  Widget _buildMonthHeader(ColorScheme cs) {
    final monthYear = DateFormat('MMMM yyyy').format(_currentMonth);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _previousMonth,
            tooltip: 'Previous month',
          ),
          Expanded(
            child: Text(
              monthYear,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _nextMonth,
            tooltip: 'Next month',
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(ColorScheme cs) {
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final startingWeekday = firstDayOfMonth.weekday; // 1 = Monday, 7 = Sunday

    // Calculate previous month days to show
    final previousMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    final daysInPreviousMonth = DateTime(previousMonth.year, previousMonth.month + 1, 0).day;

    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final today = DateTime.now();

    return Column(
      children: [
        // Weekday headers
        Container(
          color: cs.primaryContainer.withOpacity(0.3),
          child: Row(
            children: weekdays.map((day) {
              final isWeekend = day == 'Sat' || day == 'Sun';
              return Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isWeekend ? Colors.red.shade400 : cs.onSurface,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        // Calendar days grid
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Calculate optimal aspect ratio: fill available height
              final availableHeight = constraints.maxHeight;
              final cellWidth = constraints.maxWidth / 7;
              final cellHeight = availableHeight / 6; // 6 weeks
              final ratio = cellWidth / cellHeight;
              return GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: ratio > 0 ? ratio : 1.0,
            ),
            itemCount: 42, // 6 weeks
            itemBuilder: (context, index) {
              int dayNumber;
              bool isCurrentMonth = true;
              bool isPreviousMonth = false;

              if (index < startingWeekday - 1) {
                // Previous month
                dayNumber = daysInPreviousMonth - (startingWeekday - 2 - index);
                isCurrentMonth = false;
                isPreviousMonth = true;
              } else if (index - startingWeekday + 2 > daysInMonth) {
                // Next month
                dayNumber = index - startingWeekday + 2 - daysInMonth;
                isCurrentMonth = false;
              } else {
                // Current month
                dayNumber = index - startingWeekday + 2;
              }

              DateTime date;
              if (isPreviousMonth) {
                date = DateTime(previousMonth.year, previousMonth.month, dayNumber);
              } else if (!isCurrentMonth) {
                date = DateTime(_currentMonth.year, _currentMonth.month + 1, dayNumber);
              } else {
                date = DateTime(_currentMonth.year, _currentMonth.month, dayNumber);
              }

              final isToday = isCurrentMonth &&
                  date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
              final isSelected = _selectedDate != null &&
                  date.year == _selectedDate!.year &&
                  date.month == _selectedDate!.month &&
                  date.day == _selectedDate!.day;
              final isWeekend = index % 7 == 5 || index % 7 == 6;
              final meetingsForDay = _getMeetingsForDate(date);

              return _buildDayCell(
                date,
                dayNumber,
                isCurrentMonth,
                isToday,
                isSelected,
                isWeekend,
                meetingsForDay,
                cs,
              );
            },
          );
          },
          ),
        ),
        // Selected day meetings (on narrow screens)
        if (MediaQuery.of(context).size.width <= 800 && _selectedDate != null)
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: _buildSelectedDayPanel(cs),
          ),
      ],
    );
  }

  Widget _buildDayCell(
    DateTime date,
    int dayNumber,
    bool isCurrentMonth,
    bool isToday,
    bool isSelected,
    bool isWeekend,
    List<Meeting> meetings,
    ColorScheme cs,
  ) {
    final isMobile = MediaQuery.of(context).size.width <= 800;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedDate = date;
        });
      },
      onDoubleTap: () {
        _openScheduleDialog(preselectedDate: date);
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primaryContainer.withOpacity(0.5)
              : isToday
                  ? cs.primary.withOpacity(0.1)
                  : null,
          border: Border.all(
            color: isSelected
                ? cs.primary
                : Colors.grey.shade200,
            width: isSelected ? 2 : 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day number
            Padding(
              padding: const EdgeInsets.all(4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isToday ? cs.primary : null,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$dayNumber',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                        color: isToday
                            ? Colors.white
                            : !isCurrentMonth
                                ? Colors.grey.shade400
                                : isWeekend
                                    ? Colors.red.shade400
                                    : null,
                      ),
                    ),
                  ),
                  if (meetings.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${meetings.length}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Meeting previews (desktop only - mobile shows details in panel below)
            if (!isMobile) ...[
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: meetings.take(3).map((meeting) {
                      return _buildMeetingChip(meeting);
                    }).toList(),
                  ),
                ),
              ),
              if (meetings.length > 3)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  child: Text(
                    '+${meetings.length - 3} more',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ] else ...[
              // Mobile: show colored dots only
              if (meetings.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 2),
                  child: Wrap(
                    spacing: 2,
                    children: meetings.take(4).map((m) {
                      return Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _getStatusColor(m.status),
                          shape: BoxShape.circle,
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.superAdmin: return Colors.red;
      case UserRole.admin: return Colors.deepPurple;
      case UserRole.manager: return Colors.blue;
      case UserRole.teamLead: return Colors.teal;
      case UserRole.coordinator: return Colors.orange;
      case UserRole.member: return Colors.grey;
    }
  }

  Widget _buildMeetingChip(Meeting meeting) {
    final statusColor = _getStatusColor(meeting.status);
    final timeStr = DateFormat('HH:mm').format(meeting.startTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border(
          left: BorderSide(color: statusColor, width: 3),
        ),
      ),
      child: Row(
        children: [
          Text(
            timeStr,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              meeting.title,
              style: const TextStyle(fontSize: 9),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedDayPanel(ColorScheme cs) {
    if (_selectedDate == null) {
      return const Center(child: Text('Select a date'));
    }

    final meetings = _getMeetingsForDate(_selectedDate!);
    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate!);

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cs.primaryContainer.withOpacity(0.5), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateStr,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${meetings.length} meeting${meetings.length == 1 ? '' : 's'}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        // Meetings list
        Expanded(
          child: meetings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_available,
                          size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 8),
                      Text(
                        'No meetings',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Use + button to add',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: meetings.length,
                  itemBuilder: (context, index) {
                    final meeting = meetings[index];
                    return _MeetingDetailCard(
                      meeting: meeting,
                      onStatusChange: (status) async {
                        await _calendarService.updateMeetingStatus(
                            meeting.id, status);
                        _loadMeetings();
                      },
                      onViewLead: meeting.leadId != null
                          ? () => _navigateToLeadDetail(meeting.leadId!)
                          : null,
                      onEdit: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => ScheduleMeetingDialog(
                            currentUser: widget.currentUser,
                            existingMeeting: meeting,
                            onMeetingCreated: _loadMeetings,
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Color _getStatusColor(MeetingStatus status) {
    switch (status) {
      case MeetingStatus.scheduled:
        return Colors.blue;
      case MeetingStatus.confirmed:
        return Colors.green;
      case MeetingStatus.inProgress:
        return Colors.orange;
      case MeetingStatus.completed:
        return Colors.grey;
      case MeetingStatus.cancelled:
        return Colors.red;
      case MeetingStatus.rescheduled:
        return Colors.purple;
      case MeetingStatus.noShow:
        return Colors.brown;
    }
  }
}

class _MeetingDetailCard extends StatelessWidget {
  final Meeting meeting;
  final Function(MeetingStatus) onStatusChange;
  final VoidCallback? onViewLead;
  final VoidCallback? onEdit;

  const _MeetingDetailCard({
    required this.meeting,
    required this.onStatusChange,
    this.onViewLead,
    this.onEdit,
  });

  Color _getStatusColor(MeetingStatus status) {
    switch (status) {
      case MeetingStatus.scheduled:
        return Colors.blue;
      case MeetingStatus.confirmed:
        return Colors.green;
      case MeetingStatus.inProgress:
        return Colors.orange;
      case MeetingStatus.completed:
        return Colors.grey;
      case MeetingStatus.cancelled:
        return Colors.red;
      case MeetingStatus.rescheduled:
        return Colors.purple;
      case MeetingStatus.noShow:
        return Colors.brown;
    }
  }

  IconData _getTypeIcon(MeetingType type) {
    switch (type) {
      case MeetingType.googleMeet:
        return Icons.videocam;
      case MeetingType.phoneCall:
        return Icons.phone;
      case MeetingType.inPerson:
        return Icons.people;
      case MeetingType.other:
        return Icons.event;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final statusColor = _getStatusColor(meeting.status);
    final timeStr =
        '${meeting.startTime.hour.toString().padLeft(2, '0')}:${meeting.startTime.minute.toString().padLeft(2, '0')} - ${meeting.endTime.hour.toString().padLeft(2, '0')}:${meeting.endTime.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    _getTypeIcon(meeting.type),
                    color: statusColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meeting.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        timeStr,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    meeting.status.label,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (meeting.leadName != null) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: onViewLead,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person_outline, size: 14, color: Colors.blue.shade600),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          meeting.leadName!,
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (onViewLead != null) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.open_in_new, size: 12, color: Colors.blue.shade600),
                        const SizedBox(width: 4),
                        Text(
                          'View Lead',
                          style: TextStyle(
                            color: Colors.blue.shade600,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            // Show meeting description/agenda if available
            if (meeting.description != null && meeting.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.subject, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        meeting.description!,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Show guests if available
            if (meeting.guests.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.people_outline, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Guests: ${meeting.guests.map((g) => g.name ?? g.email).join(", ")}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            // Show location if available
            if (meeting.location != null && meeting.location!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      meeting.location!,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (meeting.meetLink != null && meeting.meetLink!.isNotEmpty && meeting.meetLink != 'pending') ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final link = meeting.meetLink!;
                    final urlStr = link.startsWith('http') ? link : 'https://$link';
                    try {
                      final uri = Uri.parse(urlStr);
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } catch (e) {
                      debugPrint('Could not launch meeting link: $e');
                    }
                  },
                  icon: const Icon(Icons.video_call, size: 16),
                  label: const Text('Join Meeting'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
            // Action buttons
            const Divider(height: 16),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              runSpacing: 4,
              children: [
                // Edit button - always visible unless meeting is from lead fallback
                if (onEdit != null && !meeting.id.startsWith('lead_'))
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit, size: 14),
                    label: const Text('Edit', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue.shade700,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                if (meeting.status != MeetingStatus.completed &&
                    meeting.status != MeetingStatus.cancelled) ...[
                  if (meeting.status == MeetingStatus.scheduled) ...[
                    TextButton(
                      onPressed: () => onStatusChange(MeetingStatus.confirmed),
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                      child: const Text('Confirm', style: TextStyle(fontSize: 12)),
                    ),
                    TextButton(
                      onPressed: () => onStatusChange(MeetingStatus.cancelled),
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                      child: Text('Cancel',
                          style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
                    ),
                  ],
                  if (meeting.status == MeetingStatus.confirmed) ...[
                    TextButton(
                      onPressed: () => onStatusChange(MeetingStatus.inProgress),
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                      child: const Text('Start', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                  if (meeting.status == MeetingStatus.inProgress) ...[
                    TextButton(
                      onPressed: () => onStatusChange(MeetingStatus.completed),
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                      child: const Text('Complete', style: TextStyle(fontSize: 12)),
                    ),
                    TextButton(
                      onPressed: () => onStatusChange(MeetingStatus.noShow),
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                      child: const Text('No Show', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
