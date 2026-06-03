// lib/models/deal_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/utils/date_utils.dart';

class DealModel {
  final String id;
  final String taskCode;
  final String date;
  final String salesId;
  final String salesName;
  final String team;
  final String clientName;
  final String wordCount;
  final String totalDealValue;
  final String payment1st;
  final String payment2nd;
  final String paymentStatus;
  final String assignStatus;
  final String writerAssigned;
  final String writerTaskId;
  final String notes;
  final String salesFileLink;
  final String paymentScreenshot;
  final String clientProfileLink;
  final String whatsappNumber;
  final String salesTaskId;      // ← ADD THIS
  final DateTime? createdAt;

  DealModel({
    required this.id,
    required this.taskCode,
    required this.date,
    required this.salesId,
    required this.salesName,
    required this.team,
    required this.clientName,
    required this.wordCount,
    required this.totalDealValue,
    required this.payment1st,
    required this.payment2nd,
    required this.paymentStatus,
    this.assignStatus = 'Open',
    this.writerAssigned = '',
    this.writerTaskId = '',
    this.notes = '',
    this.salesFileLink = '',
    this.paymentScreenshot = '',
    this.clientProfileLink = '',
    this.whatsappNumber = '',
    this.salesTaskId = '',       // ← ADD THIS
    this.createdAt,
  });

  factory DealModel.fromMap(Map<String, dynamic> map, String id) {
    return DealModel(
      id: id,
      taskCode: map['taskCode']?.toString() ?? id,
      date: map['date']?.toString() ?? '',
      salesId: map['salesId']?.toString() ?? '',
      salesName: map['salesName']?.toString() ?? '',
      team: map['team']?.toString() ?? '',
      clientName: map['clientName']?.toString() ?? '',
      wordCount: map['wordCount']?.toString() ?? '',
      totalDealValue: map['totalDealValue']?.toString() ?? '',
      payment1st: map['payment1st']?.toString() ?? '',
      payment2nd: map['payment2nd']?.toString() ?? '',
      paymentStatus: map['paymentStatus']?.toString() ?? 'Pending',
      assignStatus: map['assignStatus']?.toString() ?? 'Open',
      writerAssigned: map['writerAssigned']?.toString() ?? '',
      writerTaskId: map['writerTaskId']?.toString() ?? '',
      notes: map['notes']?.toString() ?? '',
      salesFileLink: map['salesFileLink']?.toString() ?? '',
      paymentScreenshot: map['paymentScreenshot']?.toString() ?? '',
      clientProfileLink: map['clientProfileLink']?.toString() ?? '',
      whatsappNumber: map['whatsappNumber']?.toString() ?? '',
      salesTaskId: map['salesTaskId']?.toString() ?? '',   // ← ADD THIS
      createdAt: _parseDateTime(map['createdAt']),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'taskCode': taskCode,
      'date': date,
      'salesId': salesId,
      'salesName': salesName,
      'team': team,
      'clientName': clientName,
      'wordCount': wordCount,
      'totalDealValue': totalDealValue,
      'payment1st': payment1st,
      'payment2nd': payment2nd,
      'paymentStatus': paymentStatus,
      'assignStatus': assignStatus,
      'writerAssigned': writerAssigned,
      'writerTaskId': writerTaskId,
      'notes': notes,
      'salesFileLink': salesFileLink,
      'paymentScreenshot': paymentScreenshot,
      'clientProfileLink': clientProfileLink,
      'whatsappNumber': whatsappNumber,
      'salesTaskId': salesTaskId,    // ← ADD THIS
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  double get totalValue => double.tryParse(totalDealValue) ?? 0.0;

  DealModel copyWith({
    String? id,
    String? taskCode,
    String? date,
    String? salesId,
    String? salesName,
    String? team,
    String? clientName,
    String? wordCount,
    String? totalDealValue,
    String? payment1st,
    String? payment2nd,
    String? paymentStatus,
    String? assignStatus,
    String? writerAssigned,
    String? writerTaskId,
    String? notes,
    String? salesFileLink,
    String? paymentScreenshot,
    String? clientProfileLink,
    String? whatsappNumber,
    String? salesTaskId,           // ← ADD THIS
  }) {
    return DealModel(
      id: id ?? this.id,
      taskCode: taskCode ?? this.taskCode,
      date: date ?? this.date,
      salesId: salesId ?? this.salesId,
      salesName: salesName ?? this.salesName,
      team: team ?? this.team,
      clientName: clientName ?? this.clientName,
      wordCount: wordCount ?? this.wordCount,
      totalDealValue: totalDealValue ?? this.totalDealValue,
      payment1st: payment1st ?? this.payment1st,
      payment2nd: payment2nd ?? this.payment2nd,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      assignStatus: assignStatus ?? this.assignStatus,
      writerAssigned: writerAssigned ?? this.writerAssigned,
      writerTaskId: writerTaskId ?? this.writerTaskId,
      notes: notes ?? this.notes,
      salesFileLink: salesFileLink ?? this.salesFileLink,
      paymentScreenshot: paymentScreenshot ?? this.paymentScreenshot,
      clientProfileLink: clientProfileLink ?? this.clientProfileLink,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      salesTaskId: salesTaskId ?? this.salesTaskId,   // ← ADD THIS
    );
  }
}