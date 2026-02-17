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

  Future<List<Lead>> getLeadsByGroup(String groupId) async {
    final snapshot = await _db
        .collection(_collection)
        .where('group_id', isEqualTo: groupId)
        .get();
    return snapshot.docs.map((doc) => Lead.fromFirestore(doc)).toList();
  }

  Future<Lead?> getLeadById(String leadId) async {
    final doc = await _db.collection(_collection).doc(leadId).get();
    if (doc.exists) {
      return Lead.fromFirestore(doc);
    }
    return null;
  }

  /// Get all leads accessible to a user:
  /// - Leads they own (owner_uid matches)
  /// - Leads assigned to them (assigned_to matches)
  /// - Leads where they are a follower
  /// - Leads where they are tagged as manager
  Future<List<Lead>> getLeadsForUser(String userEmail, {String? ownerUid}) async {
    final Set<String> leadIds = {};
    final List<Lead> leads = [];

    // 1. Leads owned by user
    if (ownerUid != null && ownerUid.isNotEmpty) {
      final ownedSnapshot = await _db
          .collection(_collection)
          .where('owner_uid', isEqualTo: ownerUid)
          .get();
      for (final doc in ownedSnapshot.docs) {
        if (!leadIds.contains(doc.id)) {
          leadIds.add(doc.id);
          leads.add(Lead.fromFirestore(doc));
        }
      }
    }

    // 2. Leads assigned to user
    if (userEmail.isNotEmpty) {
      final assignedSnapshot = await _db
          .collection(_collection)
          .where('assigned_to', isEqualTo: userEmail)
          .get();
      for (final doc in assignedSnapshot.docs) {
        if (!leadIds.contains(doc.id)) {
          leadIds.add(doc.id);
          leads.add(Lead.fromFirestore(doc));
        }
      }

      // 3. Leads where user is tagged as manager
      final taggedSnapshot = await _db
          .collection(_collection)
          .where('tagged_manager', isEqualTo: userEmail)
          .get();
      for (final doc in taggedSnapshot.docs) {
        if (!leadIds.contains(doc.id)) {
          leadIds.add(doc.id);
          leads.add(Lead.fromFirestore(doc));
        }
      }

      // 4. Leads where user is a follower
      final followerSnapshot = await _db
          .collection(_collection)
          .where('followers', arrayContains: userEmail)
          .get();
      for (final doc in followerSnapshot.docs) {
        if (!leadIds.contains(doc.id)) {
          leadIds.add(doc.id);
          leads.add(Lead.fromFirestore(doc));
        }
      }
    }

    // Sort by updated_at descending
    leads.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return leads;
  }

  /// Stream version of getLeadsForUser - returns combined stream
  Stream<List<Lead>> getLeadsStreamForUser(String userEmail, {String? ownerUid}) {
    // For stream, we'll combine multiple queries
    // This is a simplified version - for production, consider using rxdart for merging streams
    return _db.collection(_collection).snapshots().map((snapshot) {
      final leads = <Lead>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final docOwner = data['owner_uid'] ?? '';
        final docAssigned = data['assigned_to'] ?? '';
        final docTagged = data['tagged_manager'] ?? '';
        final docFollowers = List<String>.from(data['followers'] ?? []);

        // Check if user has access
        if ((ownerUid != null && docOwner == ownerUid) ||
            docAssigned == userEmail ||
            docTagged == userEmail ||
            docFollowers.contains(userEmail)) {
          leads.add(Lead.fromFirestore(doc));
        }
      }
      leads.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return leads;
    });
  }

  Future<void> addLeadHistory(String leadId, String activityType, String description, String userEmail) async {
    await _db.collection(_collection).doc(leadId).collection('history').add({
      'action': activityType,
      'description': description,
      'updated_at': FieldValue.serverTimestamp(),
      'updated_by': userEmail,
      'changed_fields': {},
      'comment': '',
    });
    // Also update the lead's updated_at timestamp
    await _db.collection(_collection).doc(leadId).update({
      'updated_at': FieldValue.serverTimestamp(),
      'last_updated_by': userEmail,
    });
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
