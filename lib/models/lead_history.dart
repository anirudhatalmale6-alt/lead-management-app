import 'package:cloud_firestore/cloud_firestore.dart';

class LeadHistory {
  final String id;
  final String leadId;
  final String updatedBy;
  final DateTime updatedAt;
  final String comment;
  final Map<String, dynamic> changedFields;
  // New fields for activity logs
  final String? action;
  final String? description;

  LeadHistory({
    required this.id,
    required this.leadId,
    required this.updatedBy,
    required this.updatedAt,
    this.comment = '',
    required this.changedFields,
    this.action,
    this.description,
  });

  factory LeadHistory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Handle both old format (changed_fields) and new format (action/description)
    final hasAction = data.containsKey('action');

    return LeadHistory(
      id: doc.id,
      leadId: data['lead_id'] ?? '',
      // Handle both 'updated_by' and 'user_email' fields
      updatedBy: data['updated_by'] ?? data['user_email'] ?? '',
      // Handle both 'updated_at' and 'timestamp' fields
      updatedAt: data['updated_at'] is Timestamp
          ? (data['updated_at'] as Timestamp).toDate()
          : data['timestamp'] is Timestamp
              ? (data['timestamp'] as Timestamp).toDate()
              : DateTime.now(),
      comment: data['comment'] ?? '',
      changedFields:
          Map<String, dynamic>.from(data['changed_fields'] as Map? ?? {}),
      // New activity log fields
      action: hasAction ? data['action'] : null,
      description: hasAction ? data['description'] : null,
    );
  }

  // Check if this is an activity log entry (vs a field change entry)
  bool get isActivityLog => action != null && action!.isNotEmpty;

  Map<String, dynamic> toFirestore() {
    return {
      'lead_id': leadId,
      'updated_by': updatedBy,
      'updated_at': Timestamp.fromDate(updatedAt),
      'comment': comment,
      'changed_fields': changedFields,
    };
  }
}
