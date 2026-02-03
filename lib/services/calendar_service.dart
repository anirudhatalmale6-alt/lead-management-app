import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/meeting.dart';

class CalendarService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Meetings collection
  CollectionReference get _meetingsRef => _firestore.collection('meetings');

  // Calendar config document
  DocumentReference get _configRef =>
      _firestore.collection('settings').doc('calendar_config');

  // Get all meetings
  Future<List<Meeting>> getAllMeetings() async {
    try {
      // Try with orderBy first
      final snapshot =
          await _meetingsRef.orderBy('start_time', descending: false).get();
      final meetings = snapshot.docs.map((doc) => Meeting.fromFirestore(doc)).toList();
      debugPrint('CalendarService: Loaded ${meetings.length} meetings from Firestore');
      return meetings;
    } catch (e) {
      debugPrint('CalendarService: orderBy failed, trying without: $e');
      try {
        // Fallback: get without orderBy (no index needed)
        final snapshot = await _meetingsRef.get();
        final meetings = snapshot.docs.map((doc) => Meeting.fromFirestore(doc)).toList();
        // Sort in memory
        meetings.sort((a, b) => a.startTime.compareTo(b.startTime));
        debugPrint('CalendarService: Loaded ${meetings.length} meetings (fallback)');
        return meetings;
      } catch (e2) {
        debugPrint('CalendarService: Error loading meetings: $e2');
        return [];
      }
    }
  }

  // Get meetings for a specific lead
  Future<List<Meeting>> getMeetingsForLead(String leadId) async {
    try {
      debugPrint('CalendarService: Fetching meetings for lead_id: $leadId');
      // Simple query without orderBy to avoid needing composite index
      final snapshot = await _meetingsRef
          .where('lead_id', isEqualTo: leadId)
          .get();
      debugPrint('CalendarService: Found ${snapshot.docs.length} meetings for lead $leadId');
      final meetings = snapshot.docs.map((doc) {
        final meeting = Meeting.fromFirestore(doc);
        debugPrint('CalendarService: Meeting ${doc.id} has lead_id: ${meeting.leadId}');
        return meeting;
      }).toList();
      // Sort in memory instead
      meetings.sort((a, b) => b.startTime.compareTo(a.startTime));
      return meetings;
    } catch (e) {
      debugPrint('Error getting meetings for lead $leadId: $e');
      return [];
    }
  }

  // Get meetings for a date range
  Future<List<Meeting>> getMeetingsInRange(
      DateTime start, DateTime end) async {
    try {
      final snapshot = await _meetingsRef
          .where('start_time', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('start_time', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .orderBy('start_time')
          .get();
      return snapshot.docs.map((doc) => Meeting.fromFirestore(doc)).toList();
    } catch (e) {
      return [];
    }
  }

  // Create a meeting
  Future<String> createMeeting(Meeting meeting) async {
    final docRef = await _meetingsRef.add(meeting.toFirestore());
    return docRef.id;
  }

  // Update a meeting
  Future<void> updateMeeting(String meetingId, Map<String, dynamic> data) async {
    data['updated_at'] = FieldValue.serverTimestamp();
    await _meetingsRef.doc(meetingId).update(data);
  }

  // Update meeting status
  Future<void> updateMeetingStatus(String meetingId, MeetingStatus status) async {
    await _meetingsRef.doc(meetingId).update({
      'status': status.toSnakeCase(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // Delete a meeting
  Future<void> deleteMeeting(String meetingId) async {
    await _meetingsRef.doc(meetingId).delete();
  }

  // Get calendar config
  Future<CalendarConfig?> getCalendarConfig() async {
    try {
      final doc = await _configRef.get();
      if (doc.exists) {
        return CalendarConfig.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Save calendar config
  Future<void> saveCalendarConfig(CalendarConfig config) async {
    await _configRef.set(config.toFirestore());
  }

  // Stream of meetings for real-time updates
  Stream<List<Meeting>> meetingsStream() {
    return _meetingsRef
        .orderBy('start_time', descending: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Meeting.fromFirestore(doc)).toList());
  }

  // Stream of meetings for a specific lead
  Stream<List<Meeting>> leadMeetingsStream(String leadId) {
    return _meetingsRef
        .where('lead_id', isEqualTo: leadId)
        .orderBy('start_time', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Meeting.fromFirestore(doc)).toList());
  }
}
