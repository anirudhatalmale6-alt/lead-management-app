import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Seed 100 demo leads with history logs for testing
class DemoDataSeeder {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Random _random = Random();

  // Sample data for generating random leads
  final List<String> _firstNames = [
    'Rahul', 'Priya', 'Amit', 'Sneha', 'Vikram', 'Neha', 'Rohan', 'Ananya',
    'Arjun', 'Kavya', 'Sanjay', 'Deepika', 'Rajesh', 'Meera', 'Aditya',
    'Pooja', 'Karan', 'Shruti', 'Nikhil', 'Divya', 'Varun', 'Ritu',
    'Akash', 'Swati', 'Manish', 'Anjali', 'Gaurav', 'Nisha', 'Vishal', 'Komal',
    'Suresh', 'Rekha', 'Mukesh', 'Geeta', 'Dinesh', 'Sunita', 'Prakash', 'Usha',
    'Mohan', 'Lakshmi', 'Ajay', 'Radha', 'Vijay', 'Shanti', 'Ramesh', 'Sita',
    'Mahesh', 'Gita', 'Sunil', 'Kamla'
  ];

  final List<String> _lastNames = [
    'Sharma', 'Patel', 'Singh', 'Kumar', 'Gupta', 'Verma', 'Jain', 'Agarwal',
    'Chopra', 'Malhotra', 'Kapoor', 'Mehta', 'Shah', 'Reddy', 'Rao',
    'Iyer', 'Nair', 'Pillai', 'Menon', 'Das', 'Bose', 'Sen', 'Roy',
    'Chakraborty', 'Banerjee', 'Mukherjee', 'Ghosh', 'Sinha', 'Mishra', 'Pandey'
  ];

  final List<String> _businessNames = [
    'Tech Solutions Pvt Ltd', 'Digital Services India', 'Cloud Systems Corp',
    'WebDev Studios', 'Mobile App Labs', 'Data Analytics Pro', 'Soft Tech Solutions',
    'InfoTech Systems', 'Cyber Solutions', 'NetWorks India', 'ERP Solutions',
    'CRM Experts', 'Business Automation', 'Smart Technologies', 'Innovation Hub',
    'TechnoSoft', 'Digital Dreams', 'CodeCraft', 'ByteWise', 'PixelPerfect',
    'DataDriven', 'CloudNine Tech', 'AgileWorks', 'DevOps Pro', 'AI Solutions',
    'ML Technologies', 'Blockchain Labs', 'IoT Innovations', 'StartUp Hub', 'Growth Hackers'
  ];

  final List<String> _cities = [
    'Mumbai', 'Delhi', 'Bangalore', 'Hyderabad', 'Chennai', 'Kolkata', 'Pune',
    'Ahmedabad', 'Jaipur', 'Lucknow', 'Chandigarh', 'Noida', 'Gurgaon',
    'Indore', 'Bhopal', 'Nagpur', 'Surat', 'Vadodara', 'Coimbatore', 'Kochi'
  ];

  final List<String> _states = [
    'Maharashtra', 'Delhi', 'Karnataka', 'Telangana', 'Tamil Nadu', 'West Bengal',
    'Gujarat', 'Rajasthan', 'Uttar Pradesh', 'Punjab', 'Haryana', 'Madhya Pradesh',
    'Andhra Pradesh', 'Kerala', 'Bihar'
  ];

  // Product/Service enum names (must match ProductService enum in lead.dart)
  final List<String> _products = [
    'cityFinSolBusinessListing',
    'cityFinSolWebCrmApps',
    'cityFinSolLeadsPackage',
    'customWebsiteApp',
    'customerSoftwareCrmErpCms',
    'digitalMarketing',
    'education',
    'ecommerce',
    'webSite',
    'mobileApp',
    'others',
  ];

  // Stage enum names (must match LeadStage enum in lead.dart)
  final List<String> _stageLabels = [
    'newLead', 'contacted', 'demoScheduled', 'demoCompleted',
    'proposalSent', 'negotiation', 'won', 'lost'
  ];

  final List<String> _healthLabels = ['hot', 'warm', 'solo', 'sleeping', 'dead', 'junk'];
  final List<String> _activityLabels = ['idle', 'working', 'followUpDue', 'reOpened', 'closed'];
  final List<String> _paymentLabels = ['free', 'supported', 'pending', 'partiallyPaid', 'fullyPaid'];
  final List<String> _meetingAgendas = ['demo', 'query', 'requirement', 'others', 'none'];

