import 'package:cloud_firestore/cloud_firestore.dart';

// ---------------------------------------------------------------------------
// Enums matching client's Excel template exactly
// ---------------------------------------------------------------------------

enum LeadHealth { hot, warm, solo, sleeping, dead, junk }

extension LeadHealthX on LeadHealth {
  String get label {
    switch (this) {
      case LeadHealth.hot:
        return 'Hot';
      case LeadHealth.warm:
        return 'Warm';
      case LeadHealth.solo:
        return 'Solo';
      case LeadHealth.sleeping:
        return 'Sleeping';
      case LeadHealth.dead:
        return 'Dead';
      case LeadHealth.junk:
        return 'Junk';
    }
  }
}

enum LeadStage {
  newLead,
  contacted,
  demoScheduled,
  demoCompleted,
  proposalSent,
  negotiation,
  won,
  lost,
}

extension LeadStageX on LeadStage {
  String get label {
    switch (this) {
      case LeadStage.newLead:
        return 'New Lead';
      case LeadStage.contacted:
        return 'Contacted';
      case LeadStage.demoScheduled:
        return 'Demo Scheduled';
      case LeadStage.demoCompleted:
        return 'Demo Completed';
      case LeadStage.proposalSent:
        return 'Proposal Sent';
      case LeadStage.negotiation:
        return 'Negotiation';
      case LeadStage.won:
        return 'Won';
      case LeadStage.lost:
        return 'Lost';
    }
  }
}

enum ActivityState { idle, working, followUpDue, reOpened, closed }

extension ActivityStateX on ActivityState {
  String get label {
    switch (this) {
      case ActivityState.idle:
        return 'Idle';
      case ActivityState.working:
        return 'Working';
      case ActivityState.followUpDue:
        return 'Follow-up Due';
      case ActivityState.reOpened:
        return 'Re-opened';
      case ActivityState.closed:
        return 'Closed';
    }
  }
}

enum PaymentStatus { free, supported, pending, partiallyPaid, fullyPaid }

extension PaymentStatusX on PaymentStatus {
  String get label {
    switch (this) {
      case PaymentStatus.free:
        return 'Free';
      case PaymentStatus.supported:
        return 'Supported';
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.partiallyPaid:
        return 'Partially Paid';
      case PaymentStatus.fullyPaid:
        return 'Fully Paid';
    }
  }
}

enum ProductService {
  cityFinSolBusinessListing,
  cityFinSolWebCrmApps,
  cityFinSolLeadsPackage,
  customWebsiteApp,
  customerSoftwareCrmErpCms,
  digitalMarketing,
  education,
  ecommerce,
  webSite,
  mobileApp,
  others,
}

extension ProductServiceX on ProductService {
  String get label {
    switch (this) {
      case ProductService.cityFinSolBusinessListing:
        return 'CityFinSol Business Listing';
      case ProductService.cityFinSolWebCrmApps:
        return 'CityFinSol Web, CRM & Apps';
      case ProductService.cityFinSolLeadsPackage:
        return 'CityFinSol Leads Package';
      case ProductService.customWebsiteApp:
        return 'Custom Website & App';
      case ProductService.customerSoftwareCrmErpCms:
        return 'Customer Software CRM/ERP CMS';
      case ProductService.digitalMarketing:
        return 'Digital Marketing - SEO, Social or PPC';
      case ProductService.education:
        return 'Education';
      case ProductService.ecommerce:
        return 'Ecommerce';
      case ProductService.webSite:
        return 'Web Site';
      case ProductService.mobileApp:
        return 'Mobile App';
      case ProductService.others:
        return 'Others';
    }
  }
}

enum MeetingAgenda { demo, query, requirement, others }

extension MeetingAgendaX on MeetingAgenda {
  String get label {
    switch (this) {
      case MeetingAgenda.demo:
        return 'Demo';
      case MeetingAgenda.query:
        return 'Query';
      case MeetingAgenda.requirement:
        return 'Requirement';
      case MeetingAgenda.others:
        return 'Others';
    }
  }
}

// ---------------------------------------------------------------------------
// Lead model
// ---------------------------------------------------------------------------

class Lead {
  // Auto-generated fields
  String id;
  DateTime createdAt;
  DateTime updatedAt;
  String lastUpdatedBy;

  // Meeting
  String meetingLink;
  MeetingAgenda meetingAgenda;
  DateTime? meetingDate;
  String meetingTime;

  // Follow-up & Activity
  DateTime? lastCallDate;
  DateTime? nextFollowUpDate;
  String nextFollowUpTime;
  String comment;

  // Status fields (dropdowns)
  int rating; // 10, 20, 30, ... 90
  LeadHealth health;
  LeadStage stage;
  ActivityState activityState;
  PaymentStatus paymentStatus;

  // Product/Service
  ProductService interestedInProduct;

  // Client info
  String clientBusinessName;
  String clientName;
  String clientWhatsApp;
  String clientMobile;
  String clientEmail;
  String country;
  String state;
  String clientCity;
  String notes;

  // Submitter info
  String submitterName;
  String submitterEmail;
  String submitterMobile;
  String groupName;
  String subGroup;

  // Internal
  String ownerUid;
  String teamId;
  String groupId;
  String createdBy;

