// lib/models/notification_model.dart
class NotificationModel {
  final String id;
  final String icon;
  final String type;
  final String taskId;
  final String message;
  final String time;
  final int priority;

  NotificationModel({
    required this.id,
    required this.icon,
    required this.type,
    required this.taskId,
    required this.message,
    required this.time,
    required this.priority,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] ?? '',
      icon: map['icon'] ?? '🔔',
      type: map['type'] ?? '',
      taskId: map['taskId'] ?? '',
      message: map['msg'] ?? '',
      time: map['time'] ?? '',
      priority: map['priority'] ?? 9,
    );
  }
}
