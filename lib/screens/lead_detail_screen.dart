import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/lead.dart';
import '../models/lead_history.dart';
import '../services/lead_service.dart';
import '../theme/app_theme.dart';

class LeadDetailScreen extends StatefulWidget {
  final Lead lead;
  final VoidCallback? onEditPressed;

  const LeadDetailScreen({
    super.key,
    required this.lead,
    this.onEditPressed,
  });

  @override
  State<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends State<LeadDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final LeadService _leadService = LeadService();
  List<LeadHistory> _history = [];
  bool _loadingHistory = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadHistory();
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
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingHistory = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lead = widget.lead;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(lead.clientName),
        actions: [
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
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDetailsTab(lead, cs),
          _buildHistoryTab(cs),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Details Tab
  // ---------------------------------------------------------------------------

  Widget _buildDetailsTab(Lead lead, ColorScheme cs) {
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
        _sectionCard('Meeting', [
          _infoRow('Agenda', lead.meetingAgenda.label),
          _infoRow(
              'Date',
              lead.meetingDate != null
                  ? '${lead.meetingDate!.day}/${lead.meetingDate!.month}/${lead.meetingDate!.year}'
                  : '-'),
          _infoRow('Time', lead.meetingTime.isNotEmpty ? lead.meetingTime : '-'),
          _infoRow(
              'Link', lead.meetingLink.isNotEmpty ? lead.meetingLink : '-'),
        ]),
        const SizedBox(height: 12),

        // Follow-up
        _sectionCard('Follow-up', [
          _infoRow(
              'Last Call Date',
              lead.lastCallDate != null
                  ? '${lead.lastCallDate!.day}/${lead.lastCallDate!.month}/${lead.lastCallDate!.year}'
                  : '-'),
          _infoRow(
              'Next Follow-up',
              lead.nextFollowUpDate != null
                  ? '${lead.nextFollowUpDate!.day}/${lead.nextFollowUpDate!.month}/${lead.nextFollowUpDate!.year}'
                  : '-'),
          _infoRow('Follow-up Time',
              lead.nextFollowUpTime.isNotEmpty ? lead.nextFollowUpTime : '-'),
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

        // WhatsApp button
        if (lead.clientWhatsApp.isNotEmpty)
          FilledButton.icon(
            onPressed: () {
              final url = Uri.parse('https://wa.me/${lead.clientWhatsApp}');
              launchUrl(url, mode: LaunchMode.externalApplication);
            },
            icon: const Icon(Icons.chat),
            label: const Text('Open WhatsApp'),
          ),
      ],
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
  // History Tab
  // ---------------------------------------------------------------------------

  Widget _buildHistoryTab(ColorScheme cs) {
    if (_loadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('No update history yet',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final entry = _history[index];
        return _historyCard(entry, cs);
      },
    );
  }

  Widget _historyCard(LeadHistory entry, ColorScheme cs) {
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(entry.updatedAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: who & when
            Row(
              children: [
                Icon(Icons.update, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.updatedBy.isNotEmpty
                        ? entry.updatedBy
                        : 'Unknown user',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(dateStr,
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
            if (entry.comment.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(entry.comment,
                  style: TextStyle(
                      color: Colors.grey.shade700,
                      fontStyle: FontStyle.italic)),
            ],
            const Divider(height: 20),

            // Changed fields
            ...entry.changedFields.entries.map((e) {
              final fieldName = _humanFieldName(e.key);
              final change = e.value as Map<String, dynamic>;
              final oldVal = change['old']?.toString() ?? '';
              final newVal = change['new']?.toString() ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(fieldName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w500, fontSize: 13)),
                    ),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: DefaultTextStyle.of(context).style,
                          children: [
                            if (oldVal.isNotEmpty)
                              TextSpan(
                                text: oldVal,
                                style: const TextStyle(
                                  color: Colors.red,
                                  decoration: TextDecoration.lineThrough,
                                  fontSize: 13,
                                ),
                              ),
                            if (oldVal.isNotEmpty && newVal.isNotEmpty)
                              const TextSpan(text: '  →  '),
                            TextSpan(
                              text: newVal.isNotEmpty ? newVal : '(empty)',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _humanFieldName(String field) {
    return field
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) =>
            w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }
}
