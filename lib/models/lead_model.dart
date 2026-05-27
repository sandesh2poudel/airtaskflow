// lib/models/lead_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/utils/date_utils.dart';

class LeadModel {
  final String id;
  final String date;
  final String salesId;
  final String salesName;
  final String team;
  final String clientName;
  final String dealClosingStatus;
  final String subjectsTask;
  final String source;
  final String remarks;
  final String clientProfileLink;
  final String followupTextCall;
  final String whatsappNumber;
  final DateTime? createdAt;

  LeadModel({
    required this.id,
    required this.date,
    required this.salesId,
    required this.salesName,
    required this.team,
    required this.clientName,
    required this.dealClosingStatus,
    required this.subjectsTask,
    required this.source,
    required this.remarks,
    required this.clientProfileLink,
    required this.followupTextCall,
    required this.whatsappNumber,
    this.createdAt,
  });

  factory LeadModel.fromMap(Map<String, dynamic> map, String id) {
    return LeadModel(
      id: id,
      date: map['date']?.toString() ?? '',
      salesId: map['salesId']?.toString() ?? '',
      salesName: map['salesName']?.toString() ?? '',
      team: map['team']?.toString() ?? '',
      clientName: map['clientName']?.toString() ?? '',
      dealClosingStatus: map['dealClosingStatus']?.toString() ?? '',
      subjectsTask: map['subjectsTask']?.toString() ?? '',
      source: map['source']?.toString() ?? '',
      remarks: map['remarks']?.toString() ?? '',
      clientProfileLink: map['clientProfileLink']?.toString() ?? '',
      followupTextCall: map['followupTextCall']?.toString() ?? '',
      whatsappNumber: map['whatsappNumber']?.toString() ?? '',
      // Handle both Firestore Timestamp and ISO string
      createdAt: _parseDateTime(map['createdAt']),
    );
  }

  /// Handles Firestore Timestamp objects AND ISO string dates
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'salesId': salesId,
      'salesName': salesName,
      'team': team,
      'clientName': clientName,
      'dealClosingStatus': dealClosingStatus,
      'subjectsTask': subjectsTask,
      'source': source,
      'remarks': remarks,
      'clientProfileLink': clientProfileLink,
      'followupTextCall': followupTextCall,
      'whatsappNumber': whatsappNumber,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  LeadModel copyWith({
    String? id,
    String? date,
    String? salesId,
    String? salesName,
    String? team,
    String? clientName,
    String? dealClosingStatus,
    String? subjectsTask,
    String? source,
    String? remarks,
    String? clientProfileLink,
    String? followupTextCall,
    String? whatsappNumber,
  }) {
    return LeadModel(
      id: id ?? this.id,
      date: date ?? this.date,
      salesId: salesId ?? this.salesId,
      salesName: salesName ?? this.salesName,
      team: team ?? this.team,
      clientName: clientName ?? this.clientName,
      dealClosingStatus: dealClosingStatus ?? this.dealClosingStatus,
      subjectsTask: subjectsTask ?? this.subjectsTask,
      source: source ?? this.source,
      remarks: remarks ?? this.remarks,
      clientProfileLink: clientProfileLink ?? this.clientProfileLink,
      followupTextCall: followupTextCall ?? this.followupTextCall,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
    );
  }
}