  Lead({
    required this.id,
    required this.clientName,
    this.clientBusinessName = '',
    this.clientWhatsApp = '',
    this.clientMobile = '',
    this.clientEmail = '',
    this.country = '',
    this.state = '',
    this.clientCity = '',
    this.notes = '',
    this.meetingLink = '',
    this.meetingAgenda = MeetingAgenda.demo,
    this.meetingDate,
    this.meetingTime = '',
    this.lastCallDate,
    this.nextFollowUpDate,
    this.nextFollowUpTime = '',
    this.comment = '',
    this.rating = 10,
    this.health = LeadHealth.warm,
    this.stage = LeadStage.newLead,
    this.activityState = ActivityState.idle,
    this.paymentStatus = PaymentStatus.free,
    this.interestedInProduct = ProductService.others,
    this.submitterName = '',
    this.submitterEmail = '',
    this.submitterMobile = '',
    this.groupName = '',
    this.subGroup = '',
    this.ownerUid = '',
    this.teamId = '',
    this.groupId = '',
    this.createdBy = '',
    this.lastUpdatedBy = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Lead.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Lead(
      id: doc.id,
      clientName: data['client_name'] ?? '',
      clientBusinessName: data['client_business_name'] ?? '',
      clientWhatsApp: data['client_whatsapp'] ?? '',
      clientMobile: data['client_mobile'] ?? '',
      clientEmail: data['client_email'] ?? '',
      country: data['country'] ?? '',
      state: data['state'] ?? '',
      clientCity: data['client_city'] ?? '',
      notes: data['notes'] ?? '',
      meetingLink: data['meeting_link'] ?? '',
      meetingAgenda: _parseEnum(
          data['meeting_agenda'], MeetingAgenda.values, MeetingAgenda.demo),
      meetingDate: _parseTimestamp(data['meeting_date']),
      meetingTime: data['meeting_time'] ?? '',
      lastCallDate: _parseTimestamp(data['last_call_date']),
      nextFollowUpDate: _parseTimestamp(data['next_follow_up_date']),
      nextFollowUpTime: data['next_follow_up_time'] ?? '',
      comment: data['comment'] ?? '',
      rating: _parseInt(data['rating'], 10),
      health:
          _parseEnum(data['health'], LeadHealth.values, LeadHealth.warm),
      stage:
          _parseEnum(data['stage'], LeadStage.values, LeadStage.newLead),
      activityState: _parseEnum(
          data['activity_state'], ActivityState.values, ActivityState.idle),
      paymentStatus: _parseEnum(
          data['payment_status'], PaymentStatus.values, PaymentStatus.free),
      interestedInProduct: _parseEnum(data['interested_in_product'],
          ProductService.values, ProductService.others),
      submitterName: data['submitter_name'] ?? '',
      submitterEmail: data['submitter_email'] ?? '',
      submitterMobile: data['submitter_mobile'] ?? '',
      groupName: data['group_name'] ?? '',
      subGroup: data['sub_group'] ?? '',
      ownerUid: data['owner_uid'] ?? '',
      teamId: data['team_id'] ?? '',
      groupId: data['group_id'] ?? '',
      createdBy: data['created_by'] ?? '',
      lastUpdatedBy: data['last_updated_by'] ?? '',
      createdAt: _parseTimestamp(data['created_at']) ?? DateTime.now(),
      updatedAt: _parseTimestamp(data['updated_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'client_name': clientName,
      'client_business_name': clientBusinessName,
      'client_whatsapp': clientWhatsApp,
      'client_mobile': clientMobile,
      'client_email': clientEmail,
      'country': country,
      'state': state,
      'client_city': clientCity,
      'notes': notes,
      'meeting_link': meetingLink,
      'meeting_agenda': meetingAgenda.name,
      'meeting_date':
          meetingDate != null ? Timestamp.fromDate(meetingDate!) : null,
      'meeting_time': meetingTime,
      'last_call_date':
          lastCallDate != null ? Timestamp.fromDate(lastCallDate!) : null,
      'next_follow_up_date': nextFollowUpDate != null
          ? Timestamp.fromDate(nextFollowUpDate!)
          : null,
      'next_follow_up_time': nextFollowUpTime,
      'comment': comment,
      'rating': rating,
      'health': health.name,
      'stage': stage.name,
      'activity_state': activityState.name,
      'payment_status': paymentStatus.name,
      'interested_in_product': interestedInProduct.name,
      'submitter_name': submitterName,
      'submitter_email': submitterEmail,
      'submitter_mobile': submitterMobile,
      'group_name': groupName,
      'sub_group': subGroup,
      'owner_uid': ownerUid,
      'team_id': teamId,
      'group_id': groupId,
      'created_by': createdBy,
      'last_updated_by': lastUpdatedBy,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  // ---------------------------------------------------------------------------
  // Parsing helpers
  // ---------------------------------------------------------------------------

  static T _parseEnum<T extends Enum>(
      dynamic value, List<T> values, T fallback) {
    if (value == null) return fallback;
    final str = value.toString();
    return values.firstWhere((e) => e.name == str, orElse: () => fallback);
  }

  static int _parseInt(dynamic value, int fallback) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    return null;
  }
}