  String _randomElement<T>(List<T> list) => list[_random.nextInt(list.length)] as String;
  int _randomInt(int min, int max) => min + _random.nextInt(max - min);

  /// Generate a random phone number
  String _randomPhone() {
    return '${7 + _random.nextInt(3)}${_random.nextInt(900000000) + 100000000}';
  }

  /// Seed 100 demo leads
  Future<void> seedLeads({int count = 100, String createdBy = 'demo@example.com'}) async {
    final now = DateTime.now();
    final List<String> createdLeadIds = [];

    // Create leads in batches of 20
    for (int batchStart = 0; batchStart < count; batchStart += 20) {
      final batch = _firestore.batch();
      final batchEnd = (batchStart + 20 > count) ? count : batchStart + 20;
      final List<Map<String, dynamic>> leadsInBatch = [];

      for (int i = batchStart; i < batchEnd; i++) {
        final firstName = _randomElement(_firstNames);
        final lastName = _randomElement(_lastNames);
        final clientName = '$firstName $lastName';
        final email = '${firstName.toLowerCase()}.${lastName.toLowerCase()}${_random.nextInt(100)}@gmail.com';
        final phone = _randomPhone();
        final city = _randomElement(_cities);
        final state = _randomElement(_states);

        // Random dates within last 90 days
        final createdAt = now.subtract(Duration(days: _randomInt(1, 90)));
        final updatedAt = createdAt.add(Duration(days: _randomInt(0, 30)));

        // Random follow-up date
        DateTime? nextFollowUpDate;
        if (_random.nextBool()) {
          nextFollowUpDate = now.add(Duration(days: _randomInt(-5, 15)));
        }

        // Random meeting date
        DateTime? meetingDate;
        if (_random.nextDouble() < 0.3) {
          meetingDate = now.add(Duration(days: _randomInt(-10, 20)));
        }

        final docRef = _firestore.collection('leads').doc();

        final leadData = {
          'client_name': clientName,
          'client_business_name': _random.nextBool() ? _randomElement(_businessNames) : '',
          'client_mobile': phone,
          'client_whatsapp': _random.nextBool() ? phone : '',
          'client_email': email,
          'country': 'India',
          'state': state,
          'client_city': city,
          'stage': _randomElement(_stageLabels),
          'health': _randomElement(_healthLabels),
          'activity_state': _randomElement(_activityLabels),
          'payment_status': _randomElement(_paymentLabels),
          'interested_in_product': _randomElement(_products),
          'rating': _randomInt(10, 100),
          'meeting_agenda': _randomElement(_meetingAgendas),
          'meeting_date': meetingDate != null ? Timestamp.fromDate(meetingDate) : null,
          'meeting_time': meetingDate != null ? '${_randomInt(9, 18)}:${_random.nextBool() ? '00' : '30'}' : '',
          'meeting_link': meetingDate != null && _random.nextBool() ? 'https://meet.google.com/abc-defg-hij' : '',
          'last_call_date': _random.nextBool() ? Timestamp.fromDate(createdAt.add(Duration(days: _randomInt(1, 10)))) : null,
          'next_follow_up_date': nextFollowUpDate != null ? Timestamp.fromDate(nextFollowUpDate) : null,
          'next_follow_up_time': nextFollowUpDate != null ? '${_randomInt(9, 18)}:00' : '',
          'notes': _random.nextBool() ? 'Demo lead created for testing purposes. ${_randomElement(['Good prospect', 'Needs follow-up', 'Interested in premium plan', 'Budget concerns', 'Decision maker'])}.' : '',
          'comment': _random.nextBool() ? _randomElement(['Call back later', 'Interested', 'Needs more info', 'Waiting for approval', 'Ready to close']) : '',
          'submitter_name': '${_randomElement(_firstNames)} ${_randomElement(_lastNames)}',
          'submitter_email': 'submitter@example.com',
          'submitter_mobile': _randomPhone(),
          'group_name': _randomElement(['Sales', 'Marketing', 'Support', 'Enterprise', 'SMB']),
          'sub_group': _randomElement(['Team A', 'Team B', 'Team C', '']),
          'created_at': Timestamp.fromDate(createdAt),
          'updated_at': Timestamp.fromDate(updatedAt),
          'created_by': createdBy,
          'last_updated_by': createdBy,
        };

        batch.set(docRef, leadData);
        leadsInBatch.add({
          'id': docRef.id,
          'createdAt': createdAt,
          'updatedAt': updatedAt,
        });
      }

      // Commit this batch of leads
      await batch.commit();

      // Store lead IDs for history creation
      for (final lead in leadsInBatch) {
        createdLeadIds.add(lead['id']);
      }

      print('Created ${batchEnd} leads...');
    }

    // Now add history for all leads
    print('Adding history logs for leads...');
    for (int i = 0; i < createdLeadIds.length; i++) {
      final leadId = createdLeadIds[i];
      final createdAt = now.subtract(Duration(days: _randomInt(1, 90)));
      final updatedAt = createdAt.add(Duration(days: _randomInt(0, 30)));
      await _addHistoryForLead(leadId, createdAt, updatedAt, createdBy);

      if ((i + 1) % 20 == 0) {
        print('Added history for ${i + 1} leads...');
      }
    }

    print('Created $count demo leads successfully!');
  }

