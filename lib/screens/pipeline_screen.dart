import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/lead.dart';
import '../theme/app_theme.dart';

class PipelineScreen extends StatefulWidget {
  final List<Lead> leads;
  final void Function(Lead lead, LeadStage newStage) onStageChanged;
  final void Function() onAddLead;
  final void Function(Lead lead) onEditLead;
  final bool Function(Lead lead)? canEditLead;

  const PipelineScreen({
    super.key,
    required this.leads,
    required this.onStageChanged,
    required this.onAddLead,
    required this.onEditLead,
    this.canEditLead,
  });

  @override
  State<PipelineScreen> createState() => _PipelineScreenState();
}

class _PipelineScreenState extends State<PipelineScreen> {
  LeadStage? _hoveredStage;
  bool _showFilters = false;

  // --- Filter state ---
  final TextEditingController _searchController = TextEditingController();
  LeadHealth? _filterHealth;
  LeadStage? _filterStage;
  ActivityState? _filterActivity;
  PaymentStatus? _filterPayment;
  ProductService? _filterProduct;
  int? _filterRating;
  DateTime? _filterDateFrom;
  DateTime? _filterDateTo;
  bool _filterHasFollowUp = false;
  bool _filterHasMeeting = false;

  static const List<LeadStage> _stages = LeadStage.values;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasActiveFilters =>
      _searchController.text.isNotEmpty ||
      _filterHealth != null ||
      _filterStage != null ||
      _filterActivity != null ||
      _filterPayment != null ||
      _filterProduct != null ||
      _filterRating != null ||
      _filterDateFrom != null ||
      _filterDateTo != null ||
      _filterHasFollowUp ||
      _filterHasMeeting;

  List<Lead> get _filteredLeads {
    var results = widget.leads;

    // Keyword search
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      results = results.where((lead) {
        return lead.clientName.toLowerCase().contains(query) ||
            lead.clientBusinessName.toLowerCase().contains(query) ||
            lead.clientEmail.toLowerCase().contains(query) ||
            lead.clientMobile.contains(query) ||
            lead.clientWhatsApp.contains(query) ||
            lead.clientCity.toLowerCase().contains(query) ||
            lead.notes.toLowerCase().contains(query) ||
            lead.comment.toLowerCase().contains(query) ||
            lead.submitterName.toLowerCase().contains(query);
      }).toList();
    }

    // Dropdown filters
    if (_filterHealth != null) {
      results = results.where((l) => l.health == _filterHealth).toList();
    }
    if (_filterStage != null) {
      results = results.where((l) => l.stage == _filterStage).toList();
    }
    if (_filterActivity != null) {
      results =
          results.where((l) => l.activityState == _filterActivity).toList();
    }
    if (_filterPayment != null) {
      results =
          results.where((l) => l.paymentStatus == _filterPayment).toList();
    }
    if (_filterProduct != null) {
      results =
          results.where((l) => l.interestedInProduct == _filterProduct).toList();
    }
    if (_filterRating != null) {
      results = results.where((l) => l.rating == _filterRating).toList();
    }

    // Date range (applies to createdAt)
    if (_filterDateFrom != null) {
      final from = DateTime(
          _filterDateFrom!.year, _filterDateFrom!.month, _filterDateFrom!.day);
      results = results.where((l) => !l.createdAt.isBefore(from)).toList();
    }
    if (_filterDateTo != null) {
      final to = DateTime(
          _filterDateTo!.year, _filterDateTo!.month, _filterDateTo!.day, 23, 59, 59);
      results = results.where((l) => !l.createdAt.isAfter(to)).toList();
    }

    // Checkbox filters
    if (_filterHasFollowUp) {
      results = results.where((l) => l.nextFollowUpDate != null).toList();
    }
    if (_filterHasMeeting) {
      results = results.where((l) => l.meetingDate != null).toList();
    }

