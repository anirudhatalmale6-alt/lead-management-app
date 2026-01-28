import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/lead.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  final List<Lead> leads;
  const DashboardScreen({super.key, required this.leads});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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
      results = results
          .where((l) => l.interestedInProduct == _filterProduct)
          .toList();
    }
    if (_filterRating != null) {
      results = results.where((l) => l.rating == _filterRating).toList();
    }
    if (_filterDateFrom != null) {
      final from = DateTime(
          _filterDateFrom!.year, _filterDateFrom!.month, _filterDateFrom!.day);
      results = results.where((l) => !l.createdAt.isBefore(from)).toList();
    }
    if (_filterDateTo != null) {
      final to = DateTime(_filterDateTo!.year, _filterDateTo!.month,
          _filterDateTo!.day, 23, 59, 59);
      results = results.where((l) => !l.createdAt.isAfter(to)).toList();
    }
    if (_filterHasFollowUp) {
      results = results.where((l) => l.nextFollowUpDate != null).toList();
    }
    if (_filterHasMeeting) {
      results = results.where((l) => l.meetingDate != null).toList();
    }

    return results;
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

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  // ---------------------------------------------------------------------------
  // Computed data — Summary
  // ---------------------------------------------------------------------------

  List<Lead> get leads => _filteredLeads;

  int get _totalLeads => leads.length;

  int get _newLeadsToday => leads
      .where((l) => l.stage == LeadStage.newLead && _isToday(l.createdAt))
      .length;

  int get _followUpDueToday => leads
      .where((l) =>
          l.activityState == ActivityState.followUpDue &&
          l.nextFollowUpDate != null &&
          _isToday(l.nextFollowUpDate!))
      .length;

  int get _totalWon => leads.where((l) => l.stage == LeadStage.won).length;

  int get _totalLost => leads.where((l) => l.stage == LeadStage.lost).length;

  int get _totalPaid =>
      leads.where((l) => l.paymentStatus == PaymentStatus.fullyPaid).length;

  // ---------------------------------------------------------------------------
  // Computed data — Breakdowns
  // ---------------------------------------------------------------------------

  Map<LeadHealth, int> get _healthCounts {
    final map = <LeadHealth, int>{};
    for (final h in LeadHealth.values) {
      map[h] = leads.where((l) => l.health == h).length;
    }
    return map;
  }

  Map<LeadStage, int> get _stageCounts {
    final map = <LeadStage, int>{};
    for (final s in LeadStage.values) {
      map[s] = leads.where((l) => l.stage == s).length;
    }
    return map;
  }

  Map<ActivityState, int> get _activityCounts {
    final map = <ActivityState, int>{};
    for (final a in ActivityState.values) {
      map[a] = leads.where((l) => l.activityState == a).length;
    }
    return map;
  }

  Map<PaymentStatus, int> get _paymentCounts {
    final map = <PaymentStatus, int>{};
    for (final p in PaymentStatus.values) {
      map[p] = leads.where((l) => l.paymentStatus == p).length;
    }
    return map;
  }

  Map<ProductService, int> get _productCounts {
    final map = <ProductService, int>{};
    for (final p in ProductService.values) {
      map[p] = leads.where((l) => l.interestedInProduct == p).length;
    }
    return map;
  }

  Map<int, int> get _ratingCounts {
    final map = <int, int>{};
    for (final r in [10, 20, 30, 40, 50, 60, 70, 80, 90]) {
      map[r] = leads.where((l) => l.rating == r).length;
    }
    return map;
  }

  // ---------------------------------------------------------------------------
  // Color helpers
  // ---------------------------------------------------------------------------

  Color _healthColor(LeadHealth h) {
    switch (h) {
      case LeadHealth.hot:
        return Colors.red;
      case LeadHealth.warm:
        return Colors.orange;
      case LeadHealth.solo:
        return Colors.blue;
      case LeadHealth.sleeping:
        return Colors.purple;
      case LeadHealth.dead:
        return Colors.grey;
      case LeadHealth.junk:
        return Colors.brown;
    }
  }

  Color _stageColor(LeadStage s) {
    switch (s) {
      case LeadStage.newLead:
        return Colors.blue;
      case LeadStage.contacted:
        return Colors.cyan.shade700;
      case LeadStage.demoScheduled:
        return Colors.teal;
      case LeadStage.demoCompleted:
        return Colors.indigo;
      case LeadStage.proposalSent:
        return Colors.purple;
      case LeadStage.negotiation:
        return Colors.amber.shade800;
      case LeadStage.won:
        return Colors.green;
      case LeadStage.lost:
        return Colors.grey.shade600;
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final filteredCount = _filteredLeads.length;
    final totalCount = widget.leads.length;

    return Column(
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
        // Dashboard content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryCards(context),
                const SizedBox(height: 24),
                _buildChartsRow(context),
                const SizedBox(height: 24),
                _buildSectionTitle('Activity State Breakdown'),
                const SizedBox(height: 8),
                _buildActivityStateCards(),
                const SizedBox(height: 24),
                _buildSectionTitle('Payment Status Breakdown'),
                const SizedBox(height: 8),
                _buildPaymentStatusCards(),
                const SizedBox(height: 24),
                _buildProductServiceCard(context),
                const SizedBox(height: 24),
                _buildSectionTitle('Rating Distribution'),
                const SizedBox(height: 8),
                _buildRatingCards(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Filter Panel
  // ---------------------------------------------------------------------------

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
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
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
                          child: Icon(Icons.close,
                              size: 14, color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
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
                          child: Icon(Icons.close,
                              size: 14, color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
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
                    child:
                        const Text('Has Meeting', style: TextStyle(fontSize: 13)),
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

  // ---------------------------------------------------------------------------
  // Section 1 — Summary Cards
  // ---------------------------------------------------------------------------

  Widget _buildSummaryCards(BuildContext context) {
    final cards = <_SummaryCardData>[
      _SummaryCardData(
        icon: Icons.people,
        color: Colors.indigo,
        value: '$_totalLeads',
        label: 'Total Leads',
      ),
      _SummaryCardData(
        icon: Icons.fiber_new,
        color: Colors.blue,
        value: '$_newLeadsToday',
        label: 'New Leads Today',
      ),
      _SummaryCardData(
        icon: Icons.notification_important,
        color: Colors.orange,
        value: '$_followUpDueToday',
        label: 'Follow-up Due Today',
      ),
      _SummaryCardData(
        icon: Icons.emoji_events,
        color: Colors.green,
        value: '$_totalWon',
        label: 'Total Won',
      ),
      _SummaryCardData(
        icon: Icons.cancel,
        color: Colors.red.shade400,
        value: '$_totalLost',
        label: 'Total Lost',
      ),
      _SummaryCardData(
        icon: Icons.payments,
        color: Colors.teal,
        value: '$_totalPaid',
        label: 'Total Paid',
      ),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children:
          cards.map((data) => _buildSummaryCard(context, data)).toList(),
    );
  }

  Widget _buildSummaryCard(BuildContext context, _SummaryCardData data) {
    return SizedBox(
      width: 170,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: data.color, width: 4),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(data.icon, color: data.color, size: 28),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  data.value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                data.label,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sections 2 & 3 — Charts Row
  // ---------------------------------------------------------------------------

  Widget _buildChartsRow(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 800;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildHealthPieChart(context)),
              const SizedBox(width: 16),
              Expanded(child: _buildStageBarChart(context)),
            ],
          );
        } else {
          return Column(
            children: [
              _buildHealthPieChart(context),
              const SizedBox(height: 16),
              _buildStageBarChart(context),
            ],
          );
        }
      },
    );
  }

  Widget _buildHealthPieChart(BuildContext context) {
    final data = _healthCounts;
    final total = _totalLeads;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lead Health Breakdown',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 240,
              child: total == 0
                  ? const Center(child: Text('No data'))
                  : PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: data.entries
                            .where((e) => e.value > 0)
                            .map((entry) {
                          final percentage =
                              (entry.value / total * 100).toStringAsFixed(1);
                          return PieChartSectionData(
                            color: _healthColor(entry.key),
                            value: entry.value.toDouble(),
                            title: '$percentage%',
                            radius: 60,
                            titleStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: data.entries.map((entry) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _healthColor(entry.key),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${entry.key.label} (${entry.value})',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStageBarChart(BuildContext context) {
    final data = _stageCounts;
    final maxCount = data.values.fold(0, (a, b) => a > b ? a : b);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sales Stage Breakdown',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 240,
              child: _totalLeads == 0
                  ? const Center(child: Text('No data'))
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: (maxCount + 1).toDouble(),
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipItem:
                                (group, groupIndex, rod, rodIndex) {
                              final stage =
                                  LeadStage.values[group.x.toInt()];
                              return BarTooltipItem(
                                '${stage.label}\n${rod.toY.round()}',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                if (value == value.roundToDouble() &&
                                    value >= 0) {
                                  return Text(
                                    '${value.toInt()}',
                                    style: const TextStyle(fontSize: 11),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 52,
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx < 0 ||
                                    idx >= LeadStage.values.length) {
                                  return const SizedBox.shrink();
                                }
                                final label = LeadStage.values[idx].label;
                                final short = label.length > 8
                                    ? '${label.substring(0, 7)}.'
                                    : label;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Transform.rotate(
                                    angle: -0.5,
                                    child: Text(
                                      short,
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 1,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: Colors.grey.shade200,
                            strokeWidth: 1,
                          ),
                        ),
                        barGroups: List.generate(
                          LeadStage.values.length,
                          (index) {
                            final count =
                                data[LeadStage.values[index]] ?? 0;
                            return BarChartGroupData(
                              x: index,
                              barRods: [
                                BarChartRodData(
                                  toY: count.toDouble(),
                                  color:
                                      _stageColor(LeadStage.values[index]),
                                  width: 18,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(4),
                                    topRight: Radius.circular(4),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section 4 — Activity State Breakdown
  // ---------------------------------------------------------------------------

  Widget _buildActivityStateCards() {
    final data = _activityCounts;
    final colors = <ActivityState, Color>{
      ActivityState.idle: Colors.blueGrey,
      ActivityState.working: Colors.blue,
      ActivityState.followUpDue: Colors.orange,
      ActivityState.reOpened: Colors.purple,
      ActivityState.closed: Colors.grey,
    };

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: data.entries.map((entry) {
        return _buildCountChip(
          label: entry.key.label,
          count: entry.value,
          color: colors[entry.key] ?? Colors.blueGrey,
        );
      }).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Section 5 — Payment Status Breakdown
  // ---------------------------------------------------------------------------

  Widget _buildPaymentStatusCards() {
    final data = _paymentCounts;
    final colors = <PaymentStatus, Color>{
      PaymentStatus.free: Colors.grey,
      PaymentStatus.supported: Colors.blue,
      PaymentStatus.pending: Colors.orange,
      PaymentStatus.partiallyPaid: Colors.amber.shade800,
      PaymentStatus.fullyPaid: Colors.green,
    };

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: data.entries.map((entry) {
        return _buildCountChip(
          label: entry.key.label,
          count: entry.value,
          color: colors[entry.key] ?? Colors.blueGrey,
        );
      }).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Section 6 — Product/Service Breakdown
  // ---------------------------------------------------------------------------

  Widget _buildProductServiceCard(BuildContext context) {
    final data = _productCounts;
    final maxCount = data.values.fold(0, (a, b) => a > b ? a : b);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Interested In Product/Service',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_totalLeads == 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No data')),
              )
            else
              ...data.entries.map((entry) {
                final fraction =
                    maxCount > 0 ? entry.value / maxCount : 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 180,
                        child: Text(
                          entry.key.label,
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: fraction,
                            minHeight: 18,
                            backgroundColor: Colors.grey.shade200,
                            valueColor:
                                const AlwaysStoppedAnimation<Color>(
                                    Colors.indigo),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 32,
                        child: Text(
                          '${entry.value}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.right,
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

  // ---------------------------------------------------------------------------
  // Section 7 — Rating Distribution
  // ---------------------------------------------------------------------------

  Widget _buildRatingCards() {
    final data = _ratingCounts;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: data.entries.map((entry) {
        return _buildCountChip(
          label: '${entry.key}',
          count: entry.value,
          color: _ratingColor(entry.key),
        );
      }).toList(),
    );
  }

  Color _ratingColor(int rating) {
    if (rating >= 70) return Colors.green;
    if (rating >= 40) return Colors.orange;
    return Colors.red.shade400;
  }

  // ---------------------------------------------------------------------------
  // Reusable widgets
  // ---------------------------------------------------------------------------

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildCountChip({
    required String label,
    required int count,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        constraints: const BoxConstraints(minWidth: 100),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Internal data class for summary cards
// -----------------------------------------------------------------------------

class _SummaryCardData {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _SummaryCardData({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });
}
