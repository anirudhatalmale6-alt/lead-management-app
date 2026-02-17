import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/lead.dart';
import '../models/lead_history.dart';
import '../models/email_template.dart';
import '../models/meeting.dart';
import '../models/user.dart';
import '../services/lead_service.dart';
import '../services/email_service.dart';
import '../services/calendar_service.dart';
import '../services/user_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/send_email_dialog.dart';
import '../widgets/schedule_meeting_dialog.dart';

class LeadDetailScreen extends StatefulWidget {
  final Lead lead;
  final VoidCallback? onEditPressed;
  final AppUser? currentUser;

  const LeadDetailScreen({
    super.key,
    required this.lead,
    this.onEditPressed,
    this.currentUser,
  });

  @override
  State<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends State<LeadDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final LeadService _leadService = LeadService();
  final EmailService _emailService = EmailService();
  final CalendarService _calendarService = CalendarService();
  final UserService _userService = UserService();
  final FirestoreService _firestoreService = FirestoreService();
  List<LeadHistory> _history = [];
  List<EmailLog> _emailLogs = [];
  List<Meeting> _meetings = [];
  List<_TimelineEntry> _combinedTimeline = []; // Combined history + email logs
  bool _loadingHistory = true;
  bool _loadingEmails = true;
  bool _loadingMeetings = true;

  // Users for assignment dropdowns
  List<AppUser> _allUsers = [];
  List<AppUser> _employees = [];
  List<AppUser> _managers = [];
  List<AppUser> _teamLeads = [];
  bool _loadingUsers = true;