    return results;
  }

  List<Lead> _leadsForStage(LeadStage stage) {
    return _filteredLeads.where((lead) => lead.stage == stage).toList();
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _filterHealth = null;
      _filterStage = null;
      _filterActivity = null;
      _filterPayment = null;
      _filterProduct = null;
      _filterRating = null;
      _filterDateFrom = null;
      _filterDateTo = null;
      _filterHasFollowUp = false;
      _filterHasMeeting = false;
    });
  }

  Future<void> _pickFilterDate(bool isFrom) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? (_filterDateFrom ?? now) : (_filterDateTo ?? now),
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _filterDateFrom = picked;
        } else {
          _filterDateTo = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredCount = _filteredLeads.length;
    final totalCount = widget.leads.length;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Column(
        children: [
          // Search bar + filter toggle
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search leads...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Badge(
                      isLabelVisible: _hasActiveFilters,
                      smallSize: 8,
                      child: IconButton(
                        icon: Icon(
                          _showFilters
                              ? Icons.filter_list_off
                              : Icons.filter_list,
                          color: _hasActiveFilters
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        tooltip: 'Toggle filters',
                        onPressed: () =>
                            setState(() => _showFilters = !_showFilters),
                      ),
                    ),
                    if (_hasActiveFilters) ...[
                      const SizedBox(width: 4),
                      TextButton.icon(
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.clear_all, size: 18),
                        label: const Text('Clear'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red.shade600,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ],
                  ],
                ),
                if (_hasActiveFilters)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Showing $filteredCount of $totalCount leads',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Filter panel (expandable)
          if (_showFilters) _buildFilterPanel(),
          // Pipeline columns
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children:
                    _stages.map((stage) => _buildStageColumn(stage)).toList(),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: widget.onAddLead,
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildFilterPanel() {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 10),
          // Row 1: Status dropdowns
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildFilterDropdown<LeadHealth>(
                label: 'Health',
                value: _filterHealth,
                items: LeadHealth.values,
                itemLabel: (v) => v.label,
                onChanged: (v) => setState(() => _filterHealth = v),
              ),
              _buildFilterDropdown<LeadStage>(
                label: 'Stage',
                value: _filterStage,
                items: LeadStage.values,
                itemLabel: (v) => v.label,
                onChanged: (v) => setState(() => _filterStage = v),
              ),
              _buildFilterDropdown<ActivityState>(
                label: 'Activity',
                value: _filterActivity,
                items: ActivityState.values,
                itemLabel: (v) => v.label,
                onChanged: (v) => setState(() => _filterActivity = v),
              ),
              _buildFilterDropdown<PaymentStatus>(
                label: 'Payment',
                value: _filterPayment,
                items: PaymentStatus.values,
                itemLabel: (v) => v.label,
                onChanged: (v) => setState(() => _filterPayment = v),
              ),
              _buildFilterDropdown<ProductService>(
                label: 'Product/Service',
                value: _filterProduct,
                items: ProductService.values,
                itemLabel: (v) => v.label,
                onChanged: (v) => setState(() => _filterProduct = v),
                width: 220,
              ),
              _buildFilterDropdown<int>(
                label: 'Rating',
                value: _filterRating,
                items: List.generate(9, (i) => (i + 1) * 10),
                itemLabel: (v) => '$v',
                onChanged: (v) => setState(() => _filterRating = v),
                width: 100,
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Row 2: Date range + checkboxes
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Date From
              InkWell(
                onTap: () => _pickFilterDate(true),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today,
                          size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text(
                        _filterDateFrom != null
                            ? dateFormat.format(_filterDateFrom!)
                            : 'From Date',
                        style: TextStyle(
                          fontSize: 13,
                          color: _filterDateFrom != null
                              ? Colors.black87
                              : Colors.grey.shade500,
                        ),
                      ),
                      if (_filterDateFrom != null) ...[
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _filterDateFrom = null),
                          child:
                              Icon(Icons.close, size: 14, color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Date To
              InkWell(
                onTap: () => _pickFilterDate(false),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today,
                          size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text(
                        _filterDateTo != null
                            ? dateFormat.format(_filterDateTo!)
                            : 'To Date',
                        style: TextStyle(
                          fontSize: 13,
                          color: _filterDateTo != null
                              ? Colors.black87
                              : Colors.grey.shade500,
                        ),
                      ),
                      if (_filterDateTo != null) ...[
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _filterDateTo = null),
                          child:
                              Icon(Icons.close, size: 14, color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Follow-up checkbox
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _filterHasFollowUp,
                      onChanged: (v) =>
                          setState(() => _filterHasFollowUp = v ?? false),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => setState(
                        () => _filterHasFollowUp = !_filterHasFollowUp),
                    child: const Text('Has Follow-up',
                        style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
              // Meeting checkbox
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _filterHasMeeting,
                      onChanged: (v) =>
                          setState(() => _filterHasMeeting = v ?? false),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _filterHasMeeting = !_filterHasMeeting),
                    child: const Text('Has Meeting',
                        style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
    double width = 150,
  }) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<T>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
        ),
        isExpanded: true,
        items: [
          DropdownMenuItem<T>(
            value: null,
            child: Text('All', style: TextStyle(color: Colors.grey.shade500)),
          ),
          ...items.map((item) => DropdownMenuItem<T>(
                value: item,
                child: Text(
                  itemLabel(item),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              )),
        ],
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildStageColumn(LeadStage stage) {
    final stageLeads = _leadsForStage(stage);
    final stageLabel = stage.label;
    final color = AppTheme.stageColor(stageLabel);
    final isHovered = _hoveredStage == stage;

    return DragTarget<Lead>(
      onWillAcceptWithDetails: (details) {
        if (details.data.stage != stage) {
          // Check edit permission if callback provided
          if (widget.canEditLead != null &&
              !widget.canEditLead!(details.data)) {
            return false;
          }
          setState(() => _hoveredStage = stage);
          return true;
        }
        return false;
      },
      onLeave: (_) {
        setState(() => _hoveredStage = null);
      },
      onAcceptWithDetails: (details) {
        setState(() => _hoveredStage = null);
        widget.onStageChanged(details.data, stage);
      },
      builder: (context, candidateData, rejectedData) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 280,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: isHovered ? color.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: isHovered
                ? Border.all(color: color.withOpacity(0.5), width: 2)
                : Border.all(color: Colors.grey.shade200, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Color strip at top
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
              ),
              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        stageLabel,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${stageLeads.length}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Lead cards list
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height - 280,
                ),
                child: stageLeads.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'No leads',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 8),
                        itemCount: stageLeads.length,
                        itemBuilder: (context, index) {
                          return _buildLeadCard(stageLeads[index], color);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLeadCard(Lead lead, Color stageColor) {
    final healthLabel = lead.health.label;
    final healthColor = AppTheme.healthColor(healthLabel);

    return Draggable<Lead>(
      data: lead,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 260,
          child: _buildCardContent(lead, stageColor, healthColor,
              isDragging: true),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildCardContent(lead, stageColor, healthColor),
      ),
      child: GestureDetector(
        onTap: () => widget.onEditLead(lead),
        child: _buildCardContent(lead, stageColor, healthColor),
      ),
    );
  }

  Widget _buildCardContent(Lead lead, Color stageColor, Color healthColor,
      {bool isDragging = false}) {
    final activityLabel = lead.activityState.label;
    final activityColor = AppTheme.activityColor(activityLabel);
    final paymentLabel = lead.paymentStatus.label;
    final paymentColor = AppTheme.paymentColor(paymentLabel);
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: isDragging ? 6 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color:
              isDragging ? stageColor.withOpacity(0.4) : Colors.grey.shade200,
          width: isDragging ? 1.5 : 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Client name and health indicator
            Row(
              children: [
                Expanded(
                  child: Text(
                    lead.clientName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: lead.health.label,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: healthColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: healthColor.withOpacity(0.4),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Client business name
            if (lead.clientBusinessName.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                lead.clientBusinessName,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 6),
            // Interested product/service
            Text(
              lead.interestedInProduct.label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            // Rating value
            Text(
              'Rating: ${lead.rating}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: stageColor,
              ),
            ),
            const SizedBox(height: 8),
            // Activity state and payment status badges
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _buildBadge(activityLabel, activityColor),
                _buildBadge(paymentLabel, paymentColor),
              ],
            ),
            const SizedBox(height: 8),
            // Timestamps
            Row(
              children: [
                Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Created: ${dateFormat.format(lead.createdAt)}',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (lead.updatedAt != lead.createdAt) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.update, size: 12, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Updated: ${dateFormat.format(lead.updatedAt)}',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
