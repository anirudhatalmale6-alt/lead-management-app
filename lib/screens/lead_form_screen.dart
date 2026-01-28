import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/lead.dart';
import '../models/user.dart';

class LeadFormScreen extends StatefulWidget {
  final Lead? existingLead;
  final void Function(Lead lead) onSave;
  final AppUser? currentUser;

  const LeadFormScreen({
    super.key,
    this.existingLead,
    required this.onSave,
    this.currentUser,
  });

  @override
  State<LeadFormScreen> createState() => _LeadFormScreenState();
}

class _LeadFormScreenState extends State<LeadFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Section 1: Client Information
  late final TextEditingController _clientBusinessNameController;
  late final TextEditingController _clientNameController;
  late final TextEditingController _clientWhatsAppController;
  late final TextEditingController _clientMobileController;
  late final TextEditingController _clientEmailController;
  late final TextEditingController _countryController;
  late final TextEditingController _stateController;
  late final TextEditingController _clientCityController;

  // Section 2: Lead Status
  late ProductService _interestedInProduct;
  late int _rating;
  late LeadHealth _health;
  late LeadStage _stage;
  late ActivityState _activityState;
  late PaymentStatus _paymentStatus;

  // Section 3: Meeting
  late MeetingAgenda _meetingAgenda;
  DateTime? _meetingDate;
  late final TextEditingController _meetingDateController;
  late final TextEditingController _meetingTimeController;
  late final TextEditingController _meetingLinkController;

  // Section 4: Follow-up
  DateTime? _lastCallDate;
  late final TextEditingController _lastCallDateController;
  DateTime? _nextFollowUpDate;
  late final TextEditingController _nextFollowUpDateController;
  late final TextEditingController _nextFollowUpTimeController;
  late final TextEditingController _commentController;

  // Section 5: Notes
  late final TextEditingController _notesController;

  // Section 6: Submitter Info
  late final TextEditingController _submitterNameController;
  late final TextEditingController _submitterEmailController;
  late final TextEditingController _submitterMobileController;
  late final TextEditingController _groupNameController;
  late final TextEditingController _subGroupController;

  bool get _isEditing => widget.existingLead != null;

  @override
  void initState() {
    super.initState();
    final lead = widget.existingLead;

    // Section 1: Client Information
    _clientBusinessNameController =
        TextEditingController(text: lead?.clientBusinessName ?? '');
    _clientNameController =
        TextEditingController(text: lead?.clientName ?? '');
    _clientWhatsAppController =
        TextEditingController(text: lead?.clientWhatsApp ?? '');
    _clientMobileController =
        TextEditingController(text: lead?.clientMobile ?? '');
    _clientEmailController =
        TextEditingController(text: lead?.clientEmail ?? '');
    _countryController =
        TextEditingController(text: lead?.country ?? '');
    _stateController =
        TextEditingController(text: lead?.state ?? '');
    _clientCityController =
        TextEditingController(text: lead?.clientCity ?? '');

    // Section 2: Lead Status
    _interestedInProduct =
        lead?.interestedInProduct ?? ProductService.others;
    _rating = lead?.rating ?? 10;
    _health = lead?.health ?? LeadHealth.warm;
    _stage = lead?.stage ?? LeadStage.newLead;
    _activityState = lead?.activityState ?? ActivityState.idle;
    _paymentStatus = lead?.paymentStatus ?? PaymentStatus.free;

    // Section 3: Meeting
    _meetingAgenda = lead?.meetingAgenda ?? MeetingAgenda.demo;
    _meetingDate = lead?.meetingDate;
    _meetingDateController = TextEditingController(
      text: _meetingDate != null
          ? DateFormat('dd MMM yyyy').format(_meetingDate!)
          : '',
    );
    _meetingTimeController =
        TextEditingController(text: lead?.meetingTime ?? '');
    _meetingLinkController =
        TextEditingController(text: lead?.meetingLink ?? '');

    // Section 4: Follow-up
    _lastCallDate = lead?.lastCallDate;
    _lastCallDateController = TextEditingController(
      text: _lastCallDate != null
          ? DateFormat('dd MMM yyyy').format(_lastCallDate!)
          : '',
    );
    _nextFollowUpDate = lead?.nextFollowUpDate;
    _nextFollowUpDateController = TextEditingController(
      text: _nextFollowUpDate != null
          ? DateFormat('dd MMM yyyy').format(_nextFollowUpDate!)
          : '',
    );
    _nextFollowUpTimeController =
        TextEditingController(text: lead?.nextFollowUpTime ?? '');
    _commentController =
        TextEditingController(text: lead?.comment ?? '');

    // Section 5: Notes
    _notesController = TextEditingController(text: lead?.notes ?? '');

    // Section 6: Submitter Info — auto-fill from logged-in user on new leads
    final user = widget.currentUser;
    _submitterNameController = TextEditingController(
        text: lead?.submitterName ?? user?.name ?? '');
    _submitterEmailController = TextEditingController(
        text: lead?.submitterEmail ?? user?.email ?? '');
    _submitterMobileController = TextEditingController(
        text: lead?.submitterMobile ?? user?.phone ?? '');
    _groupNameController = TextEditingController(
        text: lead?.groupName ?? user?.groupId ?? '');
    _subGroupController =
        TextEditingController(text: lead?.subGroup ?? '');
  }

  @override
  void dispose() {
    _clientBusinessNameController.dispose();
    _clientNameController.dispose();
    _clientWhatsAppController.dispose();
    _clientMobileController.dispose();
    _clientEmailController.dispose();
    _countryController.dispose();
    _stateController.dispose();
    _clientCityController.dispose();
    _meetingDateController.dispose();
    _meetingTimeController.dispose();
    _meetingLinkController.dispose();
    _lastCallDateController.dispose();
    _nextFollowUpDateController.dispose();
    _nextFollowUpTimeController.dispose();
    _commentController.dispose();
    _notesController.dispose();
    _submitterNameController.dispose();
    _submitterEmailController.dispose();
    _submitterMobileController.dispose();
    _groupNameController.dispose();
    _subGroupController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Date Pickers
  // ---------------------------------------------------------------------------

  Future<void> _pickDate({
    required DateTime? current,
    required TextEditingController controller,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        controller.text = DateFormat('dd MMM yyyy').format(picked);
        onPicked(picked);
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------

  void _handleSave() {
    if (!_formKey.currentState!.validate()) return;

    if (_isEditing) {
      final lead = widget.existingLead!;
      lead.clientBusinessName = _clientBusinessNameController.text.trim();
      lead.clientName = _clientNameController.text.trim();
      lead.clientWhatsApp = _clientWhatsAppController.text.trim();
      lead.clientMobile = _clientMobileController.text.trim();
      lead.clientEmail = _clientEmailController.text.trim();
      lead.country = _countryController.text.trim();
      lead.state = _stateController.text.trim();
      lead.clientCity = _clientCityController.text.trim();
      lead.interestedInProduct = _interestedInProduct;
      lead.rating = _rating;
      lead.health = _health;
      lead.stage = _stage;
      lead.activityState = _activityState;
      lead.paymentStatus = _paymentStatus;
      lead.meetingAgenda = _meetingAgenda;
      lead.meetingDate = _meetingDate;
      lead.meetingTime = _meetingTimeController.text.trim();
      lead.meetingLink = _meetingLinkController.text.trim();
      lead.lastCallDate = _lastCallDate;
      lead.nextFollowUpDate = _nextFollowUpDate;
      lead.nextFollowUpTime = _nextFollowUpTimeController.text.trim();
      lead.comment = _commentController.text.trim();
      lead.notes = _notesController.text.trim();
      lead.submitterName = _submitterNameController.text.trim();
      lead.submitterEmail = _submitterEmailController.text.trim();
      lead.submitterMobile = _submitterMobileController.text.trim();
      lead.groupName = _groupNameController.text.trim();
      lead.subGroup = _subGroupController.text.trim();
      lead.updatedAt = DateTime.now();
      widget.onSave(lead);
    } else {
      final lead = Lead(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        clientName: _clientNameController.text.trim(),
        clientBusinessName: _clientBusinessNameController.text.trim(),
        clientWhatsApp: _clientWhatsAppController.text.trim(),
        clientMobile: _clientMobileController.text.trim(),
        clientEmail: _clientEmailController.text.trim(),
        country: _countryController.text.trim(),
        state: _stateController.text.trim(),
        clientCity: _clientCityController.text.trim(),
        interestedInProduct: _interestedInProduct,
        rating: _rating,
        health: _health,
        stage: _stage,
        activityState: _activityState,
        paymentStatus: _paymentStatus,
        meetingAgenda: _meetingAgenda,
        meetingDate: _meetingDate,
        meetingTime: _meetingTimeController.text.trim(),
        meetingLink: _meetingLinkController.text.trim(),
        lastCallDate: _lastCallDate,
        nextFollowUpDate: _nextFollowUpDate,
        nextFollowUpTime: _nextFollowUpTimeController.text.trim(),
        comment: _commentController.text.trim(),
        notes: _notesController.text.trim(),
        submitterName: _submitterNameController.text.trim(),
        submitterEmail: _submitterEmailController.text.trim(),
        submitterMobile: _submitterMobileController.text.trim(),
        groupName: _groupNameController.text.trim(),
        subGroup: _subGroupController.text.trim(),
      );
      widget.onSave(lead);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Lead' : 'New Lead'),
      ),
      body: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 800;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildClientInformationSection(isWide),
                  const SizedBox(height: 16),
                  _buildLeadStatusSection(isWide),
                  const SizedBox(height: 16),
                  _buildMeetingSection(isWide),
                  const SizedBox(height: 16),
                  _buildFollowUpSection(isWide),
                  const SizedBox(height: 16),
                  _buildNotesSection(),
                  const SizedBox(height: 16),
                  _buildSubmitterInfoSection(isWide),
                  const SizedBox(height: 24),
                  _buildActions(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section 1: Client Information
  // ---------------------------------------------------------------------------
  Widget _buildClientInformationSection(bool isWide) {
    final fields = <Widget>[
      _buildTextField(
        controller: _clientBusinessNameController,
        label: 'Business Name',
      ),
      _buildTextField(
        controller: _clientNameController,
        label: 'Client Name',
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Client name is required';
          }
          return null;
        },
      ),
      _buildTextField(
        controller: _clientWhatsAppController,
        label: 'WhatsApp',
        keyboardType: TextInputType.phone,
      ),
      _buildTextField(
        controller: _clientMobileController,
        label: 'Mobile',
        keyboardType: TextInputType.phone,
      ),
      _buildTextField(
        controller: _clientEmailController,
        label: 'Email',
        keyboardType: TextInputType.emailAddress,
      ),
      _buildTextField(
        controller: _countryController,
        label: 'Country',
      ),
      _buildTextField(
        controller: _stateController,
        label: 'State',
      ),
      _buildTextField(
        controller: _clientCityController,
        label: 'City',
      ),
    ];

    return _buildSectionCard(
      title: 'Client Information',
      icon: Icons.person_outline,
      isWide: isWide,
      fields: fields,
    );
  }

  // ---------------------------------------------------------------------------
  // Section 2: Lead Status
  // ---------------------------------------------------------------------------
  Widget _buildLeadStatusSection(bool isWide) {
    final fields = <Widget>[
      _buildDropdown<ProductService>(
        label: 'Interested In Product',
        value: _interestedInProduct,
        items: ProductService.values,
        itemLabel: (v) => v.label,
        onChanged: (v) {
          if (v != null) setState(() => _interestedInProduct = v);
        },
      ),
      _buildRatingDropdown(),
      _HealthSelectorWidget(
        health: _health,
        onChanged: (value) => setState(() => _health = value),
      ),
      _buildDropdown<LeadStage>(
        label: 'Stage',
        value: _stage,
        items: LeadStage.values,
        itemLabel: (v) => v.label,
        onChanged: (v) {
          if (v != null) setState(() => _stage = v);
        },
      ),
      _buildDropdown<ActivityState>(
        label: 'Activity State',
        value: _activityState,
        items: ActivityState.values,
        itemLabel: (v) => v.label,
        onChanged: (v) {
          if (v != null) setState(() => _activityState = v);
        },
      ),
      _buildDropdown<PaymentStatus>(
        label: 'Payment Status',
        value: _paymentStatus,
        items: PaymentStatus.values,
        itemLabel: (v) => v.label,
        onChanged: (v) {
          if (v != null) setState(() => _paymentStatus = v);
        },
      ),
    ];

    return _buildSectionCard(
      title: 'Lead Status',
      icon: Icons.leaderboard_outlined,
      isWide: isWide,
      fields: fields,
    );
  }

  // ---------------------------------------------------------------------------
  // Section 3: Meeting
  // ---------------------------------------------------------------------------
  Widget _buildMeetingSection(bool isWide) {
    final fields = <Widget>[
      _buildDropdown<MeetingAgenda>(
        label: 'Meeting Agenda',
        value: _meetingAgenda,
        items: MeetingAgenda.values,
        itemLabel: (v) => v.label,
        onChanged: (v) {
          if (v != null) setState(() => _meetingAgenda = v);
        },
      ),
      _buildDateField(
        controller: _meetingDateController,
        label: 'Meeting Date',
        currentDate: _meetingDate,
        onPicked: (d) => _meetingDate = d,
      ),
      _buildTextField(
        controller: _meetingTimeController,
        label: 'Meeting Time',
      ),
      _buildTextField(
        controller: _meetingLinkController,
        label: 'Meeting Link',
        keyboardType: TextInputType.url,
      ),
    ];

    return _buildSectionCard(
      title: 'Meeting',
      icon: Icons.videocam_outlined,
      isWide: isWide,
      fields: fields,
    );
  }

  // ---------------------------------------------------------------------------
  // Section 4: Follow-up
  // ---------------------------------------------------------------------------
  Widget _buildFollowUpSection(bool isWide) {
    final fields = <Widget>[
      _buildDateField(
        controller: _lastCallDateController,
        label: 'Last Call Date',
        currentDate: _lastCallDate,
        onPicked: (d) => _lastCallDate = d,
      ),
      _buildDateField(
        controller: _nextFollowUpDateController,
        label: 'Next Follow-up Date',
        currentDate: _nextFollowUpDate,
        onPicked: (d) => _nextFollowUpDate = d,
      ),
      _buildTextField(
        controller: _nextFollowUpTimeController,
        label: 'Next Follow-up Time',
      ),
      _buildTextField(
        controller: _commentController,
        label: 'Comment',
        maxLines: 3,
      ),
    ];

    return _buildSectionCard(
      title: 'Follow-up',
      icon: Icons.phone_callback_outlined,
      isWide: isWide,
      fields: fields,
    );
  }

  // ---------------------------------------------------------------------------
  // Section 5: Notes
  // ---------------------------------------------------------------------------
  Widget _buildNotesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notes_outlined,
                    size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Notes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              textInputAction: TextInputAction.newline,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section 6: Submitter Info
  // ---------------------------------------------------------------------------
  Widget _buildSubmitterInfoSection(bool isWide) {
    // Auto-filled from user account for new leads
    final bool autoFilled = !_isEditing && widget.currentUser != null;
    final fields = <Widget>[
      _buildTextField(
        controller: _submitterNameController,
        label: 'Submitter Name',
        readOnly: autoFilled,
      ),
      _buildTextField(
        controller: _submitterEmailController,
        label: 'Submitter Email',
        keyboardType: TextInputType.emailAddress,
        readOnly: autoFilled,
      ),
      _buildTextField(
        controller: _submitterMobileController,
        label: 'Submitter Mobile',
        keyboardType: TextInputType.phone,
        readOnly: autoFilled,
      ),
      _buildTextField(
        controller: _groupNameController,
        label: 'Group Name',
      ),
      _buildTextField(
        controller: _subGroupController,
        label: 'Sub Group',
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assignment_ind_outlined,
                    size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Submitter Info',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (autoFilled) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Text(
                      'Auto-filled from your account',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            if (isWide)
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: fields.map((field) {
                  return SizedBox(width: 360, child: field);
                }).toList(),
              )
            else
              Column(
                children: fields
                    .map((field) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: field,
                        ))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------
  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 12),
        FilledButton(
          onPressed: _handleSave,
          child: const Text('Save'),
        ),
      ],
    );
  }

  // ===========================================================================
  // Reusable helpers
  // ===========================================================================

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required bool isWide,
    required List<Widget> fields,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon,
                    size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isWide)
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: fields.map((field) {
                  return SizedBox(
                    width: _fieldWidthForWide(field),
                    child: field,
                  );
                }).toList(),
              )
            else
              Column(
                children: fields
                    .map((field) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: field,
                        ))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  double _fieldWidthForWide(Widget field) {
    // Health selector gets full width; others share two columns.
    if (field is _HealthSelectorWidget) {
      return double.infinity;
    }
    return 360;
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    String? prefixText,
    bool readOnly = false,
    VoidCallback? onTap,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixText: prefixText,
        alignLabelWithHint: maxLines > 1,
      ),
      keyboardType: keyboardType,
      validator: validator,
      readOnly: readOnly,
      onTap: onTap,
      maxLines: maxLines,
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: items
          .map((item) => DropdownMenuItem<T>(
                value: item,
                child: Text(itemLabel(item)),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildRatingDropdown() {
    final ratingValues = List.generate(9, (i) => (i + 1) * 10);
    return DropdownButtonFormField<int>(
      value: _rating,
      decoration: const InputDecoration(
        labelText: 'Rating',
        border: OutlineInputBorder(),
      ),
      items: ratingValues
          .map((v) => DropdownMenuItem<int>(
                value: v,
                child: Text('$v'),
              ))
          .toList(),
      onChanged: (v) {
        if (v != null) setState(() => _rating = v);
      },
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    required DateTime? currentDate,
    required ValueChanged<DateTime> onPicked,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.calendar_today),
      ),
      readOnly: true,
      onTap: () => _pickDate(
        current: currentDate,
        controller: controller,
        onPicked: onPicked,
      ),
    );
  }
}

// =============================================================================
// Private helper widgets (used for type-checking in _fieldWidthForWide)
// =============================================================================

class _HealthSelectorWidget extends StatelessWidget {
  final LeadHealth health;
  final ValueChanged<LeadHealth> onChanged;

  const _HealthSelectorWidget({
    required this.health,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Health',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<LeadHealth>(
            segments: LeadHealth.values.map((h) {
              final Color indicatorColor;
              switch (h) {
                case LeadHealth.hot:
                  indicatorColor = Colors.red;
                case LeadHealth.warm:
                  indicatorColor = Colors.orange;
                case LeadHealth.solo:
                  indicatorColor = Colors.teal;
                case LeadHealth.sleeping:
                  indicatorColor = Colors.blueGrey;
                case LeadHealth.dead:
                  indicatorColor = Colors.grey;
                case LeadHealth.junk:
                  indicatorColor = Colors.brown;
              }
              return ButtonSegment<LeadHealth>(
                value: h,
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: indicatorColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(h.label),
                  ],
                ),
              );
            }).toList(),
            selected: {health},
            onSelectionChanged: (selection) {
              if (selection.isNotEmpty) {
                onChanged(selection.first);
              }
            },
          ),
        ),
      ],
    );
  }
}
