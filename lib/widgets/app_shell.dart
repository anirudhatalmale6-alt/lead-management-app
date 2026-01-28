import 'package:flutter/material.dart';
import 'dart:html' as html;
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

  void _loadSavedIndex() {
    try {
      final savedIndex = html.window.localStorage['selectedNavIndex'];
      if (savedIndex != null) {
        final index = int.tryParse(savedIndex) ?? 0;
        if (index >= 0 && index < widget.screens.length) {
          setState(() => _selectedIndex = index);
        }
      }
    } catch (e) {
      debugPrint('Error loading nav index: $e');
    }
  }

  void _saveAndSetIndex(int index) {
    setState(() => _selectedIndex = index);
    try {
      html.window.localStorage['selectedNavIndex'] = index.toString();
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
    final items = [
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
    if (widget.isAdmin) {
      items.addAll([
        const NavigationDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: 'Users',
        ),
        const NavigationDestination(
          icon: Icon(Icons.groups_outlined),
          selectedIcon: Icon(Icons.groups),
          label: 'Teams',
        ),
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
    if (widget.isAdmin) {
      items.addAll([
        const NavigationRailDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: Text('Users'),
        ),
        const NavigationRailDestination(
          icon: Icon(Icons.groups_outlined),
          selectedIcon: Icon(Icons.groups),
          label: Text('Teams'),
        ),
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
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _saveAndSetIndex,
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
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
                  trailing: Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
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
                    ),
                  ),
                  destinations: _railDestinations,
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: widget.screens[_selectedIndex]),
              ],
            ),
          );
        }

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
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _saveAndSetIndex,
            destinations: _destinations,
          ),
        );
      },
    );
  }
}
