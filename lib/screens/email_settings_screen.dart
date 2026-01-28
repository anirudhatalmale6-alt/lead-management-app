import 'package:flutter/material.dart';
import '../models/email_template.dart';
import '../services/email_service.dart';

class EmailSettingsScreen extends StatefulWidget {
  const EmailSettingsScreen({super.key});

  @override
  State<EmailSettingsScreen> createState() => _EmailSettingsScreenState();
}

class _EmailSettingsScreenState extends State<EmailSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final EmailService _emailService = EmailService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Settings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'SMTP', icon: Icon(Icons.settings)),
            Tab(text: 'Categories', icon: Icon(Icons.category)),
            Tab(text: 'Templates', icon: Icon(Icons.email)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _SmtpConfigTab(emailService: _emailService),
          _CategoriesTab(emailService: _emailService),
          _TemplatesTab(emailService: _emailService),
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
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _saveConfig,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_saving ? 'Saving...' : 'Save SMTP Settings'),
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
