// lib/models/user_model.dart
class UserModel {
  final String userId;
  final String name;
  final String username;
  final String role;
  final String team;
  final String? password; // Only stored in admin actions, never exposed in UI

  UserModel({
    required this.userId,
    required this.name,
    required this.username,
    required this.role,
    this.team = '',
    this.password,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      userId: id,
      name: map['name'] ?? '',
      username: map['username'] ?? '',
      role: map['role'] ?? 'sales',
      team: map['team'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'username': username,
      'role': role,
      'team': team,
      if (password != null) 'password': password,
    };
  }

  UserModel copyWith({
    String? userId,
    String? name,
    String? username,
    String? role,
    String? team,
    String? password,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      username: username ?? this.username,
      role: role ?? this.role,
      team: team ?? this.team,
      password: password ?? this.password,
    );
  }

  bool get isAdmin => role == 'superadmin';
  bool get isSales => role == 'sales';
  bool get isTeamLeader => role == 'teamleader';
  bool get isWriter => role == 'writer';
  bool get canViewLeads => isSales || isAdmin;
  bool get canViewDeals => isSales || isAdmin || isTeamLeader;
  bool get canDelete => isAdmin;
  bool get canExport => isAdmin;
}
