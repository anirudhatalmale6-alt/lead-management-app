import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/lead.dart';
import '../models/user.dart';
import '../data/location_data.dart';

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
  String? _selectedCountry;
  String? _selectedState;
  String? _selectedCity;
  List<String> _availableStates = [];
  List<String> _availableCities = [];

  // Custom text fields for "Other" option
  late final TextEditingController _customCountryController;
  late final TextEditingController _customStateController;
  late final TextEditingController _customCityController;

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

    // Initialize location dropdowns
    // Check if existing values are in the dropdown lists, otherwise treat as custom
    final existingCountry = lead?.country ?? '';
    final existingState = lead?.state ?? '';
    final existingCity = lead?.clientCity ?? '';

    if (existingCountry.isNotEmpty && LocationData.countries.contains(existingCountry)) {
      _selectedCountry = existingCountry;
      _availableStates = LocationData.getStates(existingCountry);
    } else if (existingCountry.isNotEmpty) {
      _selectedCountry = 'Other';
      _availableStates = LocationData.getStates('Other');
    }

    if (existingState.isNotEmpty && _availableStates.contains(existingState)) {
      _selectedState = existingState;
      _availableCities = LocationData.getCities(existingState);
    } else if (existingState.isNotEmpty) {
      _selectedState = 'Other';
      _availableCities = LocationData.getCities('Other');
    }

    if (existingCity.isNotEmpty && _availableCities.contains(existingCity)) {
      _selectedCity = existingCity;
    } else if (existingCity.isNotEmpty) {
      _selectedCity = 'Other';
    }

    // Initialize custom text controllers
    _customCountryController = TextEditingController(
      text: (_selectedCountry == 'Other' && existingCountry != 'Other') ? existingCountry : '',
    );
    _customStateController = TextEditingController(
      text: (_selectedState == 'Other' && existingState != 'Other') ? existingState : '',
    );
    _customCityController = TextEditingController(
      text: (_selectedCity == 'Other' && existingCity != 'Other') ? existingCity : '',
    );

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
    _customCountryController.dispose();
    _customStateController.dispose();
    _customCityController.dispose();
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

  // Helper to get the actual location value (custom text or dropdown value)
  String _getCountryValue() {
    if (_selectedCountry == 'Other') {
      return _customCountryController.text.trim().isNotEmpty
          ? _customCountryController.text.trim()
          : 'Other';
    }
    return _selectedCountry ?? '';
  }

  String _getStateValue() {
    if (_selectedState == 'Other') {
      return _customStateController.text.trim().isNotEmpty
          ? _customStateController.text.trim()
          : 'Other';
    }
    return _selectedState ?? '';
  }

  String _getCityValue() {
    if (_selectedCity == 'Other') {
      return _customCityController.text.trim().isNotEmpty
          ? _customCityController.text.trim()
          : 'Other';
    }
    return _selectedCity ?? '';
  }

  void _handleSave() {
    if (!_formKey.currentState!.validate()) return;

    if (_isEditing) {
      final lead = widget.existingLead!;
      lead.clientBusinessName = _clientBusinessNameController.text.trim();
      lead.clientName = _clientNameController.text.trim();
      lead.clientWhatsApp = _clientWhatsAppController.text.trim();
      lead.clientMobile = _clientMobileController.text.trim();
      lead.clientEmail = _clientEmailController.text.trim();
      lead.country = _getCountryValue();
      lead.state = _getStateValue();
      lead.clientCity = _getCityValue();
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
        country: _getCountryValue(),
        state: _getStateValue(),
        clientCity: _getCityValue(),
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
      // Country dropdown
      DropdownButtonFormField<String>(
        value: _selectedCountry,
        decoration: const InputDecoration(
          labelText: 'Country',
          border: OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem<String>(
            value: null,
            child: Text('Select Country'),
          ),
          ...LocationData.countries.map((country) => DropdownMenuItem<String>(
                value: country,
                child: Text(country),
              )),
        ],
        onChanged: (value) {
          setState(() {
            _selectedCountry = value;
            _selectedState = null;
            _selectedCity = null;
            _customCountryController.clear();
            _customStateController.clear();
            _customCityController.clear();
            _availableStates = value != null ? LocationData.getStates(value) : [];
            _availableCities = [];
          });
        },
      ),
      // Custom Country text field (when "Other" is selected)
      if (_selectedCountry == 'Other')
        _buildTextField(
          controller: _customCountryController,
          label: 'Enter Country Name',
        ),
      // State dropdown
      DropdownButtonFormField<String>(
        value: _selectedState,
        decoration: const InputDecoration(
          labelText: 'State',
          border: OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem<String>(
            value: null,
            child: Text('Select State'),
          ),
          ..._availableStates.map((state) => DropdownMenuItem<String>(
                value: state,
                child: Text(state),
              )),
        ],
        onChanged: _selectedCountry == null
            ? null
            : (value) {
                setState(() {
                  _selectedState = value;
                  _selectedCity = null;
                  _customStateController.clear();
                  _customCityController.clear();
                  _availableCities =
                      value != null ? LocationData.getCities(value) : [];
                });
              },
      ),
      // Custom State text field (when "Other" is selected)
      if (_selectedState == 'Other')
        _buildTextField(
          controller: _customStateController,
          label: 'Enter State Name',
        ),
      // City dropdown
      DropdownButtonFormField<String>(
        value: _selectedCity,
        decoration: const InputDecoration(
          labelText: 'City',
          border: OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem<String>(
            value: null,
            child: Text('Select City'),
          ),
          ..._availableCities.map((city) => DropdownMenuItem<String>(
                value: city,
                child: Text(city),
              )),
        ],
        onChanged: _selectedState == null
            ? null
            : (value) {
                setState(() {
                  _selectedCity = value;
                  _customCityController.clear();
                });
              },
      ),
      // Custom City text field (when "Other" is selected)
      if (_selectedCity == 'Other')
        _buildTextField(
          controller: _customCityController,
          label: 'Enter City Name',
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
      _buildTimeField(
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
      _buildTimeField(
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

  Widget _buildTimeField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.access_time),
        hintText: 'Tap to select time',
      ),
      readOnly: true,
      onTap: () async {
        // Parse existing time if available
        TimeOfDay initialTime = const TimeOfDay(hour: 10, minute: 0);
        final existingText = controller.text.trim();
        if (existingText.isNotEmpty) {
          try {
            // Try to parse AM/PM format like "10:30 AM"
            final parts = existingText.replaceAll(RegExp(r'[APap][Mm]'), '').trim().split(':');
            if (parts.length == 2) {
              int hour = int.parse(parts[0].trim());
              int minute = int.parse(parts[1].trim());
              if (existingText.toUpperCase().contains('PM') && hour != 12) hour += 12;
              if (existingText.toUpperCase().contains('AM') && hour == 12) hour = 0;
              initialTime = TimeOfDay(hour: hour, minute: minute);
            }
          } catch (_) {}
        }

        final picked = await showTimePicker(
          context: context,
          initialTime: initialTime,
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
              child: child!,
            );
          },
        );
        if (picked != null) {
          // Format as 12-hour with AM/PM
          final hour = picked.hourOfPeriod == 0 ? 12 : picked.hourOfPeriod;
          final minute = picked.minute.toString().padLeft(2, '0');
          final period = picked.period == DayPeriod.am ? 'AM' : 'PM';
          setState(() {
            controller.text = '$hour:$minute $period';
          });
        }
      },
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
