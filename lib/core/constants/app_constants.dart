// lib/core/constants/app_constants.dart
class AppConstants {
  static const String appTitle = 'Air Task Flow';
  
  // Firestore collections
  static const String colUsers = 'users';
  static const String colLeads = 'leads';
  static const String colDeals = 'deals';
  static const String colTasks = 'writer_tasks';
  static const String colAudit = 'audit_log';
  static const String colNotifications = 'notifications';
  
  // Roles
  static const String roleSuperAdmin = 'superadmin';
  static const String roleSales = 'sales';
  static const String roleTeamLeader = 'teamleader';
  static const String roleWriter = 'writer';
  
  // Teams
  static const List<String> teams = ['Red', 'Yellow', 'Blue', 'Pink(CDR)'];
  
  // Payment statuses
  static const List<String> paymentStatuses = ['Pending', 'Partial', 'Paid'];
  
  // Lead statuses
  static const List<String> leadStatuses = [
    'In Talk', 'Interested', 'Follow Up', 'Closed', 'Not Interested'
  ];
  
  // Lead sources
  static const List<String> leadSources = [
    'Instagram', 'Facebook', 'WhatsApp', 'Email', 'Referral', 'Website', 'TikTok', 'Other'
  ];
  
  // Assignment types
  static const List<String> assignmentTypes = [
    'Essay', 'Case Study', 'Research Paper', 'Report', 'Assignment', 'Dissertation', 'Other'
  ];
  
  // Task statuses
  static const List<String> taskStatuses = [
    'Pending', 'In Progress', 'Completed', 'Reviewed', 'Forwarded to Sales'
  ];
  
  // Priorities
  static const List<String> priorities = ['High', 'Medium', 'Low'];
}
