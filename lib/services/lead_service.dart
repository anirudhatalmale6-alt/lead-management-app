import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/lead.dart';
import '../models/lead_history.dart';

class LeadService {
  static final LeadService _instance = LeadService._internal();
  factory LeadService() => _instance;
  LeadService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'leads';

  // ---------------------------------------------------------------------------
  // Create
  // ---------------------------------------------------------------------------

  Future<String> createLead(Lead lead) async {
    final docRef = await _db.collection(_collection).add(lead.toFirestore());
    return docRef.id;
  }

  // ---------------------------------------------------------------------------
  // Update with history tracking
  // ---------------------------------------------------------------------------

  Future<void> updateLead(String leadId, Map<String, dynamic> newData,
      {String updatedBy = '', String comment = ''}) async {
    // Fetch current lead data to compute diff
    final docSnap = await _db.collection(_collection).doc(leadId).get();
    if (docSnap.exists) {
      final oldData = docSnap.data() as Map<String, dynamic>;
      final changedFields = <String, dynamic>{};

      // Fields to track for history
      const trackedFields = [
        'client_name',
        'client_business_name',
        'client_whatsapp',
        'client_mobile',
        'client_email',
        'country',
        'state',
        'client_city',
        'stage',
        'health',
        'activity_state',
        'payment_status',
        'rating',
        'interested_in_product',
        'meeting_agenda',
        'meeting_date',
        'meeting_time',
        'meeting_link',
        'last_call_date',
        'next_follow_up_date',
        'next_follow_up_time',
        'notes',
        'comment',
      ];

      for (final field in trackedFields) {
        if (newData.containsKey(field)) {
          final oldVal = oldData[field];
          final newVal = newData[field];
          // Convert Timestamps to comparable strings
          final oldStr = _valueToString(oldVal);
          final newStr = _valueToString(newVal);
          if (oldStr != newStr) {
            changedFields[field] = {'old': oldStr, 'new': newStr};
          }
        }
      }

      // Save history entry if anything changed
      if (changedFields.isNotEmpty) {
        final history = LeadHistory(
          id: '',
          leadId: leadId,
          updatedBy: updatedBy,
          updatedAt: DateTime.now(),
          comment: comment,
          changedFields: changedFields,
        );
        await _db
            .collection(_collection)
            .doc(leadId)
            .collection('history')
            .add(history.toFirestore());
      }
    }

    newData['updated_at'] = FieldValue.serverTimestamp();
    if (updatedBy.isNotEmpty) {
      newData['last_updated_by'] = updatedBy;
    }
    await _db.collection(_collection).doc(leadId).update(newData);
  }

  Future<void> updateLeadStage(String leadId, String newStage,
      {String updatedBy = ''}) async {
    await updateLead(leadId, {'stage': newStage}, updatedBy: updatedBy);
  }

  // ---------------------------------------------------------------------------
  // History
  // ---------------------------------------------------------------------------

  Future<List<LeadHistory>> getLeadHistory(String leadId) async {
    final snapshot = await _db
        .collection(_collection)
        .doc(leadId)
        .collection('history')
        .orderBy('updated_at', descending: true)
        .get();
    return snapshot.docs.map((doc) => LeadHistory.fromFirestore(doc)).toList();
  }

  Stream<QuerySnapshot> getLeadHistoryStream(String leadId) {
    return _db
        .collection(_collection)
        .doc(leadId)
        .collection('history')
        .orderBy('updated_at', descending: true)
        .snapshots();
  }

  // ---------------------------------------------------------------------------
  // Delete
  // ---------------------------------------------------------------------------

  Future<void> deleteLead(String leadId) async {
    await _db.collection(_collection).doc(leadId).delete();
  }

  // ---------------------------------------------------------------------------
  // Streams
  // ---------------------------------------------------------------------------

  Stream<QuerySnapshot> getLeadsStream({
    String? ownerUid,
    String? teamId,
    String? stage,
  }) {
    Query query = _db.collection(_collection);
    if (ownerUid != null) {
      query = query.where('owner_uid', isEqualTo: ownerUid);
    }
    if (teamId != null) {
      query = query.where('team_id', isEqualTo: teamId);
    }
    if (stage != null) {
      query = query.where('stage', isEqualTo: stage);
    }
    return query.snapshots();
  }

  // ---------------------------------------------------------------------------
  // Fetch helpers
  // ---------------------------------------------------------------------------

  Future<List<Lead>> getAllLeads() async {
    final snapshot = await _db.collection(_collection).get();
    return snapshot.docs.map((doc) => Lead.fromFirestore(doc)).toList();
  }

  Future<List<Lead>> getLeadsByStage(String stage) async {
    final snapshot = await _db
        .collection(_collection)
        .where('stage', isEqualTo: stage)
        .get();
    return snapshot.docs.map((doc) => Lead.fromFirestore(doc)).toList();
  }

  Future<List<Lead>> getLeadsByOwner(String ownerUid) async {
    final snapshot = await _db
        .collection(_collection)
        .where('owner_uid', isEqualTo: ownerUid)
        .get();
    return snapshot.docs.map((doc) => Lead.fromFirestore(doc)).toList();
  }

  Future<List<Lead>> getLeadsByTeam(String teamId) async {
    final snapshot = await _db
        .collection(_collection)
        .where('team_id', isEqualTo: teamId)
        .get();
    return snapshot.docs.map((doc) => Lead.fromFirestore(doc)).toList();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _valueToString(dynamic value) {
    if (value == null) return '';
    if (value is Timestamp) return value.toDate().toIso8601String();
    return value.toString();
  }
}
