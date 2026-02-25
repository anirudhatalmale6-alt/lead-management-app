import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../models/email_template.dart';
import '../models/user.dart';
import '../models/lead.dart';
import '../services/email_service.dart';
import '../services/auth_service.dart';
import '../services/google_calendar_service.dart';
import '../utils/seed_demo_data.dart';

class EmailSettingsScreen extends StatefulWidget {
  const EmailSettingsScreen({super.key});

  @override
  State<EmailSettingsScreen> createState() => _EmailSettingsScreenState();
}

class _EmailSettingsScreenState extends State<EmailSettingsScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  final EmailService _emailService = EmailService();
  final AuthService _authService = AuthService();
  bool _isSuperAdmin = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    final user = await _authService.getCurrentAppUser();
    final isSuperAdmin = user?.role == UserRole.superAdmin;
    setState(() {
      _isSuperAdmin = isSuperAdmin;
      _tabController = TabController(
        length: isSuperAdmin ? 6 : 5,
        vsync: this,
      );
      _loading = false;
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            const Tab(text: 'SMTP', icon: Icon(Icons.settings)),
            const Tab(text: 'Google Calendar', icon: Icon(Icons.calendar_month)),
            const Tab(text: 'Categories', icon: Icon(Icons.category)),
            const Tab(text: 'Templates', icon: Icon(Icons.email)),
            const Tab(text: 'Demo Data', icon: Icon(Icons.science)),
            if (_isSuperAdmin)
              const Tab(text: 'Lead Manager', icon: Icon(Icons.admin_panel_settings)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _SmtpConfigTab(emailService: _emailService),
          const _GoogleCalendarTab(),
          _CategoriesTab(emailService: _emailService),
          _TemplatesTab(emailService: _emailService),
          const _DemoDataTab(),
          if (_isSuperAdmin) const _LeadManagerTab(),
        ],
      ),
    );
  }
}

// ============================================================================
// SMTP Configuration Tab
// ============================================================================

class _SmtpConfigTab extends StatefulWidget {
  final EmailService emailService;
  const _SmtpConfigTab({required this.emailService});

  @override
  State<_SmtpConfigTab> createState() => _SmtpConfigTabState();
}

