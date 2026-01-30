import 'package:flutter/material.dart';
import '../models/email_template.dart';
import '../models/lead.dart';
import '../models/user.dart';
import '../services/email_service.dart';

class SendEmailDialog extends StatefulWidget {
  final Lead lead;
  final AppUser currentUser;

  const SendEmailDialog({
    super.key,
    required this.lead,
    required this.currentUser,
  });

  @override
  State<SendEmailDialog> createState() => _SendEmailDialogState();
}

class _SendEmailDialogState extends State<SendEmailDialog> {
  final EmailService _emailService = EmailService();
  List<BusinessCategory> _categories = [];
  List<EmailTemplate> _templates = [];
  String? _selectedCategoryId;
  EmailTemplate? _selectedTemplate;
  bool _loading = true;
  bool _sending = false;
  String? _previewSubject;
  String? _previewBody;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final categories = await _emailService.getCategories();
    setState(() {
      _categories = categories;
      _loading = false;
      // Auto-select category based on lead's product
      _selectedCategoryId =
          _emailService.suggestCategoryForLead(widget.lead, categories);
    });
    if (_selectedCategoryId != null) {
      await _loadTemplates(_selectedCategoryId!);
    }
  }

  Future<void> _loadTemplates(String categoryId) async {
    final templates =
        await _emailService.getTemplatesForCategory(categoryId);
    setState(() {
      _templates = templates;
      _selectedTemplate = null;
      _previewSubject = null;
      _previewBody = null;
    });
  }

  void _selectTemplate(EmailTemplate template) {
    final preview = _emailService.previewEmail(template, widget.lead);
    setState(() {
      _selectedTemplate = template;
      _previewSubject = preview['subject'];
      _previewBody = preview['body'];
    });
  }

  Future<void> _sendEmail() async {
    if (_selectedTemplate == null) return;
    if (widget.lead.clientEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lead has no email address!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await _emailService.sendEmailViaQueue(
        lead: widget.lead,
        template: _selectedTemplate!,
        userId: widget.currentUser.uid,
        userName: widget.currentUser.name,
      );
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Email queued for "${widget.lead.clientName}"'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Dialog(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading templates...'),
            ],
          ),
        ),
      );
    }

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header - Fixed at top
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Send Email',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Lead info
                    Card(
                      color: Colors.grey.shade100,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.person, color: Colors.blue),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.lead.clientName,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    widget.lead.clientEmail.isEmpty
                                        ? 'No email address'
                                        : widget.lead.clientEmail,
                                    style: TextStyle(
                                      color: widget.lead.clientEmail.isEmpty
                                          ? Colors.red
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Category selector
                    if (_categories.isEmpty)
                      const Card(
                        color: Colors.orange,
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'No business categories configured. Go to Email Settings to add categories and templates.',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      )
                    else ...[
                      DropdownButtonFormField<String>(
                        value: _selectedCategoryId,
                        decoration: const InputDecoration(
                          labelText: 'Business Category',
                          prefixIcon: Icon(Icons.category),
                        ),
                        items: _categories
                            .map((c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text(c.name),
                                ))
                            .toList(),
                        onChanged: (v) {
                          setState(() => _selectedCategoryId = v);
                          if (v != null) _loadTemplates(v);
                        },
                      ),
                      const SizedBox(height: 16),
                      // Template buttons
                      const Text(
                        'Select Template:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      if (_templates.isEmpty)
                        const Text(
                          'No templates for this category.',
                          style: TextStyle(color: Colors.grey),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _templates.map((tpl) {
                            final isSelected = _selectedTemplate?.id == tpl.id;
                            return ChoiceChip(
                              label: Text(tpl.type.label),
                              selected: isSelected,
                              onSelected: (_) => _selectTemplate(tpl),
                              avatar: Icon(
                                _getTemplateIcon(tpl.type),
                                size: 18,
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                    // Preview
                    if (_previewSubject != null) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const Text(
                        'Preview:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Subject: ',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Expanded(child: Text(_previewSubject!)),
                              ],
                            ),
                            const Divider(),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 150),
                              child: SingleChildScrollView(
                                child: Text(_previewBody ?? ''),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            // Send button - Fixed at bottom
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: _selectedTemplate == null || _sending
                        ? null
                        : _sendEmail,
                    icon: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                    label: Text(_sending ? 'Sending...' : 'Send Email'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
