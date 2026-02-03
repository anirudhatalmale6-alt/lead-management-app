import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class AppShell extends StatefulWidget {
  final AppUser user;
  final VoidCallback onLogout;
  final List<Widget> screens;
  final bool isAdmin;
  final VoidCallback? onRefresh;

  const AppShell({
    super.key,
    required this.user,
    required this.onLogout,
    required this.screens,
    this.isAdmin = false,
    this.onRefresh,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadSavedIndex();
  }

  Future<void> _loadSavedIndex() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIndex = prefs.getInt('selectedNavIndex') ?? 0;
      if (savedIndex >= 0 && savedIndex < widget.screens.length) {
        setState(() => _selectedIndex = savedIndex);
      }
    } catch (e) {
      debugPrint('Error loading nav index: $e');
    }
  }

  Future<void> _saveAndSetIndex(int index) async {
    setState(() => _selectedIndex = index);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('selectedNavIndex', index);
    } catch (e) {
      debugPrint('Error saving nav index: $e');
    }
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing || widget.onRefresh == null) return;
    setState(() => _isRefreshing = true);
    widget.onRefresh!();
    // Brief delay for visual feedback
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  List<NavigationDestination> get _destinations {
    final items = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard),
        label: 'Dashboard',
      ),
      const NavigationDestination(
        icon: Icon(Icons.view_kanban_outlined),
        selectedIcon: Icon(Icons.view_kanban),
        label: 'Pipeline',
      ),
      const NavigationDestination(
        icon: Icon(Icons.calendar_month_outlined),
        selectedIcon: Icon(Icons.calendar_month),
        label: 'Calendar',
      ),
    ];
    // Admin tab is visible to all users (view-only for non-admin)
    items.add(const NavigationDestination(
      icon: Icon(Icons.admin_panel_settings_outlined),
      selectedIcon: Icon(Icons.admin_panel_settings),
      label: 'Admin',
    ));
    if (widget.isAdmin) {
      items.addAll([
        const NavigationDestination(
          icon: Icon(Icons.email_outlined),
          selectedIcon: Icon(Icons.email),
          label: 'Email',
        ),
        const NavigationDestination(
          icon: Icon(Icons.event_note_outlined),
          selectedIcon: Icon(Icons.event_note),
          label: 'Cal Setup',
        ),
      ]);
    }
    return items;
  }

  /// Scrollable bottom navigation for mobile when many items
  Widget _buildScrollableBottomNav(ColorScheme cs) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: _destinations.asMap().entries.map((entry) {
            final index = entry.key;
            final dest = entry.value;
            final isSelected = _selectedIndex == index;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: () => _saveAndSetIndex(index),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 64,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? cs.primaryContainer : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      isSelected ? (dest.selectedIcon ?? dest.icon) : dest.icon,
                      const SizedBox(height: 2),
                      Text(
                        dest.label,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  List<NavigationRailDestination> get _railDestinations {
    final items = [
      const NavigationRailDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard),
        label: Text('Dashboard'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.view_kanban_outlined),
        selectedIcon: Icon(Icons.view_kanban),
        label: Text('Pipeline'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.calendar_month_outlined),
        selectedIcon: Icon(Icons.calendar_month),
        label: Text('Calendar'),
      ),
    ];
    // Admin tab is visible to all users (view-only for non-admin)
    items.add(const NavigationRailDestination(
      icon: Icon(Icons.admin_panel_settings_outlined),
      selectedIcon: Icon(Icons.admin_panel_settings),
      label: Text('Admin'),
    ));
    if (widget.isAdmin) {
      items.addAll([
        const NavigationRailDestination(
          icon: Icon(Icons.email_outlined),
          selectedIcon: Icon(Icons.email),
          label: Text('Email'),
        ),
        const NavigationRailDestination(
          icon: Icon(Icons.event_note_outlined),
          selectedIcon: Icon(Icons.event_note),
          label: Text('Cal Setup'),
        ),
      ]);
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 800;

        if (isWide) {
          return Scaffold(
            body: Row(
              children: [
                // Wrap NavigationRail in a scrollable column for small screen heights
                SizedBox(
                  width: 80,
                  child: Column(
                    children: [
                      // User info header
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: cs.primaryContainer,
                              child: Text(
                                widget.user.name[0].toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: cs.onPrimaryContainer,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.user.name,
                              style: Theme.of(context).textTheme.labelSmall,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              widget.user.role.label,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: cs.outline,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // Scrollable navigation destinations
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: _railDestinations.asMap().entries.map((entry) {
                              final index = entry.key;
                              final dest = entry.value;
                              final isSelected = _selectedIndex == index;
                              return InkWell(
                                onTap: () => _saveAndSetIndex(index),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  color: isSelected ? cs.primaryContainer.withOpacity(0.3) : null,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      isSelected ? (dest.selectedIcon ?? dest.icon) : dest.icon,
                                      const SizedBox(height: 4),
                                      DefaultTextStyle(
                                        style: Theme.of(context).textTheme.labelSmall!.copyWith(
                                          color: isSelected ? cs.primary : cs.onSurfaceVariant,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        ),
                                        child: dest.label,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      // Bottom actions
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16, top: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.onRefresh != null)
                              IconButton(
                                onPressed: _isRefreshing ? null : _handleRefresh,
                                icon: _isRefreshing
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.refresh),
                                tooltip: 'Refresh Data',
                              ),
                            const SizedBox(height: 8),
                            IconButton(
                              onPressed: widget.onLogout,
                              icon: const Icon(Icons.logout),
                              tooltip: 'Logout',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: widget.screens[_selectedIndex]),
              ],
            ),
          );
        }

        // For mobile with many nav items, use a scrollable bottom nav
        final navItemCount = _destinations.length;
        final useScrollableNav = navItemCount > 5;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Lead Manager'),
            actions: [
              if (widget.onRefresh != null)
                IconButton(
                  onPressed: _isRefreshing ? null : _handleRefresh,
                  icon: _isRefreshing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  tooltip: 'Refresh Data',
                ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.user.role.label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: cs.outline,
                          ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: cs.primaryContainer,
                      child: Text(
                        widget.user.name[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: widget.onLogout,
                      icon: const Icon(Icons.logout, size: 20),
                      tooltip: 'Logout',
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: widget.screens[_selectedIndex],
          bottomNavigationBar: useScrollableNav
              ? _buildScrollableBottomNav(cs)
              : NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _saveAndSetIndex,
                  destinations: _destinations,
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                ),
        );
      },
    );
  }
}
