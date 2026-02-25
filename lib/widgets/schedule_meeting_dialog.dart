import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/meeting.dart';
import '../models/lead.dart';
import '../models/user.dart';
import '../services/calendar_service.dart';
import '../services/lead_service.dart';
import '../services/google_calendar_service.dart';

class ScheduleMeetingDialog extends StatefulWidget {
  final Lead? lead;
  final AppUser currentUser;
  final VoidCallback? onMeetingCreated;
  final DateTime? preselectedDate;
  final Meeting? existingMeeting; // For edit mode

  const ScheduleMeetingDialog({
    super.key,
    this.lead,
    required this.currentUser,
    this.onMeetingCreated,
    this.preselectedDate,
    this.existingMeeting,
  });

  bool get isEditMode => existingMeeting != null;

  @override
  State<ScheduleMeetingDialog> createState() => _ScheduleMeetingDialogState();
}

class _ScheduleMeetingDialogState extends State<ScheduleMeetingDialog> {
  final _formKey = GlobalKey<FormState>();
  final CalendarService _calendarService = CalendarService();
  final LeadService _leadService = LeadService();
  final GoogleCalendarService _googleCalendarService = GoogleCalendarService();

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _meetingLinkController;
  late TextEditingController _guestEmailController;

  MeetingType _selectedType = MeetingType.googleMeet;
  late DateTime _selectedDate;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 0);
  int _duration = 30;
  final List<MeetingGuest> _guests = [];

  bool _isSaving = false;
  bool _isLoadingLeads = true;
  List<Lead> _leads = [];
  Lead? _selectedLead;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _meetingLinkController = TextEditingController();
    _guestEmailController = TextEditingController();

    if (widget.isEditMode) {
      // Edit mode: pre-fill from existing meeting
      final m = widget.existingMeeting!;
      _titleController.text = m.title;
      _descriptionController.text = m.description ?? '';
      _meetingLinkController.text = m.meetLink ?? '';
      _selectedType = m.type;
      _selectedDate = DateTime(m.startTime.year, m.startTime.month, m.startTime.day);
      _selectedTime = TimeOfDay(hour: m.startTime.hour, minute: m.startTime.minute);
      _duration = m.endTime.difference(m.startTime).inMinutes;
      if (_duration <= 0) _duration = 30;
      // Clamp to valid values
      if (![15, 30, 45, 60, 90, 120].contains(_duration)) {
        _duration = _duration <= 15 ? 15 : _duration <= 30 ? 30 : _duration <= 45 ? 45 : _duration <= 60 ? 60 : _duration <= 90 ? 90 : 120;
      }
      _guests.addAll(m.guests);
    } else {
      // Use preselected date if provided, otherwise use tomorrow
      _selectedDate = widget.preselectedDate ?? DateTime.now().add(const Duration(days: 1));
    }

    // If a lead was passed in, pre-select it
    if (widget.lead != null) {
      _selectedLead = widget.lead;
      if (!widget.isEditMode) {
        _onLeadSelected(widget.lead);
      }
    }

    _loadLeads();
  }

  Future<void> _loadLeads() async {
    try {
      List<Lead> leads;
      final user = widget.currentUser;

      // Load leads based on user role
      switch (user.role) {
        case UserRole.superAdmin:
          leads = await _leadService.getAllLeads();
          break;
        case UserRole.admin:
          if (user.teamId != null && user.teamId!.isNotEmpty) {
            final teamLeads = await _leadService.getLeadsByTeam(user.teamId!);
            final userLeads = await _leadService.getLeadsForUser(user.email, ownerUid: user.uid);
            final seen = <String>{};
            leads = [];
            for (final l in [...teamLeads, ...userLeads]) {
              if (seen.add(l.id)) leads.add(l);
            }
          } else {
            leads = await _leadService.getAllLeads();
          }
          break;
        case UserRole.manager:
        case UserRole.teamLead:
          if (user.teamId != null && user.teamId!.isNotEmpty) {
            final teamLeads = await _leadService.getLeadsByTeam(user.teamId!);
            final userLeads = await _leadService.getLeadsForUser(user.email, ownerUid: user.uid);
            final seen = <String>{};
            leads = [];
            for (final l in [...teamLeads, ...userLeads]) {
              if (seen.add(l.id)) leads.add(l);
            }
          } else {
            leads = await _leadService.getLeadsForUser(user.email, ownerUid: user.uid);
          }
          break;
        case UserRole.coordinator:
          if (user.groupId != null && user.groupId!.isNotEmpty) {
            final groupLeads = await _leadService.getLeadsByGroup(user.groupId!);
            final userLeads = await _leadService.getLeadsForUser(user.email, ownerUid: user.uid);
            final seen = <String>{};
            leads = [];
            for (final l in [...groupLeads, ...userLeads]) {
              if (seen.add(l.id)) leads.add(l);
            }
          } else {
            leads = await _leadService.getLeadsForUser(user.email, ownerUid: user.uid);
          }
          break;
        case UserRole.member:
          leads = await _leadService.getLeadsForUser(user.email, ownerUid: user.uid);
          break;
      }

      if (mounted) {
        setState(() {
          _leads = leads;
          _isLoadingLeads = false;
          // If we have a pre-selected lead, find it in the loaded list
          if (_selectedLead != null) {
            _selectedLead = leads.firstWhere(
              (l) => l.id == _selectedLead!.id,
              orElse: () => _selectedLead!,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingLeads = false);
      }
    }
  }

  void _onLeadSelected(Lead? lead) {
    setState(() {
      _selectedLead = lead;
      _guests.clear();

      if (lead != null) {
        // Auto-fill title
        _titleController.text = 'Meeting with ${lead.clientName}';

        // Auto-add lead's email as guest
        if (lead.clientEmail.isNotEmpty) {
          _guests.add(MeetingGuest(
            email: lead.clientEmail,
            name: lead.clientName,
          ));
        }
      } else {
        _titleController.clear();
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _meetingLinkController.dispose();
    _guestEmailController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  void _addGuest() {
    final email = _guestEmailController.text.trim();
    if (email.isNotEmpty && email.contains('@')) {
      setState(() {
        _guests.add(MeetingGuest(email: email));
        _guestEmailController.clear();
      });
    }
  }

  void _removeGuest(int index) {
    setState(() => _guests.removeAt(index));
  }

  Future<void> _saveMeeting() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final startDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );
      final endDateTime = startDateTime.add(Duration(minutes: _duration));

      // Use the widget.lead if available (passed from lead detail), otherwise use dropdown selection
      final leadToUse = widget.lead ?? _selectedLead;
      debugPrint('ScheduleMeetingDialog: widget.lead=${widget.lead?.id}, _selectedLead=${_selectedLead?.id}, leadToUse=${leadToUse?.id}');

      // Auto-generate Google Meet link if no manual link provided
      String meetLink = _meetingLinkController.text.trim();
      String? googleEventId;

      if (meetLink.isEmpty && !widget.isEditMode) {
        // Try to create Google Calendar event with Meet link
        try {
          final gcConfig = await _googleCalendarService.getConfig();
          if (gcConfig != null && gcConfig.isConfigured) {
            final tempMeeting = Meeting(
              id: '',
              title: _titleController.text.trim(),
              description: _descriptionController.text.trim(),
              startTime: startDateTime,
              endTime: endDateTime,
              type: _selectedType,
              status: MeetingStatus.scheduled,
              guests: _guests,
              createdBy: widget.currentUser.email,
              createdAt: DateTime.now(),
            );

            final result = await _googleCalendarService.createCalendarEvent(
              meeting: tempMeeting,
              config: gcConfig,
            );

            if (result != null) {
              meetLink = result['meetLink'] ?? '';
              googleEventId = result['eventId'];
              debugPrint('Google Meet link auto-created: $meetLink');
            }
          }
        } catch (e) {
          debugPrint('Google Calendar auto-create failed: $e');
          // Continue without Meet link - not a fatal error
        }
      }

      // Update the link controller so downstream code (history, lead update) uses it
      if (meetLink.isNotEmpty && _meetingLinkController.text.trim().isEmpty) {
        _meetingLinkController.text = meetLink;
      }

      if (widget.isEditMode) {
        // Update existing meeting
        await _calendarService.updateMeeting(widget.existingMeeting!.id, {
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'start_time': Timestamp.fromDate(startDateTime),
          'end_time': Timestamp.fromDate(endDateTime),
          'type': _selectedType.toSnakeCase(),
          'lead_id': leadToUse?.id,
          'lead_name': leadToUse?.clientName,
          'guests': _guests.map((g) => g.toMap()).toList(),
          'meet_link': meetLink,
        });
      } else {
        // Create new meeting
        // If meeting is for a lead assigned to someone else, use lead's assignedTo
        // so the assigned employee can also see this meeting on their calendar
        String meetingAssignedTo = widget.currentUser.uid;
        if (leadToUse != null && leadToUse.assignedTo.isNotEmpty) {
          meetingAssignedTo = leadToUse.assignedTo;
        }

        final meeting = Meeting(
          id: '',
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          startTime: startDateTime,
          endTime: endDateTime,
          type: _selectedType,
          status: MeetingStatus.scheduled,
          leadId: leadToUse?.id,
          leadName: leadToUse?.clientName,
          guests: _guests,
          meetLink: meetLink.isNotEmpty ? meetLink : null,
          googleEventId: googleEventId,
          createdBy: widget.currentUser.email,
          createdAt: DateTime.now(),
          organizerUid: widget.currentUser.uid,
          assignedTo: meetingAssignedTo,
          teamId: widget.currentUser.teamId ?? leadToUse?.teamId,
          groupId: widget.currentUser.groupId ?? leadToUse?.groupId,
        );

        await _calendarService.createMeeting(meeting);
      }

      // Add history entry for the lead if a lead is associated
      // AND update the lead's meeting fields for dashboard sync
      if (leadToUse != null && leadToUse.id.isNotEmpty) {
        final historyMeetLink = _meetingLinkController.text.trim();
        final meetingForHistory = Meeting(
          id: widget.isEditMode ? widget.existingMeeting!.id : '',
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          startTime: startDateTime,
          endTime: endDateTime,
          type: _selectedType,
          status: widget.isEditMode ? widget.existingMeeting!.status : MeetingStatus.scheduled,
          leadId: leadToUse.id,
          leadName: leadToUse.clientName,
          guests: _guests,
          meetLink: historyMeetLink.isNotEmpty ? historyMeetLink : null,
          createdBy: widget.currentUser.email,
          createdAt: DateTime.now(),
          organizerUid: widget.currentUser.uid,
        );
        await _addMeetingHistoryToLead(leadToUse.id, meetingForHistory, isEdit: widget.isEditMode);
        await _updateLeadMeetingInfo(leadToUse.id, meetingForHistory);
      }

      // Send meeting notification emails to host and guests
      await _sendMeetingNotificationEmails(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        startTime: startDateTime,
        endTime: endDateTime,
        type: _selectedType,
        guests: _guests,
        leadName: leadToUse?.clientName,
        isEdit: widget.isEditMode,
      );

      if (mounted) {
        Navigator.of(context).pop();
        widget.onMeetingCreated?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEditMode ? 'Meeting updated successfully' : 'Meeting scheduled successfully'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scheduling meeting: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _addMeetingHistoryToLead(String leadId, Meeting meeting, {bool isEdit = false}) async {
    try {
      final dateStr = '${meeting.startTime.day}/${meeting.startTime.month}/${meeting.startTime.year}';
      final timeStr = '${meeting.startTime.hour.toString().padLeft(2, '0')}:${meeting.startTime.minute.toString().padLeft(2, '0')}';
      final action = isEdit ? 'updated' : 'scheduled';

      await FirebaseFirestore.instance
          .collection('leads')
          .doc(leadId)
          .collection('history')
          .add({
        'lead_id': leadId,
        'updated_by': widget.currentUser.email,
        'updated_at': FieldValue.serverTimestamp(),
        'comment': 'Meeting $action: ${meeting.title}',
        'changed_fields': {
          'meeting_$action': {
            'old': '',
            'new': '${meeting.type.label} on $dateStr at $timeStr',
          },
        },
      });
    } catch (e) {
      debugPrint('Error adding meeting history: $e');
    }
  }

  /// Update lead's meeting date/time for dashboard activity sync
  Future<void> _updateLeadMeetingInfo(String leadId, Meeting meeting) async {
    try {
      final timeStr = '${meeting.startTime.hour.toString().padLeft(2, '0')}:${meeting.startTime.minute.toString().padLeft(2, '0')}';

      await FirebaseFirestore.instance
          .collection('leads')
          .doc(leadId)
          .update({
        'meeting_date': Timestamp.fromDate(meeting.startTime),
        'meeting_time': timeStr,
        'meeting_link': meeting.meetLink ?? '',
        'meeting_agenda': meeting.description ?? '',
        'updated_at': FieldValue.serverTimestamp(),
        'last_updated_by': widget.currentUser.email,
      });
      debugPrint('Updated lead $leadId with meeting info');
    } catch (e) {
      debugPrint('Error updating lead meeting info: $e');
    }
  }

  /// Send meeting notification emails to host and all guests
  Future<void> _sendMeetingNotificationEmails({
    required String title,
    required String description,
    required DateTime startTime,
    required DateTime endTime,
    required MeetingType type,
    required List<MeetingGuest> guests,
    String? leadName,
    bool isEdit = false,
  }) async {
    try {
      final dateStr = '${startTime.day}/${startTime.month}/${startTime.year}';
      final startTimeStr = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
      final endTimeStr = '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
      final action = isEdit ? 'Updated' : 'New';
      final subject = '$action Meeting: $title - $dateStr at $startTimeStr';

      final body = '''
$action Meeting Invitation

Title: $title
${description.isNotEmpty ? 'Agenda: $description\n' : ''}Date: $dateStr
Time: $startTimeStr - $endTimeStr
Type: ${type.label}
${leadName != null ? 'Client: $leadName\n' : ''}Organized by: ${widget.currentUser.name} (${widget.currentUser.email})

Guests: ${guests.map((g) => g.name ?? g.email).join(', ')}

---
This is an automated notification from Lead Management System.
''';

      // Queue email notification for the host (organizer)
      await FirebaseFirestore.instance.collection('email_queue').add({
        'to_email': widget.currentUser.email,
        'to_name': widget.currentUser.name,
        'subject': subject,
        'body': body,
        'type': 'meeting_notification',
        'created_at': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      // Log the host notification email
      await FirebaseFirestore.instance.collection('email_logs').add({
        'to_email': widget.currentUser.email,
        'subject': subject,
        'template_name': 'Meeting Notification',
        'sent_by_user_id': widget.currentUser.uid,
        'sent_by_user_name': widget.currentUser.name,
        'sent_at': FieldValue.serverTimestamp(),
        'status': 'logged',
      });

      // Queue email notification for each guest
      for (final guest in guests) {
        await FirebaseFirestore.instance.collection('email_queue').add({
          'to_email': guest.email,
          'to_name': guest.name ?? guest.email,
          'subject': subject,
          'body': body,
          'type': 'meeting_notification',
          'created_at': FieldValue.serverTimestamp(),
          'status': 'pending',
        });

        await FirebaseFirestore.instance.collection('email_logs').add({
          'to_email': guest.email,
          'subject': subject,
          'template_name': 'Meeting Notification',
          'sent_by_user_id': widget.currentUser.uid,
          'sent_by_user_name': widget.currentUser.name,
          'sent_at': FieldValue.serverTimestamp(),
          'status': 'logged',
        });
      }

      debugPrint('Meeting notification emails queued for host + ${guests.length} guests');
    } catch (e) {
      debugPrint('Error sending meeting notification emails: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 650),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    Icon(widget.isEditMode ? Icons.edit : Icons.event, color: theme.colorScheme.onPrimaryContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.isEditMode ? 'Edit Meeting' : 'Schedule Meeting',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ],
                ),
              ),

              // Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Lead Dropdown
                      _isLoadingLeads
                          ? const LinearProgressIndicator()
                          : DropdownButtonFormField<Lead>(
                              value: _selectedLead,
                              decoration: const InputDecoration(
                                labelText: 'Select Lead/Customer',
                                prefixIcon: Icon(Icons.person),
                                hintText: 'Choose a lead...',
                              ),
                              isExpanded: true,
                              items: [
                                const DropdownMenuItem<Lead>(
                                  value: null,
                                  child: Text('-- No Lead Selected --'),
                                ),
                                ..._leads.map((lead) => DropdownMenuItem(
                                      value: lead,
                                      child: Text(
                                        '${lead.clientName}${lead.clientBusinessName.isNotEmpty ? ' (${lead.clientBusinessName})' : ''}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )),
                              ],
                              onChanged: _onLeadSelected,
                            ),
                      const SizedBox(height: 16),

                      // Title
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Meeting Title',
                          prefixIcon: Icon(Icons.title),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Title is required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Meeting Type
                      DropdownButtonFormField<MeetingType>(
                        value: _selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Meeting Type',
                          prefixIcon: Icon(Icons.videocam),
                        ),
                        items: MeetingType.values
                            .map((t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(t.label),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedType = v);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Date and Time
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _selectDate,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Date',
                                  prefixIcon: Icon(Icons.calendar_today),
                                ),
                                child: Text(
                                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: _selectTime,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Time',
                                  prefixIcon: Icon(Icons.access_time),
                                ),
                                child: Text(_selectedTime.format(context)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Duration
                      DropdownButtonFormField<int>(
                        value: _duration,
                        decoration: const InputDecoration(
                          labelText: 'Duration',
                          prefixIcon: Icon(Icons.timelapse),
                        ),
                        items: const [
                          DropdownMenuItem(value: 15, child: Text('15 minutes')),
                          DropdownMenuItem(value: 30, child: Text('30 minutes')),
                          DropdownMenuItem(value: 45, child: Text('45 minutes')),
                          DropdownMenuItem(value: 60, child: Text('1 hour')),
                          DropdownMenuItem(value: 90, child: Text('1.5 hours')),
                          DropdownMenuItem(value: 120, child: Text('2 hours')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _duration = v);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Description / Agenda
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Agenda / Description',
                          prefixIcon: Icon(Icons.notes),
                          hintText: 'Enter meeting agenda...',
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Meeting Link
                      TextFormField(
                        controller: _meetingLinkController,
                        decoration: const InputDecoration(
                          labelText: 'Meeting Link',
                          prefixIcon: Icon(Icons.link),
                          hintText: 'Paste Google Meet / Zoom link...',
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Guests
                      Text('Guests', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _guestEmailController,
                              decoration: const InputDecoration(
                                hintText: 'Add guest email',
                                prefixIcon: Icon(Icons.email),
                                isDense: true,
                              ),
                              onFieldSubmitted: (_) => _addGuest(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            icon: const Icon(Icons.add),
                            onPressed: _addGuest,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: _guests.asMap().entries.map((entry) {
                          return Chip(
                            label: Text(entry.value.email),
                            onDeleted: () => _removeGuest(entry.key),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: theme.dividerColor),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _saveMeeting,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Text(widget.isEditMode ? 'Update' : 'Schedule'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
