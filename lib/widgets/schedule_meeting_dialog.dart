import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/meeting.dart';
import '../models/lead.dart';
import '../models/user.dart';
import '../services/calendar_service.dart';
import '../services/lead_service.dart';

class ScheduleMeetingDialog extends StatefulWidget {
  final Lead? lead;
  final AppUser currentUser;
  final VoidCallback? onMeetingCreated;
  final DateTime? preselectedDate;

  const ScheduleMeetingDialog({
    super.key,
    this.lead,
    required this.currentUser,
    this.onMeetingCreated,
    this.preselectedDate,
  });

  @override
  State<ScheduleMeetingDialog> createState() => _ScheduleMeetingDialogState();
}

class _ScheduleMeetingDialogState extends State<ScheduleMeetingDialog> {
  final _formKey = GlobalKey<FormState>();
  final CalendarService _calendarService = CalendarService();
  final LeadService _leadService = LeadService();

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
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
    _guestEmailController = TextEditingController();

    // Use preselected date if provided, otherwise use tomorrow
    _selectedDate = widget.preselectedDate ?? DateTime.now().add(const Duration(days: 1));

    // If a lead was passed in, pre-select it
    if (widget.lead != null) {
      _selectedLead = widget.lead;
      _onLeadSelected(widget.lead);
    }

    _loadLeads();
  }

  Future<void> _loadLeads() async {
    try {
      final leads = await _leadService.getAllLeads();
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
        createdBy: widget.currentUser.email,
        createdAt: DateTime.now(),
        organizerUid: widget.currentUser.uid,
        assignedTo: widget.currentUser.uid,
      );

      await _calendarService.createMeeting(meeting);

      // Add history entry for the lead if a lead is associated
      if (leadToUse != null && leadToUse.id.isNotEmpty) {
        await _addMeetingHistoryToLead(leadToUse.id, meeting);
      }

      if (mounted) {
        Navigator.of(context).pop();
        widget.onMeetingCreated?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Meeting scheduled successfully'),
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

  Future<void> _addMeetingHistoryToLead(String leadId, Meeting meeting) async {
    try {
      final dateStr = '${meeting.startTime.day}/${meeting.startTime.month}/${meeting.startTime.year}';
      final timeStr = '${meeting.startTime.hour.toString().padLeft(2, '0')}:${meeting.startTime.minute.toString().padLeft(2, '0')}';

      await FirebaseFirestore.instance
          .collection('leads')
          .doc(leadId)
          .collection('history')
          .add({
        'lead_id': leadId,
        'updated_by': widget.currentUser.email,
        'updated_at': FieldValue.serverTimestamp(),
        'comment': 'Meeting scheduled: ${meeting.title}',
        'changed_fields': {
          'meeting_scheduled': {
            'old': '',
            'new': '${meeting.type.label} on $dateStr at $timeStr',
          },
        },
      });
    } catch (e) {
      debugPrint('Error adding meeting history: $e');
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
                    Icon(Icons.event, color: theme.colorScheme.onPrimaryContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Schedule Meeting',
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

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Description (optional)',
                          prefixIcon: Icon(Icons.notes),
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
                      label: const Text('Schedule'),
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