  // Teams and Groups for lookup
  Map<String, String> _teamNames = {}; // id -> name
  Map<String, String> _groupNames = {}; // id -> name

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadHistory();
    _loadUsers();
    _loadEmailLogs();
    _loadMeetings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final history = await _leadService.getLeadHistory(widget.lead.id);
      if (mounted) {
        setState(() {
          _history = history;
          _loadingHistory = false;
          _buildCombinedTimeline();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingHistory = false);
      }
    }
  }

  Future<void> _loadEmailLogs() async {
    try {
      final logs = await _emailService.getEmailLogsForLead(widget.lead.id);
      if (mounted) {
        setState(() {
          _emailLogs = logs;
          _loadingEmails = false;
          _buildCombinedTimeline();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingEmails = false);
      }
    }
  }

  void _buildCombinedTimeline() {
    _combinedTimeline = [];

    // Add history entries
    for (final entry in _history) {
      _combinedTimeline.add(_TimelineEntry(
        type: _TimelineType.history,
        timestamp: entry.updatedAt,
        historyEntry: entry,
      ));
    }

    // Add email logs
    for (final email in _emailLogs) {
      _combinedTimeline.add(_TimelineEntry(
        type: _TimelineType.email,
        timestamp: email.sentAt,
        emailLog: email,
      ));
    }

    // Add meetings to timeline
    for (final meeting in _meetings) {
      _combinedTimeline.add(_TimelineEntry(
        type: _TimelineType.meeting,
        timestamp: meeting.createdAt,
        meeting: meeting,
      ));
    }

    // Sort by timestamp descending (most recent first)
    _combinedTimeline.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<void> _loadMeetings() async {
    try {
      final meetings = await _calendarService.getMeetingsForLead(widget.lead.id);
      if (mounted) {
        setState(() {
          _meetings = meetings;
          _loadingMeetings = false;
          _buildCombinedTimeline(); // Rebuild timeline to include meetings
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingMeetings = false);
      }
    }
  }

  Future<void> _loadUsers() async {
    try {
      final allUsers = await _userService.getAllUsers();
      // Also load teams and groups for name lookup
      final teams = await _firestoreService.getTeams();
      final groups = await _firestoreService.getGroups();

      if (mounted) {
        setState(() {
          _allUsers = allUsers;
          _employees = allUsers.where((u) => u.role == UserRole.member).toList();
          _managers = allUsers.where((u) => u.role == UserRole.manager).toList();
          _teamLeads = allUsers.where((u) => u.role == UserRole.teamLead).toList();
          // Build team/group name maps
          _teamNames = {for (var t in teams) t['id'] as String: t['name'] as String? ?? ''};
          _groupNames = {for (var g in groups) g['id'] as String: g['name'] as String? ?? ''};
          _loadingUsers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingUsers = false);
      }
    }
  }

  void _openSendEmailDialog() {
    if (widget.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => SendEmailDialog(
        lead: widget.lead,
        currentUser: widget.currentUser!,
      ),
    ).then((sent) {
      if (sent == true) {
        _loadEmailLogs();
        _loadHistory();
      }
    });
  }

  void _openScheduleMeetingDialog() {
    if (widget.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => ScheduleMeetingDialog(
        lead: widget.lead,
        currentUser: widget.currentUser!,
        onMeetingCreated: () {
          _loadMeetings();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lead = widget.lead;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(lead.clientName),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam),
            tooltip: 'Schedule Meeting',
            onPressed: _openScheduleMeetingDialog,
          ),
          IconButton(
            icon: const Icon(Icons.email),
            tooltip: 'Send Email',
            onPressed: _openSendEmailDialog,
          ),
          if (widget.onEditPressed != null)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: widget.onEditPressed,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Details'),
            Tab(text: 'History'),
            Tab(text: 'Meetings'),
            Tab(text: 'Emails'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDetailsTab(lead, cs),
          _buildHistoryTab(cs),
          _buildMeetingsTab(cs),
          _buildEmailsTab(cs),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Details Tab - Two Column Layout for Desktop
  // ---------------------------------------------------------------------------

  Widget _buildDetailsTab(Lead lead, ColorScheme cs) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;

        if (isWide) {
          return _buildWideDetailsLayout(lead, cs);
        } else {
          return _buildNarrowDetailsLayout(lead, cs);
        }
      },
    );
  }

  Widget _buildWideDetailsLayout(Lead lead, ColorScheme cs) {
    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column - Main Info (expanded to fill space)
          Expanded(
            flex: 5,
            child: Column(
              children: [
                // Status badges row
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _badge(lead.stage.label, AppTheme.stageColor(lead.stage.label)),
                    _badge(lead.health.label, AppTheme.healthColor(lead.health.label)),
                    _badge(lead.activityState.label,
                        AppTheme.activityColor(lead.activityState.label)),
                    _badge(lead.paymentStatus.label,
                        AppTheme.paymentColor(lead.paymentStatus.label)),
                    _badge('Rating: ${lead.rating}', cs.primary),
                  ],
                ),
                const SizedBox(height: 20),

                // Client Information
                _sectionCard('Client Information', [
                  _infoRow('Name', lead.clientName),
                  _infoRow('Business', lead.clientBusinessName),
                  _infoRow('Mobile', lead.clientMobile),
                  _infoRow('WhatsApp', lead.clientWhatsApp),
                  _infoRow('Email', lead.clientEmail),
                  _infoRow('Country', lead.country),
                  _infoRow('State', lead.state),
                  _infoRow('City', lead.clientCity),
                ]),
                const SizedBox(height: 12),

                // Product / Service
                _sectionCard('Product / Service', [
                  _infoRow('Interested In', lead.interestedInProduct.label),
                ]),
                const SizedBox(height: 12),

                // Notes & Comment
                _sectionCard('Notes & Comments', [
                  _infoRow('Notes', lead.notes.isNotEmpty ? lead.notes : '-'),
                  _infoRow('Comment', lead.comment.isNotEmpty ? lead.comment : '-'),
                ]),
                const SizedBox(height: 12),

                // Submitter Info
                _sectionCard('Creator Info', [
                  _infoRow('Name',
                      lead.submitterName.isNotEmpty ? lead.submitterName : '-'),
                  _infoRow('Email',
                      lead.submitterEmail.isNotEmpty ? lead.submitterEmail : '-'),
                  _infoRow('Mobile',
                      lead.submitterMobile.isNotEmpty ? lead.submitterMobile : '-'),
                  _infoRow('Team', _resolveTeamName(lead)),
                  _infoRow('Group', _resolveGroupName(lead)),
                  _infoRow('Role', lead.submitterRole.isNotEmpty ? lead.submitterRole : (lead.createdBy.isNotEmpty ? '-' : widget.currentUser?.role.label ?? '-')),
                ]),
                const SizedBox(height: 12),

                // Quick Follow-up Update Card (Activity) - MOVED TO LEFT
                SelectionContainer.disabled(child: _buildQuickFollowUpUpdateCard(lead, cs)),
                const SizedBox(height: 12),

                // Assignment & Tagging Card - MOVED TO LEFT
                SelectionContainer.disabled(child: _buildAssignmentCard(lead, cs)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Right Column - Quick Actions & Stats (compact)
          Expanded(
            flex: 3,
            child: Column(
              children: [
                // Quick Actions Card
                SelectionContainer.disabled(child: _buildQuickActionsCard(lead, cs)),
                const SizedBox(height: 12),

                // Meeting Info Card
                _buildMeetingInfoCard(lead, cs),
                const SizedBox(height: 12),

                // Follow-up Card
                _buildFollowUpCard(lead, cs),
                const SizedBox(height: 12),

                // Activity Summary Card
                _buildActivitySummaryCard(lead, cs),
                const SizedBox(height: 12),

                // Timestamps & Meta
                _sectionCard('Timestamps & Meta', [
                  _infoRow('Created At',
                      DateFormat('dd MMM yyyy, hh:mm a').format(lead.createdAt)),
                  _infoRow('Last Updated At',
                      DateFormat('dd MMM yyyy, hh:mm a').format(lead.updatedAt)),
                  _infoRow('Last Updated By',
                      lead.lastUpdatedBy.isNotEmpty ? lead.lastUpdatedBy : '-'),
                  _infoRow('Created By',
                      lead.createdBy.isNotEmpty ? lead.createdBy : '-'),
                ]),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildNarrowDetailsLayout(Lead lead, ColorScheme cs) {
    return SelectionArea(
      child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Status badges row
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _badge(lead.stage.label, AppTheme.stageColor(lead.stage.label)),
            _badge(lead.health.label, AppTheme.healthColor(lead.health.label)),
            _badge(lead.activityState.label,
                AppTheme.activityColor(lead.activityState.label)),
            _badge(lead.paymentStatus.label,
                AppTheme.paymentColor(lead.paymentStatus.label)),
            _badge('Rating: ${lead.rating}', cs.primary),
          ],
        ),
        const SizedBox(height: 20),

        // Quick Actions Card
        SelectionContainer.disabled(child: _buildQuickActionsCard(lead, cs)),
        const SizedBox(height: 12),

        // Client Information
        _sectionCard('Client Information', [
          _infoRow('Name', lead.clientName),
          _infoRow('Business', lead.clientBusinessName),
          _infoRow('Mobile', lead.clientMobile),
          _infoRow('WhatsApp', lead.clientWhatsApp),
          _infoRow('Email', lead.clientEmail),
          _infoRow('Country', lead.country),
          _infoRow('State', lead.state),
          _infoRow('City', lead.clientCity),
        ]),
        const SizedBox(height: 12),

        // Product / Service
        _sectionCard('Product / Service', [
          _infoRow('Interested In', lead.interestedInProduct.label),
        ]),
        const SizedBox(height: 12),

        // Meeting
        _buildMeetingInfoCard(lead, cs),
        const SizedBox(height: 12),

        // Follow-up
        _buildFollowUpCard(lead, cs),
        const SizedBox(height: 12),

        // Quick Follow-up Update
        SelectionContainer.disabled(child: _buildQuickFollowUpUpdateCard(lead, cs)),
        const SizedBox(height: 12),

        // Notes & Comment
        _sectionCard('Notes & Comments', [
          _infoRow('Notes', lead.notes.isNotEmpty ? lead.notes : '-'),
          _infoRow('Comment', lead.comment.isNotEmpty ? lead.comment : '-'),
        ]),
        const SizedBox(height: 12),

        // Submitter Info
        _sectionCard('Creator Info', [
          _infoRow('Name',
              lead.submitterName.isNotEmpty ? lead.submitterName : '-'),
          _infoRow('Email',
              lead.submitterEmail.isNotEmpty ? lead.submitterEmail : '-'),
          _infoRow('Mobile',
              lead.submitterMobile.isNotEmpty ? lead.submitterMobile : '-'),
          _infoRow(
              'Team', lead.groupName.isNotEmpty ? lead.groupName : '-'),
          _infoRow(
              'Group', lead.subGroup.isNotEmpty ? lead.subGroup : '-'),
          _infoRow('Role', lead.submitterRole.isNotEmpty ? lead.submitterRole : (lead.createdBy.isNotEmpty ? '-' : widget.currentUser?.role.label ?? '-')),
        ]),
        const SizedBox(height: 12),

        // Assignment & Tagging Card
        SelectionContainer.disabled(child: _buildAssignmentCard(lead, cs)),
        const SizedBox(height: 12),

        // Timestamps & Meta
        _sectionCard('Timestamps & Meta', [
          _infoRow('Created At',
              DateFormat('dd MMM yyyy, hh:mm a').format(lead.createdAt)),
          _infoRow('Last Updated At',
              DateFormat('dd MMM yyyy, hh:mm a').format(lead.updatedAt)),
          _infoRow('Last Updated By',
              lead.lastUpdatedBy.isNotEmpty ? lead.lastUpdatedBy : '-'),
          _infoRow('Created By',
              lead.createdBy.isNotEmpty ? lead.createdBy : '-'),
        ]),
        const SizedBox(height: 24),
      ],
      ),
    );
  }

  Widget _buildQuickActionsCard(Lead lead, ColorScheme cs) {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.primaryContainer.withOpacity(0.5), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flash_on, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                const Text('Quick Actions',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _actionButton(
                    icon: Icons.videocam,
                    label: 'Meeting',
                    color: Colors.purple,
                    onTap: _openScheduleMeetingDialog,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _actionButton(
                    icon: Icons.email,
                    label: 'Email',
                    color: Colors.blue,
                    onTap: _openSendEmailDialog,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _actionButton(
                    icon: Icons.chat,
                    label: 'WhatsApp',
                    color: Colors.green,
                    onTap: lead.clientWhatsApp.isNotEmpty
                        ? () {
                            final url = Uri.parse('https://wa.me/${lead.clientWhatsApp}');
                            launchUrl(url, mode: LaunchMode.externalApplication);
                          }
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _actionButton(
                    icon: Icons.phone,
                    label: 'Call',
                    color: Colors.teal,
                    onTap: lead.clientMobile.isNotEmpty
                        ? () {
                            final url = Uri.parse('tel:${lead.clientMobile}');
                            launchUrl(url);
                          }
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    final isEnabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isEnabled ? color.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isEnabled ? color.withOpacity(0.3) : Colors.grey.shade300,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isEnabled ? color : Colors.grey, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isEnabled ? color : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeetingInfoCard(Lead lead, ColorScheme cs) {
    final hasMeeting = lead.meetingDate != null;
    return Card(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple.withOpacity(0.1), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.videocam, color: Colors.purple, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Meeting Info',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                if (hasMeeting)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Scheduled',
                        style: TextStyle(
                            color: Colors.green,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _iconInfoRow(Icons.event, 'Agenda', lead.meetingAgenda.label),
            _iconInfoRow(
                Icons.calendar_today,
                'Date',
                lead.meetingDate != null
                    ? '${lead.meetingDate!.day}/${lead.meetingDate!.month}/${lead.meetingDate!.year}'
                    : 'Not scheduled'),
            _iconInfoRow(Icons.access_time, 'Time',
                lead.meetingTime.isNotEmpty ? lead.meetingTime : '-'),
            if (lead.meetingLink.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final url = Uri.parse(lead.meetingLink);
                      launchUrl(url, mode: LaunchMode.externalApplication);
                    },
                    icon: const Icon(Icons.video_call, size: 18),
                    label: const Text('Join Meeting'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowUpCard(Lead lead, ColorScheme cs) {
    final hasFollowUp = lead.nextFollowUpDate != null;
    final isOverdue = hasFollowUp && lead.nextFollowUpDate!.isBefore(DateTime.now());

    return Card(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              isOverdue ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
              Colors.white
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isOverdue
                        ? Colors.red.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.notification_important,
                      color: isOverdue ? Colors.red : Colors.orange, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Follow-up',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                if (isOverdue)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('OVERDUE',
                        style: TextStyle(
                            color: Colors.red,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _iconInfoRow(
                Icons.history,
                'Last Call',
                lead.lastCallDate != null
                    ? '${lead.lastCallDate!.day}/${lead.lastCallDate!.month}/${lead.lastCallDate!.year}'
                    : 'Never'),
            _iconInfoRow(
                Icons.event_note,
                'Next Follow-up',
                lead.nextFollowUpDate != null
                    ? '${lead.nextFollowUpDate!.day}/${lead.nextFollowUpDate!.month}/${lead.nextFollowUpDate!.year}'
                    : 'Not scheduled'),
            _iconInfoRow(Icons.schedule, 'Time',
                lead.nextFollowUpTime.isNotEmpty ? lead.nextFollowUpTime : '-'),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickFollowUpUpdateCard(Lead lead, ColorScheme cs) {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.withOpacity(0.1), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.update, color: Colors.teal, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Quick Followup Update',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                // Quick update button
                FilledButton.icon(
                  onPressed: () => _showQuickUpdateDialog(lead),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Update'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Status dropdowns row 1
            Row(
              children: [
                Expanded(
                  child: _buildQuickStatusBadge(
                    'Rating',
                    '${lead.rating}',
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildQuickStatusBadge(
                    'Lead Health',
                    lead.health.label,
                    AppTheme.healthColor(lead.health.label),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Status dropdowns row 2
            Row(
              children: [
                Expanded(
                  child: _buildQuickStatusBadge(
                    'Sales Stage',
                    lead.stage.label,
                    AppTheme.stageColor(lead.stage.label),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildQuickStatusBadge(
                    'Activity State',
                    lead.activityState.label,
                    AppTheme.activityColor(lead.activityState.label),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Payment status
            _buildQuickStatusBadge(
              'Payment Status',
              lead.paymentStatus.label,
              AppTheme.paymentColor(lead.paymentStatus.label),
            ),
            const SizedBox(height: 12),

            // Next follow-up date/time
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 18, color: Colors.teal.shade700),
                  const SizedBox(width: 8),
                  const Text('Next Followup: ', style: TextStyle(fontWeight: FontWeight.w500)),
                  Expanded(
                    child: Text(
                      lead.nextFollowUpDate != null
                          ? '${DateFormat('dd/MM/yyyy').format(lead.nextFollowUpDate!)}${lead.nextFollowUpTime.isNotEmpty ? ' at ${lead.nextFollowUpTime}' : ''}'
                          : 'Not scheduled',
                      style: TextStyle(
                        color: lead.nextFollowUpDate != null ? Colors.teal.shade700 : Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Comment History section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.history, size: 18, color: Colors.amber.shade800),
                      const SizedBox(width: 8),
                      Text(
                        'Comment History:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade800,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_loadingHistory)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (_history.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No comments yet',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  else
                    ..._history.take(5).map((entry) => _buildCommentHistoryItem(entry)),
                  if (_history.length > 5)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextButton(
                        onPressed: () {
                          _tabController.animateTo(1); // Go to History tab
                        },
                        child: Text(
                          'View all ${_history.length} entries →',
                          style: TextStyle(color: Colors.teal.shade700),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatusBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentHistoryItem(LeadHistory entry) {
    final dateStr = DateFormat('dd/MM/yy').format(entry.updatedAt);
    final timeStr = DateFormat('HH:mm').format(entry.updatedAt);
    final userName = entry.updatedBy.isNotEmpty
        ? entry.updatedBy.split('@').first
        : 'System';

    // Get the comment/description text
    String commentText = '';
    if (entry.isActivityLog && entry.description != null && entry.description!.isNotEmpty) {
      commentText = entry.description!;
    } else if (entry.comment.isNotEmpty) {
      commentText = entry.comment;
    } else if (entry.changedFields.isNotEmpty) {
      // Summarize field changes
      final changes = entry.changedFields.entries.map((e) {
        final fieldName = e.key.replaceAll('_', ' ');
        return fieldName;
      }).join(', ');
      commentText = 'Updated: $changes';
    }

    if (commentText.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            commentText,
            style: const TextStyle(fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.person, size: 12, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                'by $userName',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                '$dateStr $timeStr',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showQuickUpdateDialog(Lead lead) {
    // Ensure rating is a valid dropdown value
    const validRatings = [10, 20, 30, 40, 50, 60, 70, 80, 90];
    int selectedRating = validRatings.contains(lead.rating) ? lead.rating : 10;
    LeadHealth selectedHealth = lead.health;
    LeadStage selectedStage = lead.stage;
    ActivityState selectedActivity = lead.activityState;
    PaymentStatus selectedPayment = lead.paymentStatus;
    DateTime? selectedDate = lead.nextFollowUpDate;
    TimeOfDay? selectedTime;
    final commentController = TextEditingController();
    if (lead.nextFollowUpTime.isNotEmpty) {
      final parts = lead.nextFollowUpTime.split(':');
      if (parts.length == 2) {
        try {
          selectedTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        } catch (_) {
          // ignore bad time format
        }
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) => AlertDialog(
          title: const Text('Quick Update'),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rating dropdown
                  DropdownButtonFormField<int>(
                    value: selectedRating,
                    decoration: const InputDecoration(
                      labelText: 'Rating',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: validRatings
                        .map((r) => DropdownMenuItem(value: r, child: Text('$r')))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedRating = v ?? 10),
                  ),
                  const SizedBox(height: 12),

                  // Lead Health dropdown
                  DropdownButtonFormField<LeadHealth>(
                    value: selectedHealth,
                    decoration: const InputDecoration(
                      labelText: 'Lead Health',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: LeadHealth.values
                        .map((h) => DropdownMenuItem(value: h, child: Text(h.label)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedHealth = v ?? LeadHealth.warm),
                  ),
                  const SizedBox(height: 12),

                  // Sales Stage dropdown
                  DropdownButtonFormField<LeadStage>(
                    value: selectedStage,
                    decoration: const InputDecoration(
                      labelText: 'Sales Stage',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: LeadStage.values
                        .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedStage = v ?? LeadStage.newLead),
                  ),
                  const SizedBox(height: 12),

                  // Activity State dropdown
                  DropdownButtonFormField<ActivityState>(
                    value: selectedActivity,
                    decoration: const InputDecoration(
                      labelText: 'Activity State',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: ActivityState.values
                        .map((a) => DropdownMenuItem(value: a, child: Text(a.label)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedActivity = v ?? ActivityState.idle),
                  ),
                  const SizedBox(height: 12),

                  // Payment Status dropdown
                  DropdownButtonFormField<PaymentStatus>(
                    value: selectedPayment,
                    decoration: const InputDecoration(
                      labelText: 'Payment Status',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: PaymentStatus.values
                        .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedPayment = v ?? PaymentStatus.free),
                  ),
                  const SizedBox(height: 16),

                  // Comment field (before follow-up section)
                  TextField(
                    controller: commentController,
                    decoration: const InputDecoration(
                      labelText: 'Comment',
                      hintText: 'Add a comment or note...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.comment, size: 20),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),

                  // Follow-up date/time section
                  const Text('Next Follow-up:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: ctx2,
                              initialDate: selectedDate ?? DateTime.now(),
                              firstDate: DateTime.now().subtract(const Duration(days: 30)),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) {
                              setDialogState(() => selectedDate = date);
                            }
                          },
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(
                            selectedDate != null
                                ? DateFormat('dd/MM/yyyy').format(selectedDate!)
                                : 'Select Date',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final time = await showTimePicker(
                              context: ctx2,
                              initialTime: selectedTime ?? TimeOfDay.now(),
                            );
                            if (time != null) {
                              setDialogState(() => selectedTime = time);
                            }
                          },
                          icon: const Icon(Icons.access_time, size: 16),
                          label: Text(
                            selectedTime != null
                                ? selectedTime!.format(ctx2)
                                : 'Select Time',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx2);
                try {
                  // Build update map with only changed fields
                  final Map<String, dynamic> updates = {};

                  if (selectedRating != lead.rating) {
                    updates['rating'] = selectedRating;
                  }
                  if (selectedHealth != lead.health) {
                    updates['health'] = selectedHealth.name;
                  }
                  if (selectedStage != lead.stage) {
                    updates['stage'] = selectedStage.name;
                  }
                  if (selectedActivity != lead.activityState) {
                    updates['activity_state'] = selectedActivity.name;
                  }
                  if (selectedPayment != lead.paymentStatus) {
                    updates['payment_status'] = selectedPayment.name;
                  }
                  if (selectedDate != lead.nextFollowUpDate) {
                    updates['next_follow_up_date'] = selectedDate;
                  }
                  final newTimeStr = selectedTime != null
                      ? '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}'
                      : '';
                  if (newTimeStr != lead.nextFollowUpTime) {
                    updates['next_follow_up_time'] = newTimeStr;
                  }
                  // Save comment if provided
                  final comment = commentController.text.trim();
                  if (comment.isNotEmpty) {
                    updates['comment'] = comment;
                  }

                  if (updates.isNotEmpty) {
                    await _leadService.updateLead(
                      lead.id,
                      updates,
                      updatedBy: widget.currentUser?.email ?? 'Unknown',
                      comment: comment,
                    );
                    // Update local lead object so UI refreshes
                    if (mounted) {
                      setState(() {
                        lead.rating = selectedRating;
                        lead.health = selectedHealth;
                        lead.stage = selectedStage;
                        lead.activityState = selectedActivity;
                        lead.paymentStatus = selectedPayment;
                        lead.nextFollowUpDate = selectedDate;
                        lead.nextFollowUpTime = selectedTime != null
                            ? '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}'
                            : '';
                        if (comment.isNotEmpty) lead.comment = comment;
                      });
                    }
                    await _loadHistory();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Lead updated successfully')),
                      );
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No changes made')),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  /// Look up user display name by email. Falls back to email prefix if not found.
  String _getUserNameByEmail(String email) {
    if (email.isEmpty) return '';
    final user = _allUsers.where((u) => u.email == email).firstOrNull;
    if (user != null && user.name.isNotEmpty) return user.name;
    return email.split('@').first;
  }

  void _showAddCommentDialog(Lead lead) {
    final commentCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Comment'),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: commentCtrl,
            decoration: const InputDecoration(
              labelText: 'Comment',
              hintText: 'Enter your comment or remark...',
              border: OutlineInputBorder(),
            ),
            maxLines: 4,
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (commentCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Please enter a comment')),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                await _leadService.addLeadHistory(
                  lead.id,
                  'Note',
                  commentCtrl.text.trim(),
                  widget.currentUser?.email ?? 'Unknown',
                );
                await _loadHistory();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Comment added')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySummaryCard(Lead lead, ColorScheme cs) {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.primaryContainer.withOpacity(0.3), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.analytics, color: cs.primary, size: 20),
                ),
                const SizedBox(width: 12),
                const Text('Activity Summary',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _statBox('History', '${_history.length}', Colors.indigo),
                const SizedBox(width: 8),
                _statBox('Meetings', '${_meetings.length}', Colors.purple),
                const SizedBox(width: 8),
                _statBox('Emails', '${_emailLogs.length}', Colors.blue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentCard(Lead lead, ColorScheme cs) {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple.withOpacity(0.1), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.people, color: Colors.deepPurple, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Assignment & Tagging',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Current Assignment Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person_pin, size: 16, color: Colors.deepPurple.shade700),
                      const SizedBox(width: 8),
                      const Text('Assigned To: ', style: TextStyle(fontWeight: FontWeight.w500)),
                      Expanded(
                        child: Text(
                          lead.assignedTo.isNotEmpty ? _getUserNameByEmail(lead.assignedTo) : 'Not assigned',
                          style: TextStyle(
                            color: lead.assignedTo.isNotEmpty ? Colors.deepPurple.shade700 : Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.group, size: 16, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      const Text('Followers: ', style: TextStyle(fontWeight: FontWeight.w500)),
                      Expanded(
                        child: lead.followers.isNotEmpty
                            ? Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: lead.followers.map((f) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.blue.shade200),
                                  ),
                                  child: Text(
                                    _getUserNameByEmail(f),
                                    style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                                  ),
                                )).toList(),
                              )
                            : Text(
                                'None',
                                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showAssignLeadDialog(lead),
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('Assign'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.deepPurple,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showFollowersDialog(lead),
                    icon: const Icon(Icons.group_add, size: 18),
                    label: const Text('Followers'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAssignLeadDialog(Lead lead) {
    AppUser? selectedEmployee;
    String teamName = lead.groupName;
    String groupName = lead.subGroup;

    // Pre-select current values
    if (lead.assignedTo.isNotEmpty) {
      selectedEmployee = _allUsers.where((u) => u.email == lead.assignedTo).firstOrNull;
    }

    // All assignable users (not just members — any active user)
    final assignableUsers = _allUsers.where((u) => u.isActive).toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) => AlertDialog(
          title: const Text('Assign Lead'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Employee dropdown with search
                  const Text('Assign to:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Autocomplete<AppUser>(
                    initialValue: TextEditingValue(text: selectedEmployee?.name ?? ''),
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return assignableUsers;
                      }
                      final query = textEditingValue.text.toLowerCase();
                      return assignableUsers.where((u) =>
                        u.name.toLowerCase().contains(query) ||
                        u.email.toLowerCase().contains(query)
                      );
                    },
                    displayStringForOption: (user) => '${user.name} (${user.email})',
                    fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          hintText: 'Search user by name or email...',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.person_search),
                          suffixIcon: controller.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  controller.clear();
                                  setDialogState(() {
                                    selectedEmployee = null;
                                    teamName = '';
                                    groupName = '';
                                  });
                                },
                              )
                            : null,
                        ),
                      );
                    },
                    onSelected: (user) {
                      setDialogState(() {
                        selectedEmployee = user;
                        // Auto-populate team and group NAMES from user's profile IDs
                        teamName = user.teamId != null && user.teamId!.isNotEmpty
                            ? (_teamNames[user.teamId!] ?? user.teamId!)
                            : '';
                        groupName = user.groupId != null && user.groupId!.isNotEmpty
                            ? (_groupNames[user.groupId!] ?? user.groupId!)
                            : '';
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Auto-populated Team & Group (read-only)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: TextEditingController(text: teamName),
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Team (Auto)',
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: TextEditingController(text: groupName),
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Group (Auto)',
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Team and Group are auto-filled from the assigned user\'s profile.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx2);
                try {
                  await _leadService.updateLead(
                    lead.id,
                    {
                      'assigned_to': selectedEmployee?.email ?? '',
                      'group_name': teamName,
                      'sub_group': groupName,
                      if (selectedEmployee != null) ...{
                        'team_id': selectedEmployee!.teamId ?? '',
                        'group_id': selectedEmployee!.groupId ?? '',
                        'owner_uid': selectedEmployee!.uid,
                      },
                    },
                    updatedBy: widget.currentUser?.email ?? 'Unknown',
                  );

                  // Update local state
                  if (mounted) {
                    setState(() {
                      lead.assignedTo = selectedEmployee?.email ?? '';
                      lead.groupName = teamName;
                      lead.subGroup = groupName;
                      if (selectedEmployee != null) {
                        lead.teamId = selectedEmployee!.teamId ?? '';
                        lead.groupId = selectedEmployee!.groupId ?? '';
                        lead.ownerUid = selectedEmployee!.uid;
                      }
                    });
                  }

                  // Reload history to show the change
                  await _loadHistory();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Lead assignment updated')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showFollowersDialog(Lead lead) {
    // Get team members that can be followers (TL, Manager, Coordinator, Member from same team)
    final teamId = lead.teamId.isNotEmpty ? lead.teamId : (widget.currentUser?.teamId ?? '');
    final teamUsers = _allUsers.where((u) =>
      u.isActive &&
      u.email != lead.assignedTo && // Don't show assigned user as follower option
      (u.role == UserRole.teamLead ||
       u.role == UserRole.manager ||
       u.role == UserRole.coordinator ||
       u.role == UserRole.member)
    ).toList();

    // Sort: same team first, then by name
    teamUsers.sort((a, b) {
      final aInTeam = a.teamId == teamId ? 0 : 1;
      final bInTeam = b.teamId == teamId ? 0 : 1;
      if (aInTeam != bInTeam) return aInTeam.compareTo(bInTeam);
      return a.name.compareTo(b.name);
    });

    final selectedEmails = Set<String>.from(lead.followers);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) => AlertDialog(
          title: const Text('Manage Followers'),
          content: SizedBox(
            width: 500,
            height: 400,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Followers can view this lead. Select users to add as followers.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: teamUsers.length,
                    itemBuilder: (context, index) {
                      final user = teamUsers[index];
                      final isSelected = selectedEmails.contains(user.email);
                      final isSameTeam = user.teamId == teamId;
                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (val) {
                          setDialogState(() {
                            if (val == true) {
                              selectedEmails.add(user.email);
                            } else {
                              selectedEmails.remove(user.email);
                            }
                          });
                        },
                        title: Text(
                          user.name.isNotEmpty ? user.name : user.email,
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          '${user.email} - ${user.role.label}${isSameTeam ? ' (Same Team)' : ''}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        secondary: Icon(
                          isSameTeam ? Icons.group : Icons.person_outline,
                          size: 18,
                          color: isSameTeam ? Colors.blue : Colors.grey,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx2);
                try {
                  final followers = selectedEmails.toList();

                  await _leadService.updateLead(
                    lead.id,
                    {
                      'followers': followers,
                    },
                    updatedBy: widget.currentUser?.email ?? 'Unknown',
                  );

                  // Update local state
                  if (mounted) {
                    setState(() {
                      lead.followers = followers;
                    });
                  }

                  // Reload history to show the change
                  await _loadHistory();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Followers updated successfully')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _sectionCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  /// Resolve team name: use stored name, fall back to lookup by team_id
  String _resolveTeamName(Lead lead) {
    if (lead.groupName.isNotEmpty) return lead.groupName;
    if (lead.teamId.isNotEmpty && _teamNames.containsKey(lead.teamId)) {
      return _teamNames[lead.teamId]!;
    }
    return '-';
  }

  /// Resolve group name: use stored name, fall back to lookup by group_id
  String _resolveGroupName(Lead lead) {
    if (lead.subGroup.isNotEmpty) return lead.subGroup;
    if (lead.groupId.isNotEmpty && _groupNames.containsKey(lead.groupId)) {
      return _groupNames[lead.groupId]!;
    }
    return '-';
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: TextStyle(
                    color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // History Tab - Modern Timeline Design with Email Logs
  // ---------------------------------------------------------------------------

  Widget _buildHistoryTab(ColorScheme cs) {
    if (_loadingHistory || _loadingEmails || _loadingMeetings) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_combinedTimeline.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.history, size: 48, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 16),
            Text('No Activity Yet',
                style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Updates, changes and emails will appear here',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _combinedTimeline.length,
      itemBuilder: (context, index) {
        final entry = _combinedTimeline[index];
        final isFirst = index == 0;
        final isLast = index == _combinedTimeline.length - 1;

        if (entry.type == _TimelineType.history) {
          return _buildTimelineItem(entry.historyEntry!, cs, isFirst, isLast);
        } else if (entry.type == _TimelineType.email) {
          return _buildEmailTimelineItem(entry.emailLog!, cs, isFirst, isLast);
        } else {
          return _buildMeetingTimelineItem(entry.meeting!, cs, isFirst, isLast);
        }
      },
    );
  }

  Widget _buildEmailTimelineItem(EmailLog log, ColorScheme cs, bool isFirst, bool isLast) {
    final dateStr = DateFormat('dd MMM yyyy').format(log.sentAt);
    final timeStr = DateFormat('hh:mm a').format(log.sentAt);
    final statusColor = log.status == 'sent'
        ? Colors.green
        : log.status == 'failed'
            ? Colors.red
            : Colors.orange;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline connector
          SizedBox(
            width: 60,
            child: Column(
              children: [
                // Top connector line
                if (!isFirst)
                  Container(
                    width: 2,
                    height: 20,
                    color: cs.primary.withOpacity(0.3),
                  ),
                // Circle with icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue, Colors.blue.shade300],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.email, color: Colors.white, size: 20),
                ),
                // Bottom connector line
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : cs.primary.withOpacity(0.3),
                  ),
                ),
              ],
            ),
          ),
          // Content card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with gradient
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.withOpacity(0.1), Colors.white],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Email Sent',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              log.status.toUpperCase(),
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(dateStr,
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500)),
                              Text(timeStr,
                                  style: TextStyle(
                                      color: Colors.grey.shade400, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // User info
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.blue.withOpacity(0.1),
                            child: Text(
                              _getInitials(log.sentByUserName),
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              log.sentByUserName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Email details
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Template name
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.blue.shade100),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.article, size: 14, color: Colors.blue.shade600),
                                    const SizedBox(width: 6),
                                    Text('Template: ${log.templateName}',
                                        style: TextStyle(
                                            color: Colors.blue.shade700,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.subject, size: 14, color: Colors.blue.shade600),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(log.subject,
                                          style: TextStyle(
                                              color: Colors.blue.shade700,
                                              fontSize: 12),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.send, size: 14, color: Colors.blue.shade600),
                                    const SizedBox(width: 6),
                                    Text('To: ${log.toEmail}',
                                        style: TextStyle(
                                            color: Colors.blue.shade600,
                                            fontSize: 11)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (log.errorMessage != null && log.errorMessage!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline, size: 16, color: Colors.red.shade600),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(log.errorMessage!,
                                        style: TextStyle(
                                            color: Colors.red.shade700, fontSize: 12)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingTimelineItem(Meeting meeting, ColorScheme cs, bool isFirst, bool isLast) {
    final dateStr = DateFormat('dd MMM yyyy').format(meeting.startTime);
    final timeStr = DateFormat('hh:mm a').format(meeting.startTime);
    final endTimeStr = DateFormat('hh:mm a').format(meeting.endTime);
    final statusColor = _getMeetingStatusColor(meeting.status);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 60,
            child: Column(
              children: [
                if (!isFirst)
                  Container(width: 2, height: 20, color: cs.primary.withOpacity(0.3)),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purple, Colors.purple.shade300],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.videocam, color: Colors.white, size: 20),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : cs.primary.withOpacity(0.3),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.purple.withOpacity(0.1), Colors.white],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Meeting Scheduled',
                              style: TextStyle(
                                color: Colors.purple,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              meeting.status.label.toUpperCase(),
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(dateStr,
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500)),
                              Text('$timeStr - $endTimeStr',
                                  style: TextStyle(
                                      color: Colors.grey.shade400, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meeting.title,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          if (meeting.description != null && meeting.description!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.subject, size: 14, color: Colors.purple.shade700),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Agenda: ${meeting.description!}',
                                    style: TextStyle(
                                      color: Colors.purple.shade800,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.purple.shade100),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.videocam, size: 14, color: Colors.purple.shade600),
                                    const SizedBox(width: 6),
                                    Text('Type: ${meeting.type.label}',
                                        style: TextStyle(color: Colors.purple.shade700, fontSize: 12, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                if (meeting.guests.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.people, size: 14, color: Colors.purple.shade600),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Guests: ${meeting.guests.map((g) => g.email).join(", ")}',
                                          style: TextStyle(color: Colors.purple.shade600, fontSize: 11),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(LeadHistory entry, ColorScheme cs, bool isFirst, bool isLast) {
    final dateStr = DateFormat('dd MMM yyyy').format(entry.updatedAt);
    final timeStr = DateFormat('hh:mm a').format(entry.updatedAt);
    final actionType = _getActionType(entry);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline connector
          SizedBox(
            width: 60,
            child: Column(
              children: [
                // Top connector line
                if (!isFirst)
                  Container(
                    width: 2,
                    height: 20,
                    color: cs.primary.withOpacity(0.3),
                  ),
                // Circle with icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [actionType.color, actionType.color.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: actionType.color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(actionType.icon, color: Colors.white, size: 20),
                ),
                // Bottom connector line
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : cs.primary.withOpacity(0.3),
                  ),
                ),
              ],
            ),
          ),
          // Content card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with gradient
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [actionType.color.withOpacity(0.1), Colors.white],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: actionType.color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              actionType.label,
                              style: TextStyle(
                                color: actionType.color,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(dateStr,
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500)),
                              Text(timeStr,
                                  style: TextStyle(
                                      color: Colors.grey.shade400, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // User info
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: cs.primary.withOpacity(0.1),
                            child: Text(
                              _getInitials(entry.updatedBy),
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: cs.primary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.updatedBy.isNotEmpty
                                  ? entry.updatedBy
                                  : 'System',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Comment if exists
                    if (entry.comment.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.format_quote,
                                  size: 16, color: Colors.grey.shade400),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(entry.comment,
                                    style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 13,
                                        fontStyle: FontStyle.italic)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    // Activity log description (for Quick Follow-up entries)
                    if (entry.isActivityLog && entry.description != null && entry.description!.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: actionType.color.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: actionType.color.withOpacity(0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.description, size: 14, color: actionType.color),
                                  const SizedBox(width: 6),
                                  Text('Activity Details',
                                      style: TextStyle(
                                        color: actionType.color,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      )),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                entry.description!,
                                style: TextStyle(
                                  color: Colors.grey.shade800,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    // Changed fields (for regular update entries)
                    if (!entry.isActivityLog && entry.changedFields.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: entry.changedFields.entries.map((e) {
                            return _buildChangeItem(e.key, e.value as Map<String, dynamic>);
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangeItem(String field, Map<String, dynamic> change) {
    final fieldName = _humanFieldName(field);
    final oldVal = change['old']?.toString() ?? '';
    final newVal = change['new']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fieldName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (oldVal.isNotEmpty) ...[
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.remove_circle_outline,
                            size: 14, color: Colors.red.shade400),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            oldVal,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 12,
                              decoration: TextDecoration.lineThrough,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward,
                      size: 16, color: Colors.grey.shade400),
                ),
              ],
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_circle_outline,
                          size: 14, color: Colors.green.shade600),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          newVal.isNotEmpty ? newVal : '(empty)',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  _ActionType _getActionType(LeadHistory entry) {
    // Handle activity log entries (from Quick Follow-up)
    if (entry.isActivityLog) {
      switch (entry.action?.toLowerCase()) {
        case 'call':
          return _ActionType('Phone Call', Icons.phone, Colors.teal);
        case 'email':
          return _ActionType('Email', Icons.email, Colors.blue);
        case 'meeting':
          return _ActionType('Meeting', Icons.videocam, Colors.purple);
        case 'note':
          return _ActionType('Note Added', Icons.note_add, Colors.amber.shade700);
        default:
          return _ActionType('Activity', Icons.history, Colors.indigo);
      }
    }

    final comment = entry.comment.toLowerCase();
    final fields = entry.changedFields.keys.toList();

    // Check for meeting-related activity
    if (comment.contains('meeting') || fields.any((f) => f.contains('meeting'))) {
      return _ActionType('Meeting', Icons.videocam, Colors.purple);
    }
    // Check for stage changes
    if (fields.contains('stage')) {
      return _ActionType('Stage Change', Icons.trending_up, Colors.blue);
    }
    // Check for status changes
    if (fields.contains('health') || fields.contains('activity_state')) {
      return _ActionType('Status Update', Icons.flag, Colors.orange);
    }
    // Check for payment
    if (fields.contains('payment_status') || fields.any((f) => f.contains('payment'))) {
      return _ActionType('Payment', Icons.payment, Colors.green);
    }
    // Check for contact info changes
    if (fields.any((f) => f.contains('email') || f.contains('mobile') || f.contains('phone'))) {
      return _ActionType('Contact Update', Icons.contact_phone, Colors.teal);
    }
    // Check for notes/comments
    if (fields.contains('notes') || fields.contains('comment')) {
      return _ActionType('Note Added', Icons.note_add, Colors.amber.shade700);
    }
    // Default
    return _ActionType('Updated', Icons.edit, Colors.indigo);
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.split(RegExp(r'[@\s]+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  String _humanFieldName(String field) {
    return field
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) =>
            w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  // ---------------------------------------------------------------------------
  // Meetings Tab
  // ---------------------------------------------------------------------------

  Widget _buildMeetingsTab(ColorScheme cs) {
    return Column(
      children: [
        // Schedule meeting button
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _openScheduleMeetingDialog,
              icon: const Icon(Icons.videocam),
              label: const Text('Schedule Meeting'),
            ),
          ),
        ),
        const Divider(),
        // Meetings list
        Expanded(
          child: _loadingMeetings
              ? const Center(child: CircularProgressIndicator())
              : _meetings.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.event_available,
                              size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text('No meetings scheduled yet',
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 16)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _meetings.length,
                      itemBuilder: (context, index) {
                        final meeting = _meetings[index];
                        return _meetingCard(meeting, cs);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _meetingCard(Meeting meeting, ColorScheme cs) {
    final dateStr = DateFormat('dd MMM yyyy').format(meeting.startTime);
    final statusColor = _getMeetingStatusColor(meeting.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.videocam, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    meeting.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    meeting.status.label.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (meeting.description != null && meeting.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.subject, size: 15, color: Colors.purple.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Agenda: ${meeting.description!}',
                      style: TextStyle(
                        color: Colors.purple.shade800,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  dateStr,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  meeting.timeRange,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    meeting.type.label,
                    style: const TextStyle(
                      color: Colors.purple,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (meeting.guests.isNotEmpty)
                  Text(
                    '${meeting.guests.length} guest(s)',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
              ],
            ),
            if (meeting.meetLink != null && meeting.meetLink!.isNotEmpty && meeting.meetLink != 'pending') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _launchUrl(meeting.meetLink!),
                  icon: const Icon(Icons.video_call, size: 18),
                  label: const Text('Join Google Meet'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getMeetingStatusColor(MeetingStatus status) {
    switch (status) {
      case MeetingStatus.scheduled:
        return Colors.blue;
      case MeetingStatus.confirmed:
        return Colors.green;
      case MeetingStatus.inProgress:
        return Colors.orange;
      case MeetingStatus.completed:
        return Colors.teal;
      case MeetingStatus.cancelled:
        return Colors.red;
      case MeetingStatus.rescheduled:
        return Colors.purple;
      case MeetingStatus.noShow:
        return Colors.grey;
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ---------------------------------------------------------------------------
  // Emails Tab
  // ---------------------------------------------------------------------------

  Widget _buildEmailsTab(ColorScheme cs) {
    return Column(
      children: [
        // Send email button
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _openSendEmailDialog,
              icon: const Icon(Icons.send),
              label: const Text('Send Email to Lead'),
            ),
          ),
        ),
        const Divider(),
        // Email logs
        Expanded(
          child: _loadingEmails
              ? const Center(child: CircularProgressIndicator())
              : _emailLogs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.mail_outline,
                              size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text('No emails sent yet',
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 16)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _emailLogs.length,
                      itemBuilder: (context, index) {
                        final log = _emailLogs[index];
                        return _emailLogCard(log, cs);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _emailLogCard(EmailLog log, ColorScheme cs) {
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(log.sentAt);
    final statusColor = log.status == 'sent'
        ? Colors.green
        : log.status == 'failed'
            ? Colors.red
            : Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.email, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    log.templateName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    log.status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              log.subject,
              style: const TextStyle(fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person_outline,
                    size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  log.sentByUserName,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const Spacer(),
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  dateStr,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
            if (log.errorMessage != null && log.errorMessage!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  log.errorMessage!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Helper class for history action types
class _ActionType {
  final String label;
  final IconData icon;
  final Color color;

  const _ActionType(this.label, this.icon, this.color);
}

// Timeline entry type enum
enum _TimelineType { history, email, meeting }

// Combined timeline entry
class _TimelineEntry {
  final _TimelineType type;
  final DateTime timestamp;
  final LeadHistory? historyEntry;
  final EmailLog? emailLog;
  final Meeting? meeting;

  _TimelineEntry({
    required this.type,
    required this.timestamp,
    this.historyEntry,
    this.emailLog,
    this.meeting,
  });
}
