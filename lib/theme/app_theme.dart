import 'package:flutter/material.dart';

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF1A237E),
      brightness: Brightness.light,
    ),
    useMaterial3: true,
    cardTheme: CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
  );

  static Color stageColor(String stage) {
    switch (stage) {
      case 'New Lead':
        return Colors.blue;
      case 'Contacted':
        return Colors.cyan.shade700;
      case 'Demo Scheduled':
        return Colors.orange;
      case 'Demo Completed':
        return Colors.teal;
      case 'Proposal Sent':
        return Colors.purple;
      case 'Negotiation':
        return Colors.amber.shade800;
      case 'Won':
        return Colors.green;
      case 'Lost':
        return Colors.grey.shade600;
      default:
        return Colors.blueGrey;
    }
  }

  static Color healthColor(String health) {
    switch (health) {
      case 'Hot':
        return Colors.red;
      case 'Warm':
        return Colors.orange;
      case 'Solo':
        return Colors.blue;
      case 'Sleeping':
        return Colors.purple;
      case 'Dead':
        return Colors.grey;
      case 'Junk':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  static Color activityColor(String activity) {
    switch (activity) {
      case 'Idle':
        return Colors.grey;
      case 'Working':
        return Colors.blue;
      case 'Follow-up Due':
        return Colors.orange;
      case 'Re-opened':
        return Colors.purple;
      case 'Closed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  static Color paymentColor(String payment) {
    switch (payment) {
      case 'Free':
        return Colors.grey;
      case 'Supported':
        return Colors.blue;
      case 'Pending':
        return Colors.orange;
      case 'Partially Paid':
        return Colors.amber.shade800;
      case 'Fully Paid':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
