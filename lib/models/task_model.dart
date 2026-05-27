// lib/models/task_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/utils/date_utils.dart';

class TaskModel {
  final String taskId;
  final String dateAssigned;
  final String dealId;
  final String salesId;
  final String salesName;
  final String salesTeam; // ← NEW
  final String writerId;
  final String writerName;
  final String clientName;
  final String subject;
  final String assignmentType;
  final String wordCount;
  final String deadline;
  final String status;
  final String priority;
  final String notes;
  final String completedDate;
  final String fileLink;
  final String teamLeaderReviewed;
  final String forwardedToSales;
  final String salesFileLink;
  final String salesTaskId;
  final List<Map<String, dynamic>> comments;

  TaskModel({
    required this.taskId,
    required this.dateAssigned,
    required this.dealId,
    required this.salesId,
    required this.salesName,
    this.salesTeam = '', // ← NEW
    required this.writerId,
    required this.writerName,
    required this.clientName,
    required this.subject,
    required this.assignmentType,
    required this.wordCount,
    required this.deadline,
    required this.status,
    required this.priority,
    this.notes = '',
    this.completedDate = '',
    this.fileLink = '',
    this.teamLeaderReviewed = '',
    this.forwardedToSales = '',
    this.salesFileLink = '',
    this.salesTaskId = '',
    this.comments = const [],
  });

  factory TaskModel.fromMap(Map<String, dynamic> map, String id) {
    List<Map<String, dynamic>> commentsList = [];
    try {
      final raw = map['comments'];
      if (raw is List) {
        commentsList = raw
            .whereType<Map>()
            .map((c) => Map<String, dynamic>.from(c))
            .toList();
      }
    } catch (_) {}

    return TaskModel(
      taskId: id,
      dateAssigned: _parseStringDate(map['dateAssigned']),
      dealId: map['dealId']?.toString() ?? '',
      salesId: map['salesId']?.toString() ?? '',
      salesName: map['salesName']?.toString() ?? '',
      salesTeam: map['salesTeam']?.toString() ?? '', // ← NEW
      writerId: map['writerId']?.toString() ?? '',
      writerName: map['writerName']?.toString() ?? '',
      clientName: map['clientName']?.toString() ?? '',
      subject: map['subject']?.toString() ?? '',
      assignmentType: map['assignmentType']?.toString() ?? '',
      wordCount: map['wordCount']?.toString() ?? '',
      deadline: _parseStringDate(map['deadline']),
      status: map['status']?.toString() ?? 'Pending',
      priority: map['priority']?.toString() ?? 'Medium',
      notes: map['notes']?.toString() ?? '',
      completedDate: _parseStringDate(map['completedDate']),
      fileLink: map['fileLink']?.toString() ?? '',
      teamLeaderReviewed: map['teamLeaderReviewed']?.toString() ?? '',
      forwardedToSales: map['forwardedToSales']?.toString() ?? '',
      salesFileLink: map['salesFileLink']?.toString() ?? '',
      salesTaskId: map['salesTaskId']?.toString() ?? '',
      comments: commentsList,
    );
  }

  static String _parseStringDate(dynamic value) {
    if (value == null) return '';
    if (value is Timestamp) {
      return DateHelper.format(value.toDate());
    }
    if (value is String) return value;
    return '';
  }

  Map<String, dynamic> toMap() {
    return {
      'dateAssigned': dateAssigned,
      'dealId': dealId,
      'salesId': salesId,
      'salesName': salesName,
      'salesTeam': salesTeam, // ← NEW
      'writerId': writerId,
      'writerName': writerName,
      'clientName': clientName,
      'subject': subject,
      'assignmentType': assignmentType,
      'wordCount': wordCount,
      'deadline': deadline,
      'status': status,
      'priority': priority,
      'notes': notes,
      'completedDate': completedDate,
      'fileLink': fileLink,
      'teamLeaderReviewed': teamLeaderReviewed,
      'forwardedToSales': forwardedToSales,
      'salesFileLink': salesFileLink,
      'salesTaskId': salesTaskId,
      'comments': comments,
    };
  }

  int get daysLeft {
    if (deadline.isEmpty) return 999;
    final d = DateHelper.parse(deadline);
    if (d == null) return 999;
    return DateHelper.daysUntil(d);
  }

  bool get isOverdue => daysLeft < 0;
  bool get isDueToday => daysLeft == 0;
  bool get isCompleted =>
      status == 'Completed' ||
          status == 'Reviewed' ||
          status == 'Forwarded to Sales';

  TaskModel copyWith({
    String? taskId,
    String? dateAssigned,
    String? dealId,
    String? salesId,
    String? salesName,
    String? salesTeam, // ← NEW
    String? writerId,
    String? writerName,
    String? clientName,
    String? subject,
    String? assignmentType,
    String? wordCount,
    String? deadline,
    String? status,
    String? priority,
    String? notes,
    String? completedDate,
    String? fileLink,
    String? teamLeaderReviewed,
    String? forwardedToSales,
    String? salesFileLink,
    String? salesTaskId,
    List<Map<String, dynamic>>? comments,
  }) {
    return TaskModel(
      taskId: taskId ?? this.taskId,
      dateAssigned: dateAssigned ?? this.dateAssigned,
      dealId: dealId ?? this.dealId,
      salesId: salesId ?? this.salesId,
      salesName: salesName ?? this.salesName,
      salesTeam: salesTeam ?? this.salesTeam, // ← NEW
      writerId: writerId ?? this.writerId,
      writerName: writerName ?? this.writerName,
      clientName: clientName ?? this.clientName,
      subject: subject ?? this.subject,
      assignmentType: assignmentType ?? this.assignmentType,
      wordCount: wordCount ?? this.wordCount,
      deadline: deadline ?? this.deadline,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      notes: notes ?? this.notes,
      completedDate: completedDate ?? this.completedDate,
      fileLink: fileLink ?? this.fileLink,
      teamLeaderReviewed: teamLeaderReviewed ?? this.teamLeaderReviewed,
      forwardedToSales: forwardedToSales ?? this.forwardedToSales,
      salesFileLink: salesFileLink ?? this.salesFileLink,
      salesTaskId: salesTaskId ?? this.salesTaskId,
      comments: comments ?? this.comments,
    );
  }
}