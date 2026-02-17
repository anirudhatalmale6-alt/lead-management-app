import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/lead.dart';
import 'models/user.dart';
import 'theme/app_theme.dart';
import 'screens/auth_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/pipeline_screen.dart';
import 'screens/lead_form_screen.dart';
import 'screens/lead_detail_screen.dart';
import 'screens/user_management_screen.dart';
import 'screens/team_management_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/email_settings_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/calendar_settings_screen.dart';
import 'widgets/app_shell.dart';
import 'services/firebase_options.dart';
import 'services/auth_service.dart';
import 'services/lead_service.dart';
import 'services/user_service.dart';
import 'services/firestore_service.dart';
import 'data/mock_data.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Catch any Flutter errors
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter error: ${details.exception}');
  };

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase initialized successfully');
  } catch (e) {
    // Firebase initialization failed - app will still run but with limited functionality
    debugPrint('Firebase init error: $e');
  }
  runApp(const LeadManagementApp());
}

class LeadManagementApp extends StatelessWidget {
  const LeadManagementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lead Management System',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const AppRoot(),
    );
  }
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  final AuthService _authService = AuthService();
  final LeadService _leadService = LeadService();

  AppUser? _currentUser;
  List<Lead> _leads = [];
  bool _isLoadingLeads = true;
  bool _isCheckingAuth = true;

  @override
  void initState() {
    super.initState();
    _checkExistingAuth();
  }

  Future<void> _checkExistingAuth() async {
    try {
      // Check if user is already logged in
      final existingUser = await _authService.getCurrentAppUser();
      if (existingUser != null && mounted) {
        setState(() {
          _currentUser = existingUser;
          _isCheckingAuth = false;
        });
        _loadLeads();
        return;
      }
    } catch (e) {
      debugPrint('Error checking auth: $e');
    }
    if (mounted) {
      setState(() => _isCheckingAuth = false);
    }
  }

  void _login(AppUser user) async {
    // Reset navigation to Dashboard on login
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('selectedNavIndex', 0);
    } catch (e) {
      debugPrint('Error resetting nav index: $e');
    }
    setState(() => _currentUser = user);
    _loadLeads();
  }

  Future<void> _logout() async {
    await _authService.signOut();
    setState(() {
      _currentUser = null;
      _leads = [];
    });
  }

  Future<void> _loadLeads() async {
    setState(() => _isLoadingLeads = true);
    try {
      List<Lead> leads;
      final user = _currentUser!;
      switch (user.role) {
        case UserRole.superAdmin:
        case UserRole.admin:
          // Super Admin and Admin have global view — see all leads
          leads = await _leadService.getAllLeads();
          break;
        case UserRole.manager:
        case UserRole.teamLead:
          // Manager, TL see their team's leads + leads where they're follower/assigned
          if (user.teamId != null && user.teamId!.isNotEmpty) {
            final teamLeads = await _leadService.getLeadsByTeam(user.teamId!);
            final userLeads = await _leadService.getLeadsForUser(user.email, ownerUid: user.uid);
            // Merge without duplicates
            final seen = <String>{};
            leads = [];
            for (final l in [...teamLeads, ...userLeads]) {
              if (seen.add(l.id)) leads.add(l);
            }
          } else {
            // No team assigned — fall back to own leads
            leads = await _leadService.getLeadsForUser(user.email, ownerUid: user.uid);
          }
          break;
        case UserRole.coordinator:
          // Coordinator sees own leads + leads from members in their group
          if (user.groupId != null && user.groupId!.isNotEmpty) {
            final groupLeads = await _leadService.getLeadsByGroup(user.groupId!);
            final userLeads = await _leadService.getLeadsForUser(user.email, ownerUid: user.uid);
            // Merge without duplicates
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
          // Member sees only their own leads (created by, assigned to, or follower)
          leads = await _leadService.getLeadsForUser(user.email, ownerUid: user.uid);
          break;
      }
      if (mounted) {
        setState(() {
          _leads = leads;
          _isLoadingLeads = false;
        });
      }
    } catch (e) {
      if (mounted) {
        // Firestore permission error — use mock data as fallback
        final mockLeads = generateMockLeads();
        setState(() {
          _leads = mockLeads;
          _isLoadingLeads = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Using demo data — Firestore rules need to be configured.'),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String get _currentUserIdentifier {
    if (_currentUser == null) return '';
    return _currentUser!.email.isNotEmpty
        ? _currentUser!.email
        : _currentUser!.uid;
  }

  Future<void> _changeLeadStage(Lead lead, LeadStage newStage) async {
    final oldStage = lead.stage;
    setState(() {
      lead.stage = newStage;
      lead.updatedAt = DateTime.now();
    });
    try {
      await _leadService.updateLeadStage(lead.id, newStage.name,
          updatedBy: _currentUserIdentifier);
    } catch (e) {
      if (mounted) {
        setState(() {
          lead.stage = oldStage;
        });
      }
    }
  }

  void _openLeadDetail(Lead lead) {
    final canEdit = _canEditLead(lead);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LeadDetailScreen(
          lead: lead,
          currentUser: _currentUser,
          onEditPressed: canEdit
              ? () {
                  Navigator.of(context).pop();
                  _openLeadForm(lead: lead);
                }
              : null,
        ),
      ),
    );
  }

  void _openLeadForm({Lead? lead}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LeadFormScreen(
          existingLead: lead,
          currentUser: _currentUser,
          onSave: (savedLead) async {
            Navigator.of(context).pop();
            if (lead == null) {
              try {
                savedLead.ownerUid = _currentUser?.uid ?? '';
                savedLead.teamId = _currentUser?.teamId ?? '';
                savedLead.groupId = _currentUser?.groupId ?? '';
                savedLead.createdBy = _currentUserIdentifier;
                savedLead.submitterRole = _currentUser?.role.label ?? '';
                // Auto-assign to self
                savedLead.assignedTo = _currentUser!.email;
                // Auto-populate team/group names if form didn't fill them
                try {
                  final allUsers = await UserService().getAllUsers();
                  final firestoreService = FirestoreService();
                  final creatorTeamId = _currentUser?.teamId ?? '';
                  final creatorGroupId = _currentUser?.groupId ?? '';
                  // Fill team/group names from Firestore if still empty
                  if (savedLead.groupName.isEmpty && creatorTeamId.isNotEmpty) {
                    final teams = await firestoreService.getTeams();
                    final team = teams.where((t) => t['id'] == creatorTeamId).firstOrNull;
                    if (team != null) savedLead.groupName = team['name'] ?? '';
                  }
                  if (savedLead.subGroup.isEmpty && creatorGroupId.isNotEmpty) {
                    final groups = await firestoreService.getGroups();
                    final group = groups.where((g) => g['id'] == creatorGroupId).firstOrNull;
                    if (group != null) savedLead.subGroup = group['name'] ?? '';
                  }
                  // Auto-populate followers with TL, Manager, Coordinator from same team
                  final teamFollowers = <String>[];
                  if (creatorTeamId.isNotEmpty) {
                    for (final u in allUsers) {
                      if (u.teamId == creatorTeamId &&
                          u.email != _currentUser!.email &&
                          (u.role == UserRole.teamLead ||
                           u.role == UserRole.manager ||
                           u.role == UserRole.coordinator)) {
                        teamFollowers.add(u.email);
                      }
                    }
                  }
                  savedLead.followers = teamFollowers;
                } catch (_) {
                  // Non-critical: can be updated manually later
                }
                await _leadService.createLead(savedLead);
                _loadLeads();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error creating lead: $e')),
                  );
                }
              }
            } else {
              try {
                await _leadService.updateLead(
                  lead.id,
                  savedLead.toFirestore(),
                  updatedBy: _currentUserIdentifier,
                );
                _loadLeads();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating lead: $e')),
                  );
                }
              }
            }
          },
        ),
      ),
    );
  }

  bool get _isAdmin {
    if (_currentUser == null) return false;
    return _currentUser!.role == UserRole.superAdmin ||
        _currentUser!.role == UserRole.admin;
  }

  /// Whether current user can see Admin-level nav items (Email Settings, Cal Settings)
  bool get _isAdminOrAbove => _isAdmin;

  bool _canEditLead(Lead lead) {
    if (_currentUser == null) return false;
    final role = _currentUser!.role;
    // Admins & managers can edit any lead
    if (role == UserRole.superAdmin ||
        role == UserRole.admin ||
        role == UserRole.manager) {
      return true;
    }
    // Team leads & coordinators can edit leads within their team
    if (role == UserRole.teamLead || role == UserRole.coordinator) {
      return lead.teamId == _currentUser!.teamId ||
          lead.ownerUid == _currentUser!.uid;
    }
    // Members can only edit their own leads
    return lead.ownerUid == _currentUser!.uid;
  }

  void _refreshAllData() {
    _loadLeads();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while checking existing auth
    if (_isCheckingAuth) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Loading...',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    if (_currentUser == null) {
      return AuthScreen(onLogin: _login);
    }

    if (_isLoadingLeads) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Loading leads...',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    final screens = <Widget>[
      DashboardScreen(leads: _leads, currentUser: _currentUser),
      PipelineScreen(
        leads: _leads,
        onStageChanged: _changeLeadStage,
        onAddLead: () => _openLeadForm(),
        onEditLead: (lead) => _openLeadDetail(lead),
        canEditLead: _canEditLead,
      ),
    ];

    // Calendar screen (available to all users)
    screens.add(CalendarScreen(currentUser: _currentUser!));

    // Admin screen visible to ALL roles (with restricted access for non-admins)
    screens.add(AdminScreen(currentUser: _currentUser!));

    // Email & Calendar Settings only visible to Admin and SuperAdmin
    if (_isAdminOrAbove) {
      screens.addAll([
        const EmailSettingsScreen(),
        CalendarSettingsScreen(currentUser: _currentUser!),
      ]);
    }

    return AppShell(
      user: _currentUser!,
      onLogout: _logout,
      isAdmin: _isAdminOrAbove,
      screens: screens,
      onRefresh: _refreshAllData,
    );
  }
}
