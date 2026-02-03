import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/email_template.dart';
import '../models/lead.dart';

class EmailService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
    final snap = await _firestore
        .collection('business_categories')
        .orderBy('name')
        .get();
    return snap.docs.map((d) => BusinessCategory.fromFirestore(d)).toList();
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
  // Email Sending
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

  /// Send email using Cloud Function (recommended for production)
  /// This creates an email_queue document that a Cloud Function picks up
  /// NOTE: Actual email delivery requires SMTP Cloud Function deployment
  Future<EmailLog> sendEmailViaQueue({
    required Lead lead,
    required EmailTemplate template,
    required String userId,
    required String userName,
  }) async {
    final placeholders = buildPlaceholders(lead);
    final subject = EmailTemplate.replacePlaceholders(template.subject, placeholders);
    final body = EmailTemplate.replacePlaceholders(template.body, placeholders);

    // Create email log - set status to 'logged' to show in history
    // In production with SMTP Cloud Function, status would update to 'sent' after delivery
    final logRef = _firestore.collection('email_logs').doc();
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
      status: 'logged', // Logged in system - requires SMTP config for actual delivery
    );
    await logRef.set(log.toFirestore());

    // Add to email queue (Cloud Function will pick this up if deployed)
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

    return log;
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
      // Try with orderBy first (requires composite index)
      final snap = await _firestore
          .collection('email_logs')
          .where('lead_id', isEqualTo: leadId)
          .orderBy('sent_at', descending: true)
          .get();
      return snap.docs.map((d) => EmailLog.fromFirestore(d)).toList();
    } catch (e) {
      // Fallback: query without orderBy, then sort in memory
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

  /// Get suggested category based on lead's product/service interest
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
