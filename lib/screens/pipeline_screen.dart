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

enum PipelineViewType { kanban, table }
enum SortField { createdAt, name, rating, stage, health }
enum SortOrder { asc, desc }

class _PipelineScreenState extends State<PipelineScreen> {
  LeadStage? _hoveredStage;
  bool _showFilters = false;
  PipelineViewType _viewType = PipelineViewType.kanban;

  // Sorting state
  SortField _sortField = SortField.createdAt;
  SortOrder _sortOrder = SortOrder.desc; // Latest first by default

  // Scroll controller for Kanban view
  final ScrollController _kanbanScrollController = ScrollController();
  bool _canScrollLeft = false;
  bool _canScrollRight = true;

  // Table view column configuration
  static const List<String> _defaultColumns = [
    'Name',
    'Business',
    'Stage',
    'Health',
    'Product',
    'Rating',
    'Activity',
    'Payment',
    'City',
    'Created',
  ];
  List<String> _tableColumns = List.from(_defaultColumns);
  Set<String> _hiddenColumns = {}; // Columns that are hidden

  // Get visible columns only
  List<String> get _visibleColumns =>
      _tableColumns.where((c) => !_hiddenColumns.contains(c)).toList();

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
  void initState() {
    super.initState();
    _kanbanScrollController.addListener(_updateScrollIndicators);
    // Initialize scroll indicators after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScrollIndicators();
    });
  }

  void _updateScrollIndicators() {
    if (!_kanbanScrollController.hasClients) return;
    setState(() {
      _canScrollLeft = _kanbanScrollController.offset > 10;
      _canScrollRight = _kanbanScrollController.offset <
          (_kanbanScrollController.position.maxScrollExtent - 10);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _kanbanScrollController.dispose();
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
    var results = widget.leads.toList();

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

    // Apply sorting
    results = _sortLeads(results);

    return results;
  }

  List<Lead> _sortLeads(List<Lead> leads) {
    final sorted = List<Lead>.from(leads);
    sorted.sort((a, b) {
      int comparison;
      switch (_sortField) {
        case SortField.createdAt:
          comparison = a.createdAt.compareTo(b.createdAt);
          break;
        case SortField.name:
          comparison = a.clientName.toLowerCase().compareTo(b.clientName.toLowerCase());
          break;
        case SortField.rating:
          comparison = a.rating.compareTo(b.rating);
          break;
        case SortField.stage:
          comparison = a.stage.index.compareTo(b.stage.index);
          break;
        case SortField.health:
          comparison = a.health.index.compareTo(b.health.index);
          break;
      }
      return _sortOrder == SortOrder.asc ? comparison : -comparison;
    });
    return sorted;
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
          // Search bar + filter toggle + view toggle
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
                    // View toggle
                    SegmentedButton<PipelineViewType>(
                      segments: const [
                        ButtonSegment(
                          value: PipelineViewType.kanban,
                          icon: Icon(Icons.view_kanban, size: 18),
                          label: Text('Kanban'),
                        ),
                        ButtonSegment(
                          value: PipelineViewType.table,
                          icon: Icon(Icons.table_chart, size: 18),
                          label: Text('Table'),
                        ),
                      ],
                      selected: {_viewType},
                      onSelectionChanged: (selection) {
                        setState(() => _viewType = selection.first);
                      },
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
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
          // Pipeline view - Kanban or Table
          Expanded(
            child: _viewType == PipelineViewType.kanban
                ? _buildKanbanViewWithArrows()
                : _buildTableView(),
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

  Widget _buildKanbanViewWithArrows() {
    return Stack(
      children: [
        // Main scrollable Kanban view
        Scrollbar(
          controller: _kanbanScrollController,
          thumbVisibility: true,
          trackVisibility: true,
          child: SingleChildScrollView(
            controller: _kanbanScrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _stages.map((stage) => _buildStageColumn(stage)).toList(),
            ),
          ),
        ),
        // Left arrow
        if (_canScrollLeft)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: () {
                _kanbanScrollController.animateTo(
                  (_kanbanScrollController.offset - 300).clamp(0.0, _kanbanScrollController.position.maxScrollExtent),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              child: Container(
                width: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.white, Colors.white.withOpacity(0)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade600,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    child: const Icon(Icons.chevron_left, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ),
          ),
        // Right arrow
        if (_canScrollRight)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: () {
                _kanbanScrollController.animateTo(
                  (_kanbanScrollController.offset + 300).clamp(0.0, _kanbanScrollController.position.maxScrollExtent),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              child: Container(
                width: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.white.withOpacity(0), Colors.white],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade600,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    child: const Icon(Icons.chevron_right, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ),
          ),
        // Stage indicator at the top
        Positioned(
          top: 0,
          left: 48,
          right: 48,
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(2),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (!_kanbanScrollController.hasClients) return const SizedBox();
                final maxScroll = _kanbanScrollController.position.maxScrollExtent;
                final currentScroll = _kanbanScrollController.offset;
                final progress = maxScroll > 0 ? (currentScroll / maxScroll) : 0.0;
                final indicatorWidth = constraints.maxWidth * 0.2;
                return Stack(
                  children: [
                    Positioned(
                      left: (constraints.maxWidth - indicatorWidth) * progress,
                      child: Container(
                        width: indicatorWidth,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade600,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableView() {
    final dateFormat = DateFormat('dd MMM yyyy');
    final leads = _filteredLeads;

    return Column(
      children: [
        // Sort options row with column settings button
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Column Settings Button - unique approach
                FilledButton.tonalIcon(
                  onPressed: _showColumnSettingsDialog,
                  icon: const Icon(Icons.view_column, size: 18),
                  label: const Text('Columns'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(width: 16),
                const Text('Sort by: ', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(width: 8),
                DropdownButton<SortField>(
                  value: _sortField,
                  underline: const SizedBox(),
                  isDense: true,
                  items: const [
                    DropdownMenuItem(value: SortField.createdAt, child: Text('Created')),
                    DropdownMenuItem(value: SortField.name, child: Text('Name')),
                    DropdownMenuItem(value: SortField.rating, child: Text('Rating')),
                    DropdownMenuItem(value: SortField.stage, child: Text('Stage')),
                    DropdownMenuItem(value: SortField.health, child: Text('Health')),
                  ],
                  onChanged: (v) => setState(() => _sortField = v ?? SortField.createdAt),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    _sortOrder == SortOrder.desc ? Icons.arrow_downward : Icons.arrow_upward,
                    size: 18,
                  ),
                  tooltip: _sortOrder == SortOrder.desc ? 'Newest first' : 'Oldest first',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() {
                    _sortOrder = _sortOrder == SortOrder.desc ? SortOrder.asc : SortOrder.desc;
                  }),
                ),
                Text(
                  _sortOrder == SortOrder.desc ? 'Newest' : 'Oldest',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                if (_hiddenColumns.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Chip(
                    label: Text('${_hiddenColumns.length} hidden'),
                    deleteIcon: const Icon(Icons.visibility, size: 16),
                    onDeleted: () => setState(() => _hiddenColumns.clear()),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        // Scrollable table with fixed minimum column widths
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Minimum table width to prevent column overlap
              const minTableWidth = 900.0;
              final tableWidth = constraints.maxWidth < minTableWidth
                  ? minTableWidth
                  : constraints.maxWidth;

              return Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: Column(
                      children: [
                        // Column header row
                        Container(
                          color: Colors.grey.shade200,
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                          child: Row(
                            children: List.generate(_visibleColumns.length, (index) {
                              final col = _visibleColumns[index];
                              final totalCols = _visibleColumns.length;
                              final wideCount = _visibleColumns.where((c) => c == 'Name' || c == 'Business').length;
                              final normalCount = totalCols - wideCount;
                              final unitWidth = (tableWidth - 32) / (wideCount * 2 + normalCount);
                              final colWidth = (col == 'Name' || col == 'Business') ? unitWidth * 2 : unitWidth;
                              return SizedBox(
                                width: colWidth,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    col,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        // Table rows
                        Expanded(
                          child: leads.isEmpty
                              ? const Center(child: Text('No leads found'))
                              : ListView.builder(
                                  itemCount: leads.length,
                                  itemBuilder: (context, index) {
                                    final lead = leads[index];
                                    final healthColor = AppTheme.healthColor(lead.health.label);
                                    final stageColor = AppTheme.stageColor(lead.stage.label);

                                    return InkWell(
                                      onTap: () => widget.onEditLead(lead),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12, horizontal: 16),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(color: Colors.grey.shade200),
                                          ),
                                          color: index.isEven ? Colors.white : Colors.grey.shade50,
                                        ),
                                        child: Row(
                                          children: [
                                            for (final col in _visibleColumns)
                                              Builder(builder: (context) {
                                                final totalCols = _visibleColumns.length;
                                                final wideCount = _visibleColumns.where((c) => c == 'Name' || c == 'Business').length;
                                                final normalCount = totalCols - wideCount;
                                                final unitWidth = (tableWidth - 32) / (wideCount * 2 + normalCount);
                                                final colWidth = (col == 'Name' || col == 'Business') ? unitWidth * 2 : unitWidth;
                                                return SizedBox(
                                                  width: colWidth,
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                                    child: _buildTableCell(col, lead, healthColor, stageColor, dateFormat),
                                                  ),
                                                );
                                              }),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTableCell(String column, Lead lead, Color healthColor,
      Color stageColor, DateFormat dateFormat) {
    switch (column) {
      case 'Name':
        return Text(lead.clientName,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w500));
      case 'Business':
        return Text(lead.clientBusinessName, overflow: TextOverflow.ellipsis);
      case 'Stage':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: stageColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            lead.stage.label,
            style: TextStyle(fontSize: 11, color: stageColor),
            overflow: TextOverflow.ellipsis,
          ),
        );
      case 'Health':
        return Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: healthColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(lead.health.label,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        );
      case 'Product':
        return Text(lead.interestedInProduct.label,
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis);
      case 'Rating':
        return Text('${lead.rating}',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: stageColor));
      case 'Activity':
        return Text(lead.activityState.label,
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis);
      case 'Payment':
        return Text(lead.paymentStatus.label,
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis);
      case 'City':
        return Text(lead.clientCity,
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis);
      case 'Created':
        return Text(dateFormat.format(lead.createdAt),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600));
      default:
        return const SizedBox();
    }
  }

  // Show unique column settings dialog with drag-to-reorder and show/hide toggles
  void _showColumnSettingsDialog() {
    // Create local copies for the dialog
    List<String> tempColumns = List.from(_tableColumns);
    Set<String> tempHidden = Set.from(_hiddenColumns);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade600, Colors.blue.shade400],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.view_column, color: Colors.white),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Customize Columns',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Drag to reorder • Toggle to show/hide',
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  // Column list
                  Flexible(
                    child: ReorderableListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: tempColumns.length,
                      onReorder: (oldIndex, newIndex) {
                        setDialogState(() {
                          if (newIndex > oldIndex) newIndex--;
                          final item = tempColumns.removeAt(oldIndex);
                          tempColumns.insert(newIndex, item);
                        });
                      },
                      itemBuilder: (context, index) {
                        final col = tempColumns[index];
                        final isHidden = tempHidden.contains(col);
                        final colIcon = _getColumnIcon(col);

                        return Material(
                          key: ValueKey(col),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: isHidden ? Colors.grey.shade100 : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isHidden ? Colors.grey.shade300 : Colors.blue.shade200,
                                width: 1.5,
                              ),
                              boxShadow: isHidden
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: Colors.blue.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                            ),
                            child: ListTile(
                              leading: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      child: Icon(
                                        Icons.drag_indicator,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: isHidden
                                          ? Colors.grey.shade200
                                          : Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      colIcon,
                                      size: 18,
                                      color: isHidden ? Colors.grey : Colors.blue.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              title: Text(
                                col,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isHidden ? Colors.grey : Colors.black87,
                                  decoration: isHidden ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              subtitle: Text(
                                isHidden ? 'Hidden' : 'Visible',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isHidden ? Colors.grey : Colors.green.shade600,
                                ),
                              ),
                              trailing: Switch(
                                value: !isHidden,
                                onChanged: (val) {
                                  setDialogState(() {
                                    if (val) {
                                      tempHidden.remove(col);
                                    } else {
                                      tempHidden.add(col);
                                    }
                                  });
                                },
                                activeColor: Colors.green,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Footer with actions
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            setDialogState(() {
                              tempColumns = List.from(_defaultColumns);
                              tempHidden.clear();
                            });
                          },
                          icon: const Icon(Icons.restart_alt, size: 18),
                          label: const Text('Reset'),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () {
                            setState(() {
                              _tableColumns = tempColumns;
                              _hiddenColumns = tempHidden;
                            });
                            Navigator.pop(ctx);
                          },
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Apply'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Get icon for each column type
  IconData _getColumnIcon(String col) {
    switch (col) {
      case 'Name':
        return Icons.person;
      case 'Business':
        return Icons.business;
      case 'Stage':
        return Icons.trending_up;
      case 'Health':
        return Icons.favorite;
      case 'Product':
        return Icons.shopping_bag;
      case 'Rating':
        return Icons.star;
      case 'Activity':
        return Icons.schedule;
      case 'Payment':
        return Icons.payment;
      case 'City':
        return Icons.location_city;
      case 'Created':
        return Icons.calendar_today;
      default:
        return Icons.text_fields;
    }
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
              // Lead cards list with scrollbar - improved for mobile
              Flexible(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Calculate max height based on screen - more generous on mobile
                    final screenHeight = MediaQuery.of(context).size.height;
                    final isMobile = MediaQuery.of(context).size.width < 600;
                    final maxHeight = isMobile
                        ? screenHeight * 0.6  // 60% of screen on mobile
                        : screenHeight - 250;

                    return ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: maxHeight,
                        minHeight: 100,
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
                        : Scrollbar(
                            thumbVisibility: true,
                            child: ListView.builder(
                              shrinkWrap: false, // Allow expansion on mobile
                              physics: const BouncingScrollPhysics(), // Better mobile feel
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 8),
                              itemCount: stageLeads.length,
                              itemBuilder: (context, index) {
                                return _buildLeadCard(stageLeads[index], color);
                              },
                            ),
                          ),
                    );
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
