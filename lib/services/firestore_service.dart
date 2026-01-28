import 'package:cloud_firestore/cloud_firestore.dart';

/// Singleton service for managing Teams, Groups, and Activity Logs in
/// Firestore. All document fields use snake_case naming conventions.
class FirestoreService {
  // ---------------------------------------------------------------------------
  // Singleton
  // ---------------------------------------------------------------------------
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // Teams
  // ---------------------------------------------------------------------------

  /// Creates a new team document in the `teams` collection.
  ///
  /// Returns the auto-generated document ID.
  Future<String> createTeam(
    String name,
    String description,
    String managerUid,
  ) async {
    final docRef = await _db.collection('teams').add({
      'name': name,
      'description': description,
      'manager_uid': managerUid,
      'is_active': true,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Updates an existing team document with the provided [data] map.
  ///
  /// Automatically sets `updated_at` to the server timestamp.
  Future<void> updateTeam(String teamId, Map<String, dynamic> data) async {
    data['updated_at'] = FieldValue.serverTimestamp();
    await _db.collection('teams').doc(teamId).update(data);
  }

  /// Deletes the team document identified by [teamId].
  Future<void> deleteTeam(String teamId) async {
    await _db.collection('teams').doc(teamId).delete();
  }

  /// Returns a real-time stream of all documents in the `teams` collection.
  Stream<QuerySnapshot> getTeamsStream() {
    return _db.collection('teams').snapshots();
  }

  /// Fetches all teams as a list of maps. Each map includes the document ID
  /// under the key `'id'`.
  Future<List<Map<String, dynamic>>> getTeams() async {
    final snapshot = await _db.collection('teams').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Groups
  // ---------------------------------------------------------------------------

  /// Creates a new group document in the `groups` collection.
  ///
  /// Returns the auto-generated document ID.
  Future<String> createGroup(
    String name,
    String description,
    String teamId,
    String leadUid,
  ) async {
    final docRef = await _db.collection('groups').add({
      'name': name,
      'description': description,
      'team_id': teamId,
      'lead_uid': leadUid,
      'is_active': true,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// Updates an existing group document with the provided [data] map.
  ///
  /// Automatically sets `updated_at` to the server timestamp.
  Future<void> updateGroup(String groupId, Map<String, dynamic> data) async {
    data['updated_at'] = FieldValue.serverTimestamp();
    await _db.collection('groups').doc(groupId).update(data);
  }

  /// Deletes the group document identified by [groupId].
  Future<void> deleteGroup(String groupId) async {
    await _db.collection('groups').doc(groupId).delete();
  }

  /// Returns a real-time stream of documents in the `groups` collection.
  ///
  /// When [teamId] is provided the stream is filtered to only groups
  /// belonging to that team.
  Stream<QuerySnapshot> getGroupsStream({String? teamId}) {
    Query query = _db.collection('groups');
    if (teamId != null) {
      query = query.where('team_id', isEqualTo: teamId);
    }
    return query.snapshots();
  }

  /// Fetches groups as a list of maps. Each map includes the document ID
  /// under the key `'id'`.
  ///
  /// When [teamId] is provided the results are filtered to only groups
  /// belonging to that team.
  Future<List<Map<String, dynamic>>> getGroups({String? teamId}) async {
    Query query = _db.collection('groups');
    if (teamId != null) {
      query = query.where('team_id', isEqualTo: teamId);
    }
    final snapshot = await query.get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Activity Logs
  // ---------------------------------------------------------------------------

  /// Creates a new activity log entry in the `activity_logs` collection.
  ///
  /// [action] describes what happened (e.g. "created", "updated", "deleted").
  /// [entityType] is the type of entity affected (e.g. "lead", "team").
  /// [entityId] is the ID of the affected entity.
  /// [details] holds arbitrary additional context.
  /// [performedBy] is the UID of the user who performed the action.
  Future<void> logActivity(
    String action,
    String entityType,
    String entityId,
    Map<String, dynamic> details,
    String performedBy,
  ) async {
    await _db.collection('activity_logs').add({
      'action': action,
      'entity_type': entityType,
      'entity_id': entityId,
      'details': details,
      'performed_by': performedBy,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  /// Returns a real-time stream of the most recent activity log entries,
  /// ordered by `created_at` descending.
  ///
  /// [limit] controls the maximum number of entries returned (default 50).
  Stream<QuerySnapshot> getActivityLogsStream({int limit = 50}) {
    return _db
        .collection('activity_logs')
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots();
  }
}
