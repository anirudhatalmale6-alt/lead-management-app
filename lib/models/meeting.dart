import 'package:cloud_firestore/cloud_firestore.dart';

enum MeetingType { googleMeet, phoneCall, inPerson, other }

enum MeetingStatus {
  scheduled,
  confirmed,
  inProgress,
  completed,
  cancelled,
  rescheduled,
  noShow
}

extension MeetingTypeX on MeetingType {
  String get label {
    switch (this) {
      case MeetingType.googleMeet:
        return 'Google Meet';
      case MeetingType.phoneCall:
        return 'Phone Call';
      case MeetingType.inPerson:
        return 'In Person';
      case MeetingType.other:
        return 'Other';
    }
  }

  static MeetingType fromString(String value) {
    switch (value) {
      case 'google_meet':
        return MeetingType.googleMeet;
      case 'phone_call':
        return MeetingType.phoneCall;
      case 'in_person':
        return MeetingType.inPerson;
      default:
        return MeetingType.other;
    }
  }

  String toSnakeCase() {
    switch (this) {
      case MeetingType.googleMeet:
        return 'google_meet';
      case MeetingType.phoneCall:
        return 'phone_call';
      case MeetingType.inPerson:
        return 'in_person';
      case MeetingType.other:
        return 'other';
    }
  }
}

extension MeetingStatusX on MeetingStatus {
  String get label {
    switch (this) {
      case MeetingStatus.scheduled:
        return 'Scheduled';
      case MeetingStatus.confirmed:
        return 'Confirmed';
      case MeetingStatus.inProgress:
        return 'In Progress';
      case MeetingStatus.completed:
        return 'Completed';
      case MeetingStatus.cancelled:
        return 'Cancelled';
      case MeetingStatus.rescheduled:
        return 'Rescheduled';
      case MeetingStatus.noShow:
        return 'No Show';
    }
  }

  static MeetingStatus fromString(String value) {
    switch (value) {
      case 'scheduled':
        return MeetingStatus.scheduled;
      case 'confirmed':
        return MeetingStatus.confirmed;
      case 'in_progress':
        return MeetingStatus.inProgress;
      case 'completed':
        return MeetingStatus.completed;
      case 'cancelled':
        return MeetingStatus.cancelled;
      case 'rescheduled':
        return MeetingStatus.rescheduled;
      case 'no_show':
        return MeetingStatus.noShow;
      default:
        return MeetingStatus.scheduled;
    }
  }

  String toSnakeCase() {
    switch (this) {
      case MeetingStatus.scheduled:
        return 'scheduled';
      case MeetingStatus.confirmed:
        return 'confirmed';
      case MeetingStatus.inProgress:
        return 'in_progress';
      case MeetingStatus.completed:
        return 'completed';
      case MeetingStatus.cancelled:
        return 'cancelled';
      case MeetingStatus.rescheduled:
        return 'rescheduled';
      case MeetingStatus.noShow:
        return 'no_show';
    }
  }
}

class MeetingGuest {
  final String email;
  final String? name;
  final bool isOrganizer;

  const MeetingGuest({
    required this.email,
    this.name,
    this.isOrganizer = false,
  });

  factory MeetingGuest.fromMap(Map<String, dynamic> map) {
    return MeetingGuest(
      email: map['email'] ?? '',
      name: map['name'],
      isOrganizer: map['is_organizer'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'is_organizer': isOrganizer,
    };
  }
}

class Meeting {
  final String id;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final MeetingType type;
  MeetingStatus status;
  final String? leadId;
  final String? leadName;
  final List<MeetingGuest> guests;
  final String? meetLink;
  final String? location;
  final String? googleEventId;
  final String createdBy;
  final DateTime createdAt;
  DateTime? updatedAt;
  final String? organizerUid; // For calendar permission filtering
  final String? assignedTo; // User assigned to handle this meeting

  // Computed property for time range display
  String get timeRange {
    final startHour = startTime.hour.toString().padLeft(2, '0');
    final startMin = startTime.minute.toString().padLeft(2, '0');
    final endHour = endTime.hour.toString().padLeft(2, '0');
    final endMin = endTime.minute.toString().padLeft(2, '0');
    return '$startHour:$startMin - $endHour:$endMin';
  }

  Meeting({
    required this.id,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    required this.type,
    this.status = MeetingStatus.scheduled,
    this.leadId,
    this.leadName,
    this.guests = const [],
    this.meetLink,
    this.location,
    this.googleEventId,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.organizerUid,
    this.assignedTo,
  });

  factory Meeting.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Meeting(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'],
      startTime: (data['start_time'] as Timestamp).toDate(),
      endTime: (data['end_time'] as Timestamp).toDate(),
      type: MeetingTypeX.fromString(data['type'] ?? 'other'),
      status: MeetingStatusX.fromString(data['status'] ?? 'scheduled'),
      leadId: data['lead_id'],
      leadName: data['lead_name'],
      guests: (data['guests'] as List<dynamic>?)
              ?.map((g) => MeetingGuest.fromMap(g as Map<String, dynamic>))
              .toList() ??
          [],
      meetLink: data['meet_link'],
      location: data['location'],
      googleEventId: data['google_event_id'],
      createdBy: data['created_by'] ?? '',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate(),
      organizerUid: data['organizer_uid'] ?? data['created_by'],
      assignedTo: data['assigned_to'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'start_time': Timestamp.fromDate(startTime),
      'end_time': Timestamp.fromDate(endTime),
      'type': type.toSnakeCase(),
      'status': status.toSnakeCase(),
      'lead_id': leadId,
      'lead_name': leadName,
      'guests': guests.map((g) => g.toMap()).toList(),
      'meet_link': meetLink,
      'location': location,
      'google_event_id': googleEventId,
      'created_by': createdBy,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'organizer_uid': organizerUid ?? createdBy,
      'assigned_to': assignedTo,
    };
  }
}

class CalendarConfig {
  final String clientId;
  final String clientSecret;
  final String refreshToken;
  final String organizerEmail;
  final String organizerName;
  final String calendarId;
  final int defaultDuration;
  final String defaultTimeZone;
  final bool autoCreateMeetLink;
  final bool sendInvitations;

  const CalendarConfig({
    required this.clientId,
    required this.clientSecret,
    required this.refreshToken,
    required this.organizerEmail,
    required this.organizerName,
    this.calendarId = 'primary',
    this.defaultDuration = 30,
    this.defaultTimeZone = 'Asia/Kolkata',
    this.autoCreateMeetLink = true,
    this.sendInvitations = true,
  });

  factory CalendarConfig.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CalendarConfig(
      clientId: data['client_id'] ?? '',
      clientSecret: data['client_secret'] ?? '',
      refreshToken: data['refresh_token'] ?? '',
      organizerEmail: data['organizer_email'] ?? '',
      organizerName: data['organizer_name'] ?? '',
      calendarId: data['calendar_id'] ?? 'primary',
      defaultDuration: data['default_duration'] ?? 30,
      defaultTimeZone: data['default_timezone'] ?? 'Asia/Kolkata',
      autoCreateMeetLink: data['auto_create_meet_link'] ?? true,
      sendInvitations: data['send_invitations'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'client_id': clientId,
      'client_secret': clientSecret,
      'refresh_token': refreshToken,
      'organizer_email': organizerEmail,
      'organizer_name': organizerName,
      'calendar_id': calendarId,
      'default_duration': defaultDuration,
      'default_timezone': defaultTimeZone,
      'auto_create_meet_link': autoCreateMeetLink,
      'send_invitations': sendInvitations,
    };
  }
}