class _SmtpConfigTabState extends State<_SmtpConfigTab> {
  final _formKey = GlobalKey<FormState>();
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '587');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fromEmailController = TextEditingController();
  final _fromNameController = TextEditingController();
  bool _useTls = true;
  bool _useSsl = false;
  bool _loading = true;
  bool _saving = false;
  bool _obscurePassword = true;
  bool _testing = false;
  String? _testResult;
  bool? _testSuccess;
  bool _processingQueue = false;
  String? _queueResult;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await widget.emailService.getSmtpConfig();
    if (config != null) {
      _hostController.text = config.host;
      _portController.text = config.port.toString();
      _usernameController.text = config.username;
      _passwordController.text = config.password;
      _fromEmailController.text = config.fromEmail;
      _fromNameController.text = config.fromName;
      _useTls = config.useTls;
      _useSsl = config.useSsl;
    }
    setState(() => _loading = false);
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final config = SmtpConfig(
        host: _hostController.text.trim(),
        port: int.tryParse(_portController.text) ?? 587,
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        fromEmail: _fromEmailController.text.trim(),
        fromName: _fromNameController.text.trim(),
        useTls: _useTls,
        useSsl: _useSsl,
      );
      await widget.emailService.saveSmtpConfig(config);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMTP settings saved!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _testing = true;
      _testResult = null;
      _testSuccess = null;
    });

    try {
      final config = SmtpConfig(
        host: _hostController.text.trim(),
        port: int.tryParse(_portController.text) ?? 587,
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        fromEmail: _fromEmailController.text.trim(),
        fromName: _fromNameController.text.trim(),
        useTls: _useTls,
        useSsl: _useSsl,
      );

      final result = await widget.emailService.testSmtpConnection(config);
      if (mounted) {
        setState(() {
          _testResult = result;
          _testSuccess = result.startsWith('Success');
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testResult = 'Error: $e';
          _testSuccess = false;
        });
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _processQueue() async {
    setState(() {
      _processingQueue = true;
      _queueResult = null;
    });

    try {
      final result = await widget.emailService.processPendingEmails();
      if (mounted) {
        setState(() => _queueResult = result);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _queueResult = 'Error processing queue: $e');
      }
    } finally {
      if (mounted) setState(() => _processingQueue = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SMTP Server Configuration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Configure the central email account that will send all emails.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _hostController,
              decoration: const InputDecoration(
                labelText: 'SMTP Host',
                hintText: 'e.g., smtp.gmail.com',
                prefixIcon: Icon(Icons.dns),
              ),
              validator: (v) => v?.isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _portController,
              decoration: const InputDecoration(
                labelText: 'Port',
                hintText: '587 for TLS, 465 for SSL',
                prefixIcon: Icon(Icons.numbers),
              ),
              keyboardType: TextInputType.number,
              validator: (v) => v?.isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username / Email',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (v) => v?.isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password / App Password',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword
                      ? Icons.visibility
                      : Icons.visibility_off),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              obscureText: _obscurePassword,
              validator: (v) => v?.isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: 24),
            const Text(
              'From Address',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _fromEmailController,
              decoration: const InputDecoration(
                labelText: 'From Email',
                prefixIcon: Icon(Icons.email),
              ),
              validator: (v) => v?.isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _fromNameController,
              decoration: const InputDecoration(
                labelText: 'From Name',
                hintText: 'e.g., Xtrazcon Sales',
                prefixIcon: Icon(Icons.badge),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    title: const Text('Use TLS'),
                    value: _useTls,
                    onChanged: (v) => setState(() => _useTls = v ?? true),
                  ),
                ),
                Expanded(
                  child: CheckboxListTile(
                    title: const Text('Use SSL'),
                    value: _useSsl,
                    onChanged: (v) => setState(() => _useSsl = v ?? false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Action buttons row
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _saving ? null : _saveConfig,
                  icon: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_saving ? 'Saving...' : 'Save Settings'),
                ),
                OutlinedButton.icon(
                  onPressed: _testing ? null : _testConnection,
                  icon: _testing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(_testing ? 'Testing...' : 'Test Connection'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange.shade700,
                    side: BorderSide(color: Colors.orange.shade300),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _processingQueue ? null : _processQueue,
                  icon: _processingQueue
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.queue),
                  label: Text(_processingQueue ? 'Processing...' : 'Process Email Queue'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.teal.shade700,
                    side: BorderSide(color: Colors.teal.shade300),
                  ),
                ),
              ],
            ),
            // Test Connection result
            if (_testResult != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _testSuccess == true
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _testSuccess == true
                        ? Colors.green.shade300
                        : Colors.red.shade300,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _testSuccess == true ? Icons.check_circle : Icons.error,
                      color: _testSuccess == true ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _testResult!,
                        style: TextStyle(
                          color: _testSuccess == true
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Queue processing result
            if (_queueResult != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _queueResult!,
                        style: TextStyle(color: Colors.blue.shade800, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            // Help text
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('How it works:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Text('1. Save your SMTP settings (e.g., Gmail App Password)', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  Text('2. Click "Test Connection" to send a test email to yourself', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  Text('3. Emails will be sent automatically when you use email features', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  Text('4. "Process Queue" sends any pending emails that failed earlier', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  const SizedBox(height: 8),
                  Text('For Gmail: Use App Password (Google Account > Security > App Passwords)', style: TextStyle(fontSize: 11, color: Colors.orange.shade700, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Text('Web: Requires Firebase Cloud Functions deployed (firebase deploy --only functions)', style: TextStyle(fontSize: 11, color: Colors.blue.shade700, fontWeight: FontWeight.w500)),
                  Text('Mobile: Sends emails directly via SMTP (no Cloud Functions needed)', style: TextStyle(fontSize: 11, color: Colors.blue.shade700, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Google Calendar Tab
// ============================================================================

class _GoogleCalendarTab extends StatefulWidget {
  const _GoogleCalendarTab();

  @override
  State<_GoogleCalendarTab> createState() => _GoogleCalendarTabState();
}

class _GoogleCalendarTabState extends State<_GoogleCalendarTab> {
  final _formKey = GlobalKey<FormState>();
  final GoogleCalendarService _gcService = GoogleCalendarService();
  final _clientIdController = TextEditingController();
  final _clientSecretController = TextEditingController();
  final _refreshTokenController = TextEditingController();
  final _apiKeyController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  String? _testResult;
  bool? _testSuccess;
  bool _obscureSecret = true;
  bool _obscureToken = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await _gcService.getConfig();
    if (config != null) {
      _clientIdController.text = config.clientId;
      _clientSecretController.text = config.clientSecret;
      _refreshTokenController.text = config.refreshToken;
      _apiKeyController.text = config.apiKey;
    }
    setState(() => _loading = false);
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final config = GoogleCalendarConfig(
        clientId: _clientIdController.text.trim(),
        clientSecret: _clientSecretController.text.trim(),
        refreshToken: _refreshTokenController.text.trim(),
        apiKey: _apiKeyController.text.trim(),
      );
      await _gcService.saveConfig(config);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Calendar settings saved!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _testing = true;
      _testResult = null;
      _testSuccess = null;
    });

    try {
      final config = GoogleCalendarConfig(
        clientId: _clientIdController.text.trim(),
        clientSecret: _clientSecretController.text.trim(),
        refreshToken: _refreshTokenController.text.trim(),
        apiKey: _apiKeyController.text.trim(),
      );

      final result = await _gcService.testConnection(config);
      if (mounted) {
        setState(() {
          _testResult = result;
          _testSuccess = result.startsWith('Success');
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testResult = 'Error: $e';
          _testSuccess = false;
        });
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Google Calendar Integration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Connect Google Calendar to auto-create Google Meet links for meetings.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _clientIdController,
              decoration: const InputDecoration(
                labelText: 'Client ID',
                prefixIcon: Icon(Icons.key),
                hintText: 'Google OAuth Client ID',
              ),
              validator: (v) => v?.isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _clientSecretController,
              decoration: InputDecoration(
                labelText: 'Client Secret',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(_obscureSecret ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureSecret = !_obscureSecret),
                ),
              ),
              obscureText: _obscureSecret,
              validator: (v) => v?.isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _refreshTokenController,
              decoration: InputDecoration(
                labelText: 'Refresh Token',
                prefixIcon: const Icon(Icons.refresh),
                suffixIcon: IconButton(
                  icon: Icon(_obscureToken ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureToken = !_obscureToken),
                ),
              ),
              obscureText: _obscureToken,
              validator: (v) => v?.isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'API Key (optional)',
                prefixIcon: Icon(Icons.vpn_key),
              ),
            ),
            const SizedBox(height: 24),
            // Action buttons
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _saving ? null : _saveConfig,
                  icon: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: Text(_saving ? 'Saving...' : 'Save Settings'),
                ),
                OutlinedButton.icon(
                  onPressed: _testing ? null : _testConnection,
                  icon: _testing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check_circle),
                  label: Text(_testing ? 'Testing...' : 'Test Connection'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green.shade700,
                    side: BorderSide(color: Colors.green.shade300),
                  ),
                ),
              ],
            ),
            // Test result
            if (_testResult != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _testSuccess == true ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _testSuccess == true ? Colors.green.shade300 : Colors.red.shade300,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _testSuccess == true ? Icons.check_circle : Icons.error,
                      color: _testSuccess == true ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _testResult!,
                        style: TextStyle(
                          color: _testSuccess == true ? Colors.green.shade800 : Colors.red.shade800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            // Info card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('How it works:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Text('1. Save your Google Calendar credentials', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  Text('2. When scheduling a meeting, a Google Meet link is auto-created', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  Text('3. The meeting is added to Google Calendar with the Meet link', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  Text('4. You can still enter a manual link to skip auto-creation', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Business Categories Tab
// ============================================================================

class _CategoriesTab extends StatelessWidget {
  final EmailService emailService;
  const _CategoriesTab({required this.emailService});

  void _showAddCategoryDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            hintText: 'e.g., CityFinSol',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await emailService.addCategory(controller.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Business Categories',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              FilledButton.icon(
                onPressed: () => _showAddCategoryDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<BusinessCategory>>(
            stream: emailService.streamCategories(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final categories = snapshot.data!;
              if (categories.isEmpty) {
                return const Center(
                  child: Text('No categories yet. Add one to get started.'),
                );
              }
              return ListView.builder(
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  return ListTile(
                    leading: const Icon(Icons.folder),
                    title: Text(cat.name),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Category?'),
                            content: Text(
                                'Delete "${cat.name}"? Templates in this category will become orphaned.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await emailService.deleteCategory(cat.id);
                        }
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Email Templates Tab
// ============================================================================

class _TemplatesTab extends StatefulWidget {
  final EmailService emailService;
  const _TemplatesTab({required this.emailService});

  @override
  State<_TemplatesTab> createState() => _TemplatesTabState();
}

class _TemplatesTabState extends State<_TemplatesTab> {
  String? _selectedCategoryId;

  void _showTemplateEditor(BuildContext context, EmailTemplate? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _TemplateEditorSheet(
        emailService: widget.emailService,
        existing: existing,
        categoryId: _selectedCategoryId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Category filter
        StreamBuilder<List<BusinessCategory>>(
          stream: widget.emailService.streamCategories(),
          builder: (context, catSnap) {
            final categories = catSnap.data ?? [];
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      value: _selectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: 'Filter by Category',
                        prefixIcon: Icon(Icons.filter_list),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Categories'),
                        ),
                        ...categories.map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            )),
                      ],
                      onChanged: (v) => setState(() => _selectedCategoryId = v),
                    ),
                  ),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: () => _showTemplateEditor(context, null),
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
                ],
              ),
            );
          },
        ),
        // Templates list
        Expanded(
          child: StreamBuilder<List<EmailTemplate>>(
            stream: widget.emailService
                .streamTemplates(categoryId: _selectedCategoryId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final templates = snapshot.data!;
              if (templates.isEmpty) {
                return const Center(
                  child: Text('No templates. Add one to get started.'),
                );
              }
              return ListView.builder(
                itemCount: templates.length,
                itemBuilder: (context, index) {
                  final tpl = templates[index];
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      leading: Icon(_getTemplateIcon(tpl.type)),
                      title: Text(tpl.type.label),
                      subtitle: Text(
                        tpl.subject,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showTemplateEditor(context, tpl),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete Template?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await widget.emailService.deleteTemplate(tpl.id);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  IconData _getTemplateIcon(EmailTemplateType type) {
    switch (type) {
      case EmailTemplateType.followUp:
        return Icons.refresh;
      case EmailTemplateType.offerPlan:
        return Icons.local_offer;
      case EmailTemplateType.demoConfirmation:
        return Icons.event_available;
      case EmailTemplateType.proposal:
        return Icons.description;
      case EmailTemplateType.reminder:
        return Icons.notifications;
      case EmailTemplateType.paymentRequest:
        return Icons.payment;
    }
  }
}

// ============================================================================
// Template Editor Sheet
// ============================================================================

class _TemplateEditorSheet extends StatefulWidget {
  final EmailService emailService;
  final EmailTemplate? existing;
  final String? categoryId;

  const _TemplateEditorSheet({
    required this.emailService,
    this.existing,
    this.categoryId,
  });

  @override
  State<_TemplateEditorSheet> createState() => _TemplateEditorSheetState();
}

class _TemplateEditorSheetState extends State<_TemplateEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late String _categoryId;
  late EmailTemplateType _type;
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.existing?.categoryId ?? widget.categoryId ?? '';
    _type = widget.existing?.type ?? EmailTemplateType.followUp;
    _subjectController.text = widget.existing?.subject ?? '';
    _bodyController.text = widget.existing?.body ?? '';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final template = EmailTemplate(
        id: widget.existing?.id ?? '',
        categoryId: _categoryId,
        type: _type,
        subject: _subjectController.text.trim(),
        body: _bodyController.text.trim(),
      );
      await widget.emailService.saveTemplate(template);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                widget.existing == null ? 'New Template' : 'Edit Template',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              // Category dropdown
              StreamBuilder<List<BusinessCategory>>(
                stream: widget.emailService.streamCategories(),
                builder: (context, snapshot) {
                  final categories = snapshot.data ?? [];
                  return DropdownButtonFormField<String>(
                    value: _categoryId.isEmpty ? null : _categoryId,
                    decoration: const InputDecoration(
                      labelText: 'Business Category',
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: categories
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _categoryId = v ?? ''),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  );
                },
              ),
              const SizedBox(height: 16),
              // Template type dropdown
              DropdownButtonFormField<EmailTemplateType>(
                value: _type,
                decoration: const InputDecoration(
                  labelText: 'Template Type',
                  prefixIcon: Icon(Icons.style),
                ),
                items: EmailTemplateType.values
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.label),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: 'Email Subject',
                  hintText: 'e.g., Demo Confirmation - {{client_name}}',
                  prefixIcon: Icon(Icons.subject),
                ),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bodyController,
                decoration: const InputDecoration(
                  labelText: 'Email Body',
                  hintText: 'Use {{placeholders}} for dynamic content',
                  alignLabelWithHint: true,
                ),
                maxLines: 10,
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              // Placeholder help
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Available Placeholders:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Chip(label: Text('{{client_name}}')),
                          Chip(label: Text('{{business_name}}')),
                          Chip(label: Text('{{client_email}}')),
                          Chip(label: Text('{{meeting_date}}')),
                          Chip(label: Text('{{meeting_time}}')),
                          Chip(label: Text('{{meeting_link}}')),
                          Chip(label: Text('{{product_name}}')),
                          Chip(label: Text('{{next_follow_up}}')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_saving ? 'Saving...' : 'Save Template'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Demo Data Tab - For Testing
// ============================================================================

class _DemoDataTab extends StatefulWidget {
  const _DemoDataTab();

  @override
  State<_DemoDataTab> createState() => _DemoDataTabState();
}

class _DemoDataTabState extends State<_DemoDataTab> {
  bool _seedingLeads = false;
  bool _seedingTemplates = false;
  String _status = '';

  Future<void> _seedDemoLeads() async {
    setState(() {
      _seedingLeads = true;
      _status = 'Creating 100 demo leads with history...';
    });

    try {
      final seeder = DemoDataSeeder();
      await seeder.seedLeads(count: 100, createdBy: 'demo@test.com');
      if (mounted) {
        setState(() {
          _status = '100 demo leads created successfully!';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('100 demo leads created with history logs!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Error: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating leads: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _seedingLeads = false);
      }
    }
  }

  Future<void> _seedEmailTemplates() async {
    setState(() {
      _seedingTemplates = true;
      _status = 'Creating email categories and templates...';
    });

    try {
      final seeder = DemoDataSeeder();
      await seeder.seedEmailTemplates();
      if (mounted) {
        setState(() {
          _status = 'Email templates created successfully!';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email categories and templates created!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Error: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating templates: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _seedingTemplates = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Demo Data for Testing',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Generate sample data to test the application features.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),

          // Demo Leads Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.people, color: Colors.blue),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Demo Leads',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            Text('Create 100 sample leads with history',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'This will create 100 demo leads with:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Chip(
                        label: const Text('Random names'),
                        backgroundColor: Colors.blue.shade50,
                      ),
                      Chip(
                        label: const Text('Random stages'),
                        backgroundColor: Colors.blue.shade50,
                      ),
                      Chip(
                        label: const Text('History logs'),
                        backgroundColor: Colors.blue.shade50,
                      ),
                      Chip(
                        label: const Text('Follow-ups'),
                        backgroundColor: Colors.blue.shade50,
                      ),
                      Chip(
                        label: const Text('Meetings'),
                        backgroundColor: Colors.blue.shade50,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _seedingLeads ? null : _seedDemoLeads,
                      icon: _seedingLeads
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.add),
                      label: Text(
                          _seedingLeads ? 'Creating...' : 'Create 100 Demo Leads'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Email Templates Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.email, color: Colors.purple),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Email Templates',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            Text('Create sample categories & templates',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'This will create categories and templates for:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Chip(
                        label: const Text('CityFinSol Services'),
                        backgroundColor: Colors.purple.shade50,
                      ),
                      Chip(
                        label: const Text('SaaS Products'),
                        backgroundColor: Colors.purple.shade50,
                      ),
                      Chip(
                        label: const Text('Digital Marketing'),
                        backgroundColor: Colors.purple.shade50,
                      ),
                      Chip(
                        label: const Text('Custom Development'),
                        backgroundColor: Colors.purple.shade50,
                      ),
                      Chip(
                        label: const Text('Education'),
                        backgroundColor: Colors.purple.shade50,
                      ),
                      Chip(
                        label: const Text('General Communication'),
                        backgroundColor: Colors.purple.shade50,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _seedingTemplates ? null : _seedEmailTemplates,
                      icon: _seedingTemplates
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.add),
                      label: Text(_seedingTemplates
                          ? 'Creating...'
                          : 'Create Email Templates'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Status message
          if (_status.isNotEmpty)
            Card(
              color: _status.contains('Error')
                  ? Colors.red.shade50
                  : Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      _status.contains('Error')
                          ? Icons.error_outline
                          : Icons.check_circle_outline,
                      color: _status.contains('Error')
                          ? Colors.red
                          : Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _status,
                        style: TextStyle(
                          color: _status.contains('Error')
                              ? Colors.red.shade700
                              : Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 24),
          // Warning
          Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Demo data is for testing only. You can delete it from Firebase console if needed.',
                      style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Lead Manager Tab - Super Admin Only
// ============================================================================

class _LeadManagerTab extends StatefulWidget {
  const _LeadManagerTab();

  @override
  State<_LeadManagerTab> createState() => _LeadManagerTabState();
}

class _LeadManagerTabState extends State<_LeadManagerTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Filter state
  LeadStage? _filterStage;
  LeadHealth? _filterHealth;
  ProductService? _filterProduct;
  DateTime? _filterFromDate;
  DateTime? _filterToDate;
  String _searchQuery = '';

  // Selection state
  final Set<String> _selectedLeadIds = {};
  bool _selectAll = false;
  bool _isDeleting = false;

  // Leads data
  List<Lead> _leads = [];
  List<Lead> _filteredLeads = [];
  bool _loading = true;


  @override
  void initState() {
    super.initState();
    _loadLeads();
  }

  Future<void> _loadLeads() async {
    setState(() => _loading = true);
    try {
      final snapshot = await _firestore.collection('leads').get();
      _leads = snapshot.docs.map((doc) => Lead.fromFirestore(doc)).toList();
      _applyFilters();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading leads: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    _filteredLeads = _leads.where((lead) {
      // Stage filter
      if (_filterStage != null && lead.stage != _filterStage) return false;

      // Health filter
      if (_filterHealth != null && lead.health != _filterHealth) return false;

      // Product filter
      if (_filterProduct != null && lead.interestedInProduct != _filterProduct) return false;

      // Date range filter
      if (_filterFromDate != null && lead.createdAt.isBefore(_filterFromDate!)) return false;
      if (_filterToDate != null && lead.createdAt.isAfter(_filterToDate!.add(const Duration(days: 1)))) return false;

      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesName = lead.clientName.toLowerCase().contains(query);
        final matchesEmail = lead.clientEmail.toLowerCase().contains(query);
        final matchesPhone = lead.clientMobile.contains(query);
        final matchesBusiness = lead.clientBusinessName.toLowerCase().contains(query);
        if (!matchesName && !matchesEmail && !matchesPhone && !matchesBusiness) return false;
      }

      return true;
    }).toList();

    // Sort by created date descending
    _filteredLeads.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Update selectAll state
    _selectAll = _filteredLeads.isNotEmpty &&
        _filteredLeads.every((l) => _selectedLeadIds.contains(l.id));

    setState(() {});
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      _selectAll = value ?? false;
      if (_selectAll) {
        _selectedLeadIds.addAll(_filteredLeads.map((l) => l.id));
      } else {
        _selectedLeadIds.removeAll(_filteredLeads.map((l) => l.id));
      }
    });
  }

  void _toggleLeadSelection(String leadId, bool? selected) {
    setState(() {
      if (selected == true) {
        _selectedLeadIds.add(leadId);
      } else {
        _selectedLeadIds.remove(leadId);
      }
      _selectAll = _filteredLeads.isNotEmpty &&
          _filteredLeads.every((l) => _selectedLeadIds.contains(l.id));
    });
  }

  Future<void> _deleteSelectedLeads() async {
    if (_selectedLeadIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Leads?'),
        content: Text(
          'Are you sure you want to permanently delete ${_selectedLeadIds.length} lead(s)?\n\n'
          'This action cannot be undone. All history and data for these leads will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);

    try {
      int deleted = 0;
      for (final leadId in _selectedLeadIds.toList()) {
        // Delete history subcollection first
        final historySnapshot = await _firestore
            .collection('leads')
            .doc(leadId)
            .collection('history')
            .get();

        for (final historyDoc in historySnapshot.docs) {
          await historyDoc.reference.delete();
        }

        // Delete email_logs subcollection
        final emailLogsSnapshot = await _firestore
            .collection('leads')
            .doc(leadId)
            .collection('email_logs')
            .get();

        for (final emailDoc in emailLogsSnapshot.docs) {
          await emailDoc.reference.delete();
        }

        // Delete the lead document
        await _firestore.collection('leads').doc(leadId).delete();
        deleted++;

        if (deleted % 10 == 0 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted $deleted of ${_selectedLeadIds.length} leads...'),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully deleted ${_selectedLeadIds.length} lead(s)'),
            backgroundColor: Colors.green,
          ),
        );
        _selectedLeadIds.clear();
        await _loadLeads();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting leads: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  void _clearFilters() {
    setState(() {
      _filterStage = null;
      _filterHealth = null;
      _filterProduct = null;
      _filterFromDate = null;
      _filterToDate = null;
      _searchQuery = '';
    });
    _applyFilters();
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _filterFromDate != null && _filterToDate != null
          ? DateTimeRange(start: _filterFromDate!, end: _filterToDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _filterFromDate = picked.start;
        _filterToDate = picked.end;
      });
      _applyFilters();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with warning
        Container(
          color: Colors.red.shade50,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.admin_panel_settings, color: Colors.red.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Super Admin Only: Filter and delete leads from the database',
                  style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),

        // Filters section
        Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Filters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),

                // Search field
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by name, email, phone, business...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() => _searchQuery = '');
                              _applyFilters();
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (value) {
                    _searchQuery = value;
                    _applyFilters();
                  },
                ),
                const SizedBox(height: 12),

                // Filter dropdowns row
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    // Stage filter
                    SizedBox(
                      width: 150,
                      child: DropdownButtonFormField<LeadStage?>(
                        value: _filterStage,
                        decoration: const InputDecoration(
                          labelText: 'Stage',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Stages')),
                          ...LeadStage.values.map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s.label, style: const TextStyle(fontSize: 12)),
                          )),
                        ],
                        onChanged: (v) {
                          _filterStage = v;
                          _applyFilters();
                        },
                      ),
                    ),

                    // Health filter
                    SizedBox(
                      width: 150,
                      child: DropdownButtonFormField<LeadHealth?>(
                        value: _filterHealth,
                        decoration: const InputDecoration(
                          labelText: 'Health',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Health')),
                          ...LeadHealth.values.map((h) => DropdownMenuItem(
                            value: h,
                            child: Text(h.label, style: const TextStyle(fontSize: 12)),
                          )),
                        ],
                        onChanged: (v) {
                          _filterHealth = v;
                          _applyFilters();
                        },
                      ),
                    ),

                    // Product filter
                    SizedBox(
                      width: 200,
                      child: DropdownButtonFormField<ProductService?>(
                        value: _filterProduct,
                        decoration: const InputDecoration(
                          labelText: 'Product/Service',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Products')),
                          ...ProductService.values.map((p) => DropdownMenuItem(
                            value: p,
                            child: Text(p.label, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                          )),
                        ],
                        onChanged: (v) {
                          _filterProduct = v;
                          _applyFilters();
                        },
                      ),
                    ),

                    // Date range button
                    OutlinedButton.icon(
                      onPressed: _pickDateRange,
                      icon: const Icon(Icons.date_range, size: 18),
                      label: Text(
                        _filterFromDate != null && _filterToDate != null
                            ? '${_filterFromDate!.day}/${_filterFromDate!.month} - ${_filterToDate!.day}/${_filterToDate!.month}'
                            : 'Date Range',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),

                    // Clear filters button
                    TextButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: const Text('Clear'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Action bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Colors.grey.shade100,
          child: Row(
            children: [
              Checkbox(
                value: _selectAll,
                onChanged: _toggleSelectAll,
              ),
              Text(
                '${_selectedLeadIds.length} selected of ${_filteredLeads.length}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              if (_selectedLeadIds.isNotEmpty)
                FilledButton.icon(
                  onPressed: _isDeleting ? null : _deleteSelectedLeads,
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  icon: _isDeleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.delete),
                  label: Text(_isDeleting ? 'Deleting...' : 'Delete Selected'),
                ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _loadLeads,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),

        // Leads list
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filteredLeads.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            _leads.isEmpty ? 'No leads in database' : 'No leads match the filters',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredLeads.length,
                      itemBuilder: (context, index) {
                        final lead = _filteredLeads[index];
                        final isSelected = _selectedLeadIds.contains(lead.id);

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          color: isSelected ? Colors.red.shade50 : null,
                          child: CheckboxListTile(
                            value: isSelected,
                            onChanged: (v) => _toggleLeadSelection(lead.id, v),
                            secondary: CircleAvatar(
                              backgroundColor: _getStageColor(lead.stage),
                              child: Text(
                                lead.clientName.isNotEmpty ? lead.clientName[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(
                              lead.clientName,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${lead.clientEmail} • ${lead.clientMobile}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 4,
                                  children: [
                                    _buildChip(lead.stage.label, _getStageColor(lead.stage)),
                                    _buildChip(lead.health.label, _getHealthColor(lead.health)),
                                    _buildChip(
                                      lead.interestedInProduct.label.length > 15
                                          ? '${lead.interestedInProduct.label.substring(0, 15)}...'
                                          : lead.interestedInProduct.label,
                                      Colors.grey,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }

  Color _getStageColor(LeadStage stage) {
    switch (stage) {
      case LeadStage.newLead:
        return Colors.blue;
      case LeadStage.contacted:
        return Colors.cyan;
      case LeadStage.demoScheduled:
        return Colors.orange;
      case LeadStage.demoCompleted:
        return Colors.purple;
      case LeadStage.proposalSent:
        return Colors.indigo;
      case LeadStage.negotiation:
        return Colors.amber;
      case LeadStage.won:
        return Colors.green;
      case LeadStage.lost:
        return Colors.red;
    }
  }

  Color _getHealthColor(LeadHealth health) {
    switch (health) {
      case LeadHealth.hot:
        return Colors.red;
      case LeadHealth.warm:
        return Colors.orange;
      case LeadHealth.solo:
        return Colors.blue;
      case LeadHealth.sleeping:
        return Colors.grey;
      case LeadHealth.dead:
        return Colors.black54;
      case LeadHealth.junk:
        return Colors.brown;
    }
  }
}

// ============================================================================
// Branding Tab (Super Admin Only)
// ============================================================================

class _BrandingTab extends StatefulWidget {
  const _BrandingTab();

  @override
  State<_BrandingTab> createState() => _BrandingTabState();
}

class _BrandingTabState extends State<_BrandingTab> {
  final _firestore = FirebaseFirestore.instance;
  final _nameController = TextEditingController();
  final _picker = ImagePicker();
  bool _loading = true;
  bool _saving = false;
  String? _logoBase64;
  String? _currentLogoBase64;

  @override
  void initState() {
    super.initState();
    _loadBranding();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadBranding() async {
    try {
      final doc = await _firestore.collection('settings').doc('branding').get();
      if (doc.exists) {
        final data = doc.data()!;
        _nameController.text = data['app_name'] ?? '';
        _currentLogoBase64 = data['logo_base64'] as String?;
        _logoBase64 = _currentLogoBase64;
      }
    } catch (e) {
      debugPrint('Branding: Load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickLogo() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (bytes.length > 500000) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image too large. Please use an image under 500KB.')),
          );
        }
        return;
      }

      setState(() {
        _logoBase64 = base64Encode(bytes);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _saveBranding() async {
    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        'app_name': _nameController.text.trim(),
        'updated_at': FieldValue.serverTimestamp(),
      };
      if (_logoBase64 != null) {
        data['logo_base64'] = _logoBase64;
      }
      await _firestore.collection('settings').doc('branding').set(data, SetOptions(merge: true));
      _currentLogoBase64 = _logoBase64;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Branding saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _removeLogo() {
    setState(() {
      _logoBase64 = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'App Branding',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Customize the app logo and name. Changes will appear on the login screen and throughout the app.',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),

          // Logo section
          const Text('App Logo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Center(
            child: Column(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
                  ),
                  child: _logoBase64 != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.memory(
                            base64Decode(_logoBase64!),
                            fit: BoxFit.cover,
                            width: 120,
                            height: 120,
                          ),
                        )
                      : Icon(
                          Icons.image_outlined,
                          size: 48,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickLogo,
                      icon: const Icon(Icons.upload),
                      label: Text(_logoBase64 != null ? 'Change Logo' : 'Upload Logo'),
                    ),
                    if (_logoBase64 != null) ...[
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: _removeLogo,
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        label: const Text('Remove', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Recommended: Square image, max 512x512px',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // App name section
          const Text('App Name', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'e.g. Lead Management System',
              labelText: 'App Name',
            ),
          ),
          const SizedBox(height: 24),

          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _saveBranding,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(_saving ? 'Saving...' : 'Save Branding'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The logo and app name will be displayed on the login screen and app header. After saving, users may need to refresh the page to see changes.',
                      style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
