import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
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
import 'widgets/app_shell.dart';
import 'services/firebase_options.dart';
import 'services/auth_service.dart';
import 'services/lead_service.dart';
import 'data/mock_data.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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

  void _login(AppUser user) {
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
        case UserRole.manager:
          // Full access — see all leads
          leads = await _leadService.getAllLeads();
          break;
        case UserRole.teamLead:
        case UserRole.coordinator:
          // Team-scoped — see leads belonging to their team
          if (user.teamId != null && user.teamId!.isNotEmpty) {
            leads = await _leadService.getLeadsByTeam(user.teamId!);
          } else {
            // No team assigned — fall back to own leads
            leads = await _leadService.getLeadsByOwner(user.uid);
          }
          break;
        case UserRole.member:
          // Own leads only
          leads = await _leadService.getLeadsByOwner(user.uid);
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

  @override
  Widget build(BuildContext context) {
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
      DashboardScreen(leads: _leads),
      PipelineScreen(
        leads: _leads,
        onStageChanged: _changeLeadStage,
        onAddLead: () => _openLeadForm(),
        onEditLead: (lead) => _openLeadDetail(lead),
        canEditLead: _canEditLead,
      ),
    ];

    if (_isAdmin) {
      screens.addAll([
        const UserManagementScreen(),
        const TeamManagementScreen(),
      ]);
    }

    return AppShell(
      user: _currentUser!,
      onLogout: _logout,
      isAdmin: _isAdmin,
      screens: screens,
    );
  }
}
