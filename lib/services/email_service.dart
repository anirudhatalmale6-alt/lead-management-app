import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../models/email_template.dart';
import '../models/lead.dart';

class EmailService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // -------------------------------------------------------------------------
  // Business Categories
  // -------------------------------------------------------------------------

  Stream<List<BusinessCategory>> streamCategories() {
    return _firestore
        .collection('business_categories')
        .orderBy('name')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => BusinessCategory.fromFirestore(d)).toList());
  }

  Future<List<BusinessCategory>> getCategories() async {
    try {
      final snap = await _firestore
          .collection('business_categories')
          .orderBy('name')
          .get();
      return snap.docs.map((d) => BusinessCategory.fromFirestore(d)).toList();
    } catch (e) {
      debugPrint('EmailService: orderBy query failed, trying without: $e');
      final snap = await _firestore
          .collection('business_categories')
          .get();
      final categories = snap.docs.map((d) => BusinessCategory.fromFirestore(d)).toList();
      categories.sort((a, b) => a.name.compareTo(b.name));
      return categories;
    }
  }

  Future<void> addCategory(String name) async {
    await _firestore.collection('business_categories').add({
      'name': name,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteCategory(String id) async {
    await _firestore.collection('business_categories').doc(id).delete();
  }

  // -------------------------------------------------------------------------
  // Email Templates
  // -------------------------------------------------------------------------

  Stream<List<EmailTemplate>> streamTemplates({String? categoryId}) {
    Query query = _firestore.collection('email_templates');
    if (categoryId != null && categoryId.isNotEmpty) {
      query = query.where('category_id', isEqualTo: categoryId);
    }
    return query.snapshots().map((snap) =>
        snap.docs.map((d) => EmailTemplate.fromFirestore(d)).toList());
  }

  Future<List<EmailTemplate>> getTemplatesForCategory(String categoryId) async {
    final snap = await _firestore
        .collection('email_templates')
        .where('category_id', isEqualTo: categoryId)
        .get();
    return snap.docs.map((d) => EmailTemplate.fromFirestore(d)).toList();
  }

  Future<void> saveTemplate(EmailTemplate template) async {
    if (template.id.isEmpty) {
      await _firestore
          .collection('email_templates')
          .add(template.toFirestore());
    } else {
      await _firestore
          .collection('email_templates')
          .doc(template.id)
          .update(template.toFirestore());
    }
  }

  Future<void> deleteTemplate(String id) async {
    await _firestore.collection('email_templates').doc(id).delete();
  }

  // -------------------------------------------------------------------------
  // SMTP Configuration
  // -------------------------------------------------------------------------

  Future<SmtpConfig?> getSmtpConfig() async {
    final doc = await _firestore.collection('settings').doc('smtp').get();
    if (!doc.exists) return null;
    return SmtpConfig.fromFirestore(doc.data()!);
  }

  Future<void> saveSmtpConfig(SmtpConfig config) async {
    await _firestore
        .collection('settings')
        .doc('smtp')
        .set(config.toFirestore());
  }

  // -------------------------------------------------------------------------
  // SMTP Connection & Sending (Native/Mobile via mailer package)
  // -------------------------------------------------------------------------

  /// Create SmtpServer from config (mobile only)
  SmtpServer _createSmtpServer(SmtpConfig config) {
    return SmtpServer(
      config.host,
      port: config.port,
      username: config.username,
      password: config.password,
      ssl: config.useSsl,
      ignoreBadCertificate: true,
      allowInsecure: !config.useSsl && !config.useTls,
    );
  }

  /// Test SMTP connection - works on both web (via Cloud Function) and mobile (direct)
  Future<String> testSmtpConnection(SmtpConfig config) async {
    if (kIsWeb) {
      return _testSmtpConnectionViaCloudFunction();
    }
    return _testSmtpConnectionDirect(config);
  }

  /// Test SMTP via Cloud Function (web-compatible)
  Future<String> _testSmtpConnectionViaCloudFunction() async {
    try {
      final callable = _functions.httpsCallable('testSmtpConnection');
      final result = await callable.call();
      final data = result.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return 'Success! ${data['message'] ?? 'SMTP connection verified'}';
      } else {
        return 'Error: ${data['error'] ?? 'Unknown error'}';
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Cloud Function error: ${e.code} - ${e.message}');
      if (e.code == 'not-found' || e.message?.contains('not found') == true) {
        return 'Cloud Functions not deployed yet. Please deploy Firebase Cloud Functions first.\n\nRun: firebase deploy --only functions';
      }
      return 'Cloud Function error: ${e.message}';
    } catch (e) {
      debugPrint('Test connection error: $e');
      return 'Error: $e';
    }
  }

  /// Test SMTP directly (mobile only)
  Future<String> _testSmtpConnectionDirect(SmtpConfig config) async {
    try {
      final smtpServer = _createSmtpServer(config);

      final message = Message()
        ..from = Address(config.fromEmail, config.fromName.isNotEmpty ? config.fromName : 'LMS Test')
        ..recipients.add(config.fromEmail)
        ..subject = 'LMS - SMTP Test Connection'
        ..text = 'This is a test email from the Lead Management System.\n\nIf you received this, your SMTP settings are configured correctly!\n\nTimestamp: ${DateTime.now()}'
        ..html = '''
<div style="font-family: Arial, sans-serif; max-width: 500px; margin: 0 auto; padding: 20px;">
  <h2 style="color: #1565C0;">SMTP Test Successful!</h2>
  <p>This is a test email from the <strong>Lead Management System</strong>.</p>
  <p>If you received this, your SMTP settings are configured correctly.</p>
  <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 20px 0;">
  <p style="color: #757575; font-size: 12px;">Timestamp: ${DateTime.now()}</p>
</div>
''';

      final sendReport = await send(message, smtpServer);
      debugPrint('SMTP Test: Email sent successfully: ${sendReport.toString()}');
      return 'Success! Test email sent to ${config.fromEmail}';
    } on MailerException catch (e) {
      debugPrint('SMTP Test Error: ${e.message}');
      String errorMsg = 'SMTP Error: ${e.message}';
      for (var p in e.problems) {
        errorMsg += '\n- ${p.code}: ${p.msg}';
      }
      return errorMsg;
    } catch (e) {
      debugPrint('SMTP Test Error: $e');
      return 'Connection failed: $e';
    }
  }

  /// Send an email directly via SMTP (mobile only)
  Future<bool> _sendEmailSmtpDirect({
    required SmtpConfig config,
    required String toEmail,
    required String toName,
    required String subject,
    required String body,
  }) async {
    try {
      final smtpServer = _createSmtpServer(config);

      final message = Message()
        ..from = Address(config.fromEmail, config.fromName.isNotEmpty ? config.fromName : 'Lead Management System')
        ..recipients.add(toEmail)
        ..subject = subject
        ..html = '''
<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
  ${body.replaceAll('\n', '<br>')}
  <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 20px 0;">
  <p style="color: #757575; font-size: 11px;">Sent from Lead Management System</p>
</div>
'''
        ..text = body;

      await send(message, smtpServer);
      debugPrint('Email sent to $toEmail: $subject');
      return true;
    } on MailerException catch (e) {
      debugPrint('Email send error: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Email send error: $e');
      return false;
    }
  }

  /// Send an email via Cloud Function (web-compatible)
  Future<bool> _sendEmailViaCloudFunction({
    required String toEmail,
    required String toName,
    required String subject,
    required String body,
    String? logId,
  }) async {
    try {
      final callable = _functions.httpsCallable('sendEmailNow');
      final result = await callable.call({
        'toEmail': toEmail,
        'toName': toName,
        'subject': subject,
        'body': body,
        'logId': logId,
      });
      final data = result.data as Map<String, dynamic>;
      return data['success'] == true;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Cloud Function sendEmailNow error: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('sendEmailNow error: $e');
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // Email Sending (unified - works on web and mobile)
  // -------------------------------------------------------------------------

  /// Build placeholder map from lead data
  Map<String, String> buildPlaceholders(Lead lead) {
    return {
      'client_name': lead.clientName,
      'business_name': lead.clientBusinessName,
      'client_email': lead.clientEmail,
      'client_mobile': lead.clientMobile,
      'client_whatsapp': lead.clientWhatsApp,
      'client_city': lead.clientCity,
      'country': lead.country,
      'state': lead.state,
      'meeting_date': lead.meetingDate != null
          ? '${lead.meetingDate!.day}/${lead.meetingDate!.month}/${lead.meetingDate!.year}'
          : '',
      'meeting_time': lead.meetingTime,
      'meeting_link': lead.meetingLink,
      'product_name': lead.interestedInProduct.label,
      'stage': lead.stage.label,
      'next_follow_up':
          lead.nextFollowUpDate != null
              ? '${lead.nextFollowUpDate!.day}/${lead.nextFollowUpDate!.month}/${lead.nextFollowUpDate!.year}'
              : '',
      'submitter_name': lead.submitterName,
      'notes': lead.notes,
    };
  }

  /// Preview email with placeholders replaced
  Map<String, String> previewEmail(EmailTemplate template, Lead lead) {
    final placeholders = buildPlaceholders(lead);
    return {
      'subject': EmailTemplate.replacePlaceholders(template.subject, placeholders),
      'body': EmailTemplate.replacePlaceholders(template.body, placeholders),
    };
  }

  /// Send email: works on both web and mobile
  /// - Mobile: tries direct SMTP first, falls back to queue
  /// - Web: tries Cloud Function first, falls back to queue (for automatic Cloud Function trigger)
  Future<EmailLog> sendEmailViaQueue({
    required Lead lead,
    required EmailTemplate template,
    required String userId,
    required String userName,
  }) async {
    final placeholders = buildPlaceholders(lead);
    final subject = EmailTemplate.replacePlaceholders(template.subject, placeholders);
    final body = EmailTemplate.replacePlaceholders(template.body, placeholders);

    bool smtpSent = false;
    String status = 'pending';
    String? errorMessage;

    // Create email log first
    final logRef = _firestore.collection('email_logs').doc();

    if (lead.clientEmail.isNotEmpty) {
      if (kIsWeb) {
        // Web: try Cloud Function
        try {
          smtpSent = await _sendEmailViaCloudFunction(
            toEmail: lead.clientEmail,
            toName: lead.clientName,
            subject: subject,
            body: body,
            logId: logRef.id,
          );
          status = smtpSent ? 'sent' : 'failed';
          if (!smtpSent) {
            errorMessage = 'Email sending failed. Please try again.';
          }
        } catch (e) {
          status = 'failed';
          errorMessage = 'Email sending failed. Please try again.';
          debugPrint('Email Cloud Function error: $e');
        }
      } else {
        // Mobile: try direct SMTP
        try {
          final config = await getSmtpConfig();
          if (config != null && config.isConfigured) {
            smtpSent = await _sendEmailSmtpDirect(
              config: config,
              toEmail: lead.clientEmail,
              toName: lead.clientName,
              subject: subject,
              body: body,
            );
            status = smtpSent ? 'sent' : 'failed';
            if (!smtpSent) {
              errorMessage = 'Email sending failed. Please try again.';
            }
          } else {
            status = 'failed';
            errorMessage = 'Email not configured. Please set up SMTP in Settings.';
          }
        } catch (e) {
          status = 'failed';
          errorMessage = 'Email sending failed. Please try again.';
          debugPrint('Email SMTP error: $e');
        }
      }
    }

    final log = EmailLog(
      id: logRef.id,
      leadId: lead.id,
      templateId: template.id,
      templateName: template.type.label,
      toEmail: lead.clientEmail,
      subject: subject,
      sentByUserId: userId,
      sentByUserName: userName,
      sentAt: DateTime.now(),
      status: status,
      errorMessage: errorMessage,
    );
    await logRef.set(log.toFirestore());

    // If not sent, add to queue (Cloud Function trigger will pick it up OR manual process)
    if (!smtpSent) {
      await _firestore.collection('email_queue').add({
        'log_id': logRef.id,
        'to_email': lead.clientEmail,
        'to_name': lead.clientName,
        'subject': subject,
        'body': body,
        'lead_id': lead.id,
        'created_at': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    }

    return log;
  }

  /// Process pending emails - works on both web (Cloud Function) and mobile (direct SMTP)
  Future<String> processPendingEmails() async {
    if (kIsWeb) {
      return _processQueueViaCloudFunction();
    }
    return _processQueueDirect();
  }

  /// Process queue via Cloud Function (web)
  Future<String> _processQueueViaCloudFunction() async {
    try {
      final callable = _functions.httpsCallable('processEmailQueue');
      final result = await callable.call();
      final data = result.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return data['message'] ?? 'Queue processed';
      } else {
        return 'Error: ${data['error'] ?? 'Unknown error'}';
      }
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found' || e.message?.contains('not found') == true) {
        return 'Cloud Functions not deployed yet. Please deploy Firebase Cloud Functions first.\n\nRun: firebase deploy --only functions';
      }
      return 'Cloud Function error: ${e.message}';
    } catch (e) {
      return 'Error: $e';
    }
  }

  /// Process queue directly via SMTP (mobile)
  Future<String> _processQueueDirect() async {
    final config = await getSmtpConfig();
    if (config == null || !config.isConfigured) {
      return 'SMTP not configured. Please save your SMTP settings first.';
    }

    final snap = await _firestore
        .collection('email_queue')
        .where('status', isEqualTo: 'pending')
        .limit(20)
        .get();

    if (snap.docs.isEmpty) {
      return 'No pending emails in queue.';
    }

    int sentCount = 0;
    int failCount = 0;

    for (final doc in snap.docs) {
      final data = doc.data();
      try {
        final sent = await _sendEmailSmtpDirect(
          config: config,
          toEmail: data['to_email'] ?? '',
          toName: data['to_name'] ?? '',
          subject: data['subject'] ?? '',
          body: data['body'] ?? '',
        );

        if (sent) {
          await doc.reference.update({'status': 'sent', 'sent_at': FieldValue.serverTimestamp()});
          final logId = data['log_id'];
          if (logId != null) {
            await _firestore.collection('email_logs').doc(logId).update({
              'status': 'sent',
              'error_message': null,
            });
          }
          sentCount++;
        } else {
          await doc.reference.update({'status': 'failed', 'error': 'SMTP delivery failed'});
          failCount++;
        }
      } catch (e) {
        await doc.reference.update({'status': 'failed', 'error': e.toString()});
        failCount++;
        debugPrint('Queue processing error: $e');
      }
    }

    if (sentCount > 0 && failCount == 0) {
      return '$sentCount email(s) sent successfully!';
    } else if (sentCount > 0) {
      return '$sentCount sent, $failCount failed.';
    } else {
      return 'All $failCount email(s) failed to send.';
    }
  }

  // -------------------------------------------------------------------------
  // Email Logs
  // -------------------------------------------------------------------------

  Stream<List<EmailLog>> streamEmailLogs({String? leadId}) {
    Query query = _firestore
        .collection('email_logs')
        .orderBy('sent_at', descending: true)
        .limit(100);
    if (leadId != null) {
      query = query.where('lead_id', isEqualTo: leadId);
    }
    return query.snapshots().map(
        (snap) => snap.docs.map((d) => EmailLog.fromFirestore(d)).toList());
  }

  Future<List<EmailLog>> getEmailLogsForLead(String leadId) async {
    try {
      final snap = await _firestore
          .collection('email_logs')
          .where('lead_id', isEqualTo: leadId)
          .orderBy('sent_at', descending: true)
          .get();
      return snap.docs.map((d) => EmailLog.fromFirestore(d)).toList();
    } catch (e) {
      final snap = await _firestore
          .collection('email_logs')
          .where('lead_id', isEqualTo: leadId)
          .get();
      final logs = snap.docs.map((d) => EmailLog.fromFirestore(d)).toList();
      logs.sort((a, b) => b.sentAt.compareTo(a.sentAt));
      return logs;
    }
  }

  // -------------------------------------------------------------------------
  // Map Product/Service to Business Category
  // -------------------------------------------------------------------------

  String? suggestCategoryForLead(Lead lead, List<BusinessCategory> categories) {
    final productLabel = lead.interestedInProduct.label.toLowerCase();

    for (final cat in categories) {
      final catName = cat.name.toLowerCase();
      if (productLabel.contains('cityfinsol') && catName.contains('cityfinsol')) {
        return cat.id;
      }
      if ((productLabel.contains('crm') || productLabel.contains('erp') ||
           productLabel.contains('website') || productLabel.contains('app')) &&
          catName.contains('saas')) {
        return cat.id;
      }
      if (productLabel.contains('digital') && catName.contains('digital')) {
        return cat.id;
      }
    }
    return categories.isNotEmpty ? categories.first.id : null;
  }
}