  /// Add random history entries for a lead
  Future<void> _addHistoryForLead(String leadId, DateTime createdAt, DateTime updatedAt, String updatedBy) async {
    final historyCount = _randomInt(2, 6);
    final batch = _firestore.batch();

    for (int i = 0; i < historyCount; i++) {
      final historyRef = _firestore.collection('leads').doc(leadId).collection('history').doc();

      final daysRange = updatedAt.difference(createdAt).inDays;
      final historyDate = createdAt.add(Duration(days: daysRange > 0 ? _randomInt(0, daysRange + 1) : 0));

      final historyTypes = [
        {
          'comment': 'Lead created',
          'changed_fields': {'stage': {'old': '', 'new': 'New Lead'}}
        },
        {
          'comment': 'Stage updated',
          'changed_fields': {'stage': {'old': 'New Lead', 'new': _randomElement(_stageLabels)}}
        },
        {
          'comment': 'Follow-up scheduled',
          'changed_fields': {'next_follow_up_date': {'old': '', 'new': '${historyDate.day}/${historyDate.month}/${historyDate.year}'}}
        },
        {
          'comment': 'Health status changed',
          'changed_fields': {'health': {'old': _randomElement(_healthLabels), 'new': _randomElement(_healthLabels)}}
        },
        {
          'comment': 'Meeting scheduled',
          'changed_fields': {'meeting_scheduled': {'old': '', 'new': 'Demo on ${historyDate.day}/${historyDate.month}/${historyDate.year}'}}
        },
        {
          'comment': 'Notes updated',
          'changed_fields': {'notes': {'old': '', 'new': 'Updated notes for the lead'}}
        },
        {
          'comment': 'Payment status updated',
          'changed_fields': {'payment_status': {'old': 'Pending', 'new': _randomElement(_paymentLabels)}}
        },
        {
          'comment': 'Rating updated',
          'changed_fields': {'rating': {'old': '${_randomInt(10, 50)}', 'new': '${_randomInt(50, 100)}'}}
        },
      ];

      final historyType = historyTypes[_random.nextInt(historyTypes.length)];

      batch.set(historyRef, {
        'lead_id': leadId,
        'updated_by': updatedBy,
        'updated_at': Timestamp.fromDate(historyDate),
        'comment': historyType['comment'],
        'changed_fields': historyType['changed_fields'],
      });
    }

    await batch.commit();
  }

