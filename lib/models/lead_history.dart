import 'package:cloud_firestore/cloud_firestore.dart';

class LeadHistory {
  final String id;
  final String leadId;
  final String updatedBy;
  final DateTime updatedAt;
  final String comment;
  final Map<String, dynamic> changedFields;

  LeadHistory({
    required this.id,
    required this.leadId,
    required this.updatedBy,
    required this.updatedAt,
    this.comment = '',
    required this.changedFields,
  });

  factory LeadHistory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LeadHistory(
      id: doc.id,
      leadId: data['lead_id'] ?? '',
      updatedBy: data['updated_by'] ?? '',
      updatedAt: data['updated_at'] is Timestamp
          ? (data['updated_at'] as Timestamp).toDate()
          : DateTime.now(),
      comment: data['comment'] ?? '',
      changedFields:
          Map<String, dynamic>.from(data['changed_fields'] as Map? ?? {}),
    );
  }

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
