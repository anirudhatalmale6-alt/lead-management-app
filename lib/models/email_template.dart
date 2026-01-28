import 'package:cloud_firestore/cloud_firestore.dart';

/// Business categories for email templates
class BusinessCategory {
  final String id;
  final String name;
  final DateTime createdAt;

  BusinessCategory({
    required this.id,
    required this.name,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory BusinessCategory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BusinessCategory(
      id: doc.id,
      name: data['name'] ?? '',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }
}

/// Email template types
enum EmailTemplateType {
  followUp,
  offerPlan,
  demoConfirmation,
  proposal,
  reminder,
  paymentRequest,
}

extension EmailTemplateTypeX on EmailTemplateType {
  String get label {
    switch (this) {
      case EmailTemplateType.followUp:
        return 'Follow-Up';
      case EmailTemplateType.offerPlan:
        return 'Offer Plan';
      case EmailTemplateType.demoConfirmation:
        return 'Demo Confirmation';
      case EmailTemplateType.proposal:
        return 'Proposal';
      case EmailTemplateType.reminder:
        return 'Reminder';
      case EmailTemplateType.paymentRequest:
        return 'Payment Request';
    }
  }

  String get icon {
    switch (this) {
      case EmailTemplateType.followUp:
        return 'refresh';
      case EmailTemplateType.offerPlan:
        return 'local_offer';
      case EmailTemplateType.demoConfirmation:
        return 'event_available';
      case EmailTemplateType.proposal:
        return 'description';
      case EmailTemplateType.reminder:
        return 'notifications';
      case EmailTemplateType.paymentRequest:
        return 'payment';
    }
  }
}

/// Email template model
class EmailTemplate {
  final String id;
  final String categoryId; // Links to BusinessCategory
  final EmailTemplateType type;
  final String subject;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;

  EmailTemplate({
    required this.id,
    required this.categoryId,
    required this.type,
    required this.subject,
    required this.body,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory EmailTemplate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EmailTemplate(
      id: doc.id,
      categoryId: data['category_id'] ?? '',
      type: _parseTemplateType(data['type']),
      subject: data['subject'] ?? '',
      body: data['body'] ?? '',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'category_id': categoryId,
      'type': type.name,
      'subject': subject,
      'body': body,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  static EmailTemplateType _parseTemplateType(dynamic value) {
    if (value == null) return EmailTemplateType.followUp;
    final str = value.toString();
    return EmailTemplateType.values.firstWhere(
      (e) => e.name == str,
      orElse: () => EmailTemplateType.followUp,
    );
  }

  /// Replace placeholders in subject and body with lead data
  static String replacePlaceholders(String text, Map<String, String> data) {
    String result = text;
    data.forEach((key, value) {
      result = result.replaceAll('{{$key}}', value);
    });
    return result;
  }
}

/// SMTP Configuration (stored in Firestore settings collection)
class SmtpConfig {
  final String host;
  final int port;
  final String username;
  final String password;
  final String fromEmail;
  final String fromName;
  final bool useSsl;
  final bool useTls;

  SmtpConfig({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.fromEmail,
    required this.fromName,
    this.useSsl = false,
    this.useTls = true,
  });

  factory SmtpConfig.fromFirestore(Map<String, dynamic> data) {
    return SmtpConfig(
      host: data['host'] ?? '',
      port: data['port'] ?? 587,
      username: data['username'] ?? '',
      password: data['password'] ?? '',
      fromEmail: data['from_email'] ?? '',
      fromName: data['from_name'] ?? '',
      useSsl: data['use_ssl'] ?? false,
      useTls: data['use_tls'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'host': host,
      'port': port,
      'username': username,
      'password': password,
      'from_email': fromEmail,
      'from_name': fromName,
      'use_ssl': useSsl,
      'use_tls': useTls,
    };
  }

  bool get isConfigured =>
      host.isNotEmpty && username.isNotEmpty && password.isNotEmpty;
}

/// Email log entry
class EmailLog {
  final String id;
  final String leadId;
  final String templateId;
  final String templateName;
  final String toEmail;
  final String subject;
  final String sentByUserId;
  final String sentByUserName;
  final DateTime sentAt;
  final String status; // 'sent', 'failed', 'pending'
  final String? errorMessage;

  EmailLog({
    required this.id,
    required this.leadId,
    required this.templateId,
    required this.templateName,
    required this.toEmail,
    required this.subject,
    required this.sentByUserId,
    required this.sentByUserName,
    required this.sentAt,
    required this.status,
    this.errorMessage,
  });

  factory EmailLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EmailLog(
      id: doc.id,
      leadId: data['lead_id'] ?? '',
      templateId: data['template_id'] ?? '',
      templateName: data['template_name'] ?? '',
      toEmail: data['to_email'] ?? '',
      subject: data['subject'] ?? '',
      sentByUserId: data['sent_by_user_id'] ?? '',
      sentByUserName: data['sent_by_user_name'] ?? '',
      sentAt: (data['sent_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'pending',
      errorMessage: data['error_message'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'lead_id': leadId,
      'template_id': templateId,
      'template_name': templateName,
      'to_email': toEmail,
      'subject': subject,
      'sent_by_user_id': sentByUserId,
      'sent_by_user_name': sentByUserName,
      'sent_at': Timestamp.fromDate(sentAt),
      'status': status,
      'error_message': errorMessage,
    };
  }
}