  /// Seed business categories and email templates
  Future<void> seedEmailTemplates() async {
    // Define categories with their templates
    final categoriesAndTemplates = {
      'CityFinSol Services': [
        {
          'name': 'Welcome Email',
          'type': 'welcome',
          'subject': 'Welcome to CityFinSol - {{client_name}}!',
          'body': '''Dear {{client_name}},

Welcome to CityFinSol! We're thrilled to have you join our community.

Thank you for choosing our {{product_name}} service. Our team is dedicated to helping your business {{business_name}} grow and succeed.

Here's what happens next:
1. Our team will reach out to schedule an onboarding call
2. You'll receive access to your dashboard
3. We'll help you set up your first campaign

If you have any questions, feel free to reach out to us anytime.

Best regards,
The CityFinSol Team'''
        },
        {
          'name': 'Follow-up Email',
          'type': 'follow_up',
          'subject': 'Following up on our conversation - {{client_name}}',
          'body': '''Hi {{client_name}},

I hope this email finds you well! I wanted to follow up on our recent conversation about {{product_name}}.

I understand you had some questions about our services and I'd be happy to address them.

Would you be available for a quick call on {{meeting_date}} at {{meeting_time}}?

Looking forward to hearing from you.

Best regards,
{{submitter_name}}'''
        },
        {
          'name': 'Demo Confirmation',
          'type': 'demo_scheduled',
          'subject': 'Your Demo is Confirmed - {{meeting_date}}',
          'body': '''Dear {{client_name}},

This is to confirm your demo scheduled for:

Date: {{meeting_date}}
Time: {{meeting_time}}
Meeting Link: {{meeting_link}}

During the demo, we'll walk you through:
- Key features of {{product_name}}
- How it can benefit {{business_name}}
- Pricing and packages
- Q&A session

Please make sure to join a few minutes early to test your audio/video.

See you there!

Best regards,
The CityFinSol Team'''
        },
      ],
      'SaaS Products': [
        {
          'name': 'Product Introduction',
          'type': 'introduction',
          'subject': 'Introducing Our SaaS Solution for {{business_name}}',
          'body': '''Dear {{client_name}},

I hope this message finds you well. I'm reaching out because I believe our SaaS solution could significantly benefit {{business_name}}.

Our platform offers:
- Cloud-based CRM/ERP solutions
- Custom web and mobile applications
- Seamless integrations
- 24/7 support

I'd love to schedule a quick call to discuss how we can help streamline your operations.

Would {{next_follow_up}} work for a 15-minute discovery call?

Best regards,
{{submitter_name}}'''
        },
        {
          'name': 'Proposal Email',
          'type': 'proposal_sent',
          'subject': 'Your Custom Proposal - {{business_name}}',
          'body': '''Dear {{client_name}},

Thank you for your interest in our services. As discussed, please find below our proposal tailored for {{business_name}}.

Based on your requirements for {{product_name}}, we recommend:

[Proposal Details Here]

The total investment for this package would be customized based on your specific needs.

I'm available to discuss this proposal at your convenience. Please feel free to reach out with any questions.

Best regards,
{{submitter_name}}'''
        },
      ],
      'Digital Marketing': [
        {
          'name': 'SEO Audit Report',
          'type': 'report',
          'subject': 'Your SEO Audit Report - {{business_name}}',
          'body': '''Dear {{client_name}},

Thank you for requesting an SEO audit for {{business_name}}.

Our initial analysis reveals several opportunities to improve your online presence:

1. Technical SEO improvements needed
2. Content optimization recommendations
3. Backlink opportunities identified
4. Local SEO enhancements

I'd love to walk you through these findings in detail. Would you be available for a call on {{meeting_date}}?

Best regards,
{{submitter_name}}'''
        },
        {
          'name': 'Campaign Update',
          'type': 'update',
          'subject': 'Monthly Campaign Update - {{business_name}}',
          'body': '''Dear {{client_name}},

Here's your monthly digital marketing update for {{business_name}}:

Highlights:
- Traffic increased by X%
- Lead generation improved
- Social engagement metrics up
- PPC campaign performance

Next steps:
- Optimize underperforming campaigns
- Launch new content strategy
- Enhance social media presence

Let me know if you'd like to discuss these results in detail.

Best regards,
{{submitter_name}}'''
        },
      ],
      'Custom Development': [
        {
          'name': 'Project Kickoff',
          'type': 'kickoff',
          'subject': 'Project Kickoff - {{business_name}} Custom Development',
          'body': '''Dear {{client_name}},

We're excited to kick off your custom development project for {{business_name}}!

Project Timeline:
- Discovery Phase: Week 1-2
- Design Phase: Week 3-4
- Development Phase: Week 5-10
- Testing & QA: Week 11-12
- Launch: Week 13

Your dedicated project manager will be in touch to schedule the kickoff meeting.

Next Steps:
1. Review the project scope document
2. Schedule kickoff meeting
3. Provide access to required resources

Looking forward to building something great together!

Best regards,
{{submitter_name}}'''
        },
        {
          'name': 'Milestone Update',
          'type': 'milestone',
          'subject': 'Project Milestone Completed - {{business_name}}',
          'body': '''Dear {{client_name}},

Great news! We've completed another milestone for your project.

Milestone: [Milestone Name]
Status: Completed
Deliverables: [List of deliverables]

Next milestone: [Next milestone name]
Expected completion: [Date]

Please review the deliverables and let us know your feedback.

Best regards,
{{submitter_name}}'''
        },
      ],
      'Education': [
        {
          'name': 'Course Enrollment',
          'type': 'enrollment',
          'subject': 'Welcome to Your Learning Journey - {{client_name}}',
          'body': '''Dear {{client_name}},

Congratulations on enrolling in our {{product_name}} program!

Your learning journey begins now. Here's what you need to know:

Course Start Date: [Date]
Duration: [Duration]
Schedule: [Schedule Details]
Access Link: [Platform Link]

Resources included:
- Video lectures
- Practice exercises
- Downloadable materials
- Certificate upon completion

If you have any questions, our support team is here to help.

Happy learning!

Best regards,
The Education Team'''
        },
        {
          'name': 'Course Completion',
          'type': 'completion',
          'subject': 'Congratulations on Completing Your Course!',
          'body': '''Dear {{client_name}},

Congratulations! You've successfully completed the {{product_name}} program!

We're proud of your dedication and hard work throughout this course.

Your certificate is now available for download from your dashboard.

What's next?
- Share your achievement on LinkedIn
- Explore our advanced courses
- Join our alumni network

Thank you for learning with us. We wish you all the best in your future endeavors!

Best regards,
The Education Team'''
        },
      ],
      'General Communication': [
        {
          'name': 'Thank You Email',
          'type': 'thank_you',
          'subject': 'Thank You for Your Time - {{client_name}}',
          'body': '''Dear {{client_name}},

Thank you for taking the time to speak with us today.

It was great learning more about {{business_name}} and understanding your requirements for {{product_name}}.

As discussed, here are the next steps:
1. [Next step 1]
2. [Next step 2]
3. [Next step 3]

Please don't hesitate to reach out if you have any questions.

Best regards,
{{submitter_name}}'''
        },
        {
          'name': 'Meeting Reminder',
          'type': 'reminder',
          'subject': 'Reminder: Meeting Tomorrow - {{client_name}}',
          'body': '''Dear {{client_name}},

This is a friendly reminder about your meeting scheduled for:

Date: {{meeting_date}}
Time: {{meeting_time}}
Meeting Link: {{meeting_link}}

Agenda:
- Discussion on {{product_name}}
- Review requirements
- Next steps

See you tomorrow!

Best regards,
{{submitter_name}}'''
        },
        {
          'name': 'Re-engagement Email',
          'type': 're_engagement',
          'subject': 'We Miss You, {{client_name}}!',
          'body': '''Dear {{client_name}},

It's been a while since we last connected, and I wanted to check in.

At CityFinSol, we're constantly improving our services to better serve businesses like {{business_name}}.

Some updates you might have missed:
- New features launched
- Improved pricing options
- Enhanced support services

I'd love to reconnect and explore how we can help you achieve your goals.

Would you be open to a brief call next week?

Best regards,
{{submitter_name}}'''
        },
      ],
    };

    // Create categories and templates one by one
    for (final entry in categoriesAndTemplates.entries) {
      final categoryName = entry.key;
      final templates = entry.value;

      // Create category
      final categoryRef = await _firestore.collection('business_categories').add({
        'name': categoryName,
        'created_at': FieldValue.serverTimestamp(),
      });

      // Create templates for this category
      for (final template in templates) {
        await _firestore.collection('email_templates').add({
          'category_id': categoryRef.id,
          'name': template['name'],
          'type': template['type'],
          'subject': template['subject'],
          'body': template['body'],
          'created_at': FieldValue.serverTimestamp(),
        });
      }

      print('Created category: $categoryName with ${templates.length} templates');
    }

    print('Created ${categoriesAndTemplates.length} categories with templates!');
  }

  /// Run all seeding operations
  Future<void> seedAll({String createdBy = 'demo@example.com'}) async {
    print('Starting data seeding...');
    await seedLeads(count: 100, createdBy: createdBy);
    await seedEmailTemplates();
    print('Data seeding completed!');
  }
}
