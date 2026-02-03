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
  List<LeadHistory> _history = [];
  List<EmailLog> _emailLogs = [];
  List<Meeting> _meetings = [];
  List<_TimelineEntry> _combinedTimeline = []; // Combined history + email logs
  bool _loadingHistory = true;
  bool _loadingEmails = true;
  bool _loadingMeetings = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadHistory();
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column - Main Info
          Expanded(
            flex: 3,
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
                _sectionCard('Submitter Info', [
                  _infoRow('Name',
                      lead.submitterName.isNotEmpty ? lead.submitterName : '-'),
                  _infoRow('Email',
                      lead.submitterEmail.isNotEmpty ? lead.submitterEmail : '-'),
                  _infoRow('Mobile',
                      lead.submitterMobile.isNotEmpty ? lead.submitterMobile : '-'),
                  _infoRow(
                      'Group', lead.groupName.isNotEmpty ? lead.groupName : '-'),
                  _infoRow(
                      'Sub Group', lead.subGroup.isNotEmpty ? lead.subGroup : '-'),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Right Column - Quick Actions & Stats
          Expanded(
            flex: 2,
            child: Column(
              children: [
                // Quick Actions Card
                _buildQuickActionsCard(lead, cs),
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
    );
  }

  Widget _buildNarrowDetailsLayout(Lead lead, ColorScheme cs) {
    return ListView(
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
        _buildQuickActionsCard(lead, cs),
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

        // Notes & Comment
        _sectionCard('Notes & Comments', [
          _infoRow('Notes', lead.notes.isNotEmpty ? lead.notes : '-'),
          _infoRow('Comment', lead.comment.isNotEmpty ? lead.comment : '-'),
        ]),
        const SizedBox(height: 12),

        // Submitter Info
        _sectionCard('Submitter Info', [
          _infoRow('Name',
              lead.submitterName.isNotEmpty ? lead.submitterName : '-'),
          _infoRow('Email',
              lead.submitterEmail.isNotEmpty ? lead.submitterEmail : '-'),
          _infoRow('Mobile',
              lead.submitterMobile.isNotEmpty ? lead.submitterMobile : '-'),
          _infoRow(
              'Group', lead.groupName.isNotEmpty ? lead.groupName : '-'),
          _infoRow(
              'Sub Group', lead.subGroup.isNotEmpty ? lead.subGroup : '-'),
        ]),
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
                    // Changed fields
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
