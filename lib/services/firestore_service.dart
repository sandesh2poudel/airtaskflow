// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../models/user_model.dart';
import '../models/lead_model.dart';
import '../models/deal_model.dart';
import '../models/task_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ══════════════════════════════════════════
  // AUTH / USERS
  // ══════════════════════════════════════════

  Future<UserModel?> loginUser(String username, String password) async {
    try {
      final query = await _db
          .collection(AppConstants.colUsers)
          .where('username', isEqualTo: username.trim().toLowerCase())
          .get();

      if (query.docs.isEmpty) return null;

      for (final doc in query.docs) {
        final data = doc.data();
        if (data['password']?.toString().trim() == password.trim()) {
          return UserModel.fromMap(data, doc.id);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<UserModel>> getAllUsers() async {
    final snap = await _db.collection(AppConstants.colUsers).get();
    return snap.docs.map((d) => UserModel.fromMap(d.data(), d.id)).toList();
  }

  Future<List<UserModel>> getWriters() async {
    final snap = await _db
        .collection(AppConstants.colUsers)
        .where('role', isEqualTo: 'writer')
        .get();
    return snap.docs.map((d) => UserModel.fromMap(d.data(), d.id)).toList();
  }

  Future<String> addUser(UserModel user) async {
    final existing = await _db
        .collection(AppConstants.colUsers)
        .where('username', isEqualTo: user.username.toLowerCase())
        .get();
    if (existing.docs.isNotEmpty) throw Exception('Username already exists');
    final doc = await _db.collection(AppConstants.colUsers).add(user.toMap());
    await _logAudit('Admin', 'superadmin', 'Added user: ${user.username}', doc.id);
    return doc.id;
  }

  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    await _db.collection(AppConstants.colUsers).doc(userId).update(data);
    await _logAudit('Admin', 'superadmin', 'Updated user: $userId', userId);
  }

  Future<void> deleteUser(String userId) async {
    await _db.collection(AppConstants.colUsers).doc(userId).delete();
    await _logAudit('Admin', 'superadmin', 'Deleted user: $userId', userId);
  }

  // ══════════════════════════════════════════
  // LEADS
  // ══════════════════════════════════════════

  Stream<List<LeadModel>> leadsStream(UserModel user) {
    Query<Map<String, dynamic>> query = _db.collection(AppConstants.colLeads);

    if (user.isSales) {
      query = query.where('salesId', isEqualTo: user.userId);
    }

    return query.snapshots().map((snap) {
      final list = snap.docs
          .map((d) => LeadModel.fromMap(d.data(), d.id))
          .toList();
      list.sort((a, b) {
        final da = a.createdAt?.millisecondsSinceEpoch ??
            (DateTime.tryParse(a.date)?.millisecondsSinceEpoch ?? 0);
        final db2 = b.createdAt?.millisecondsSinceEpoch ??
            (DateTime.tryParse(b.date)?.millisecondsSinceEpoch ?? 0);
        return db2.compareTo(da);
      });
      return list;
    });
  }

  Future<String> addLead(LeadModel lead) async {
    final data = lead.toMap();
    data['createdAt'] = DateTime.now().toIso8601String();
    final doc = await _db.collection(AppConstants.colLeads).add(data);
    await _logAudit(
        lead.salesName, lead.salesId, 'Added lead: ${lead.clientName}', doc.id);
    return doc.id;
  }

  Future<void> updateLead(String id, Map<String, dynamic> data) async {
    await _db.collection(AppConstants.colLeads).doc(id).update(data);
  }

  Future<void> deleteLead(String id) async {
    await _db.collection(AppConstants.colLeads).doc(id).delete();
    await _logAudit('Admin', 'superadmin', 'Deleted lead: $id', id);
  }

  // ══════════════════════════════════════════
  // DEALS
  // ══════════════════════════════════════════

  Stream<List<DealModel>> dealsStream(UserModel user) {
    Query<Map<String, dynamic>> query = _db.collection(AppConstants.colDeals);

    if (user.isSales) {
      query = query.where('salesId', isEqualTo: user.userId);
    } else if (user.isTeamLeader && user.team.isNotEmpty) {
      query = query.where('team', isEqualTo: user.team);
    }

    return query.snapshots().map((snap) {
      final list = snap.docs
          .map((d) => DealModel.fromMap(d.data(), d.id))
          .toList();
      list.sort((a, b) {
        final da = a.createdAt?.millisecondsSinceEpoch ??
            (DateTime.tryParse(a.date)?.millisecondsSinceEpoch ?? 0);
        final db2 = b.createdAt?.millisecondsSinceEpoch ??
            (DateTime.tryParse(b.date)?.millisecondsSinceEpoch ?? 0);
        return db2.compareTo(da);
      });
      return list;
    });
  }

  Future<String> addDeal(DealModel deal) async {
    final data = deal.toMap();
    data['createdAt'] = DateTime.now().toIso8601String();
    final doc = await _db.collection(AppConstants.colDeals).add(data);
    final taskCode = 'TASK-${doc.id.substring(0, 6).toUpperCase()}';
    await doc.update({'taskCode': taskCode});
    await _logAudit(
        deal.salesName, deal.salesId, 'Added deal: ${deal.clientName}', doc.id);
    return doc.id;
  }

  Future<void> updateDeal(String id, Map<String, dynamic> data) async {
    await _db.collection(AppConstants.colDeals).doc(id).update(data);
  }
//NEW ADD
  Future<void> updateTaskByDealId(String dealId, Map<String, dynamic> data) async {
    final snap = await _db
        .collection(AppConstants.colTasks)
        .where('dealId', isEqualTo: dealId)
        .get();
    for (final doc in snap.docs) {
      await doc.reference.update(data);
    }
  }

  Future<void> deleteDeal(String id) async {
    await _db.collection(AppConstants.colDeals).doc(id).delete();
    await _logAudit('Admin', 'superadmin', 'Deleted deal: $id', id);
  }

  // ══════════════════════════════════════════
  // TASKS
  // ══════════════════════════════════════════

  // ← CHANGED: team leader now only sees tasks from their team's sales people
  Stream<List<TaskModel>> tasksStream(UserModel user) {
    Query<Map<String, dynamic>> query = _db.collection(AppConstants.colTasks);

    if (user.isWriter) {
      query = query.where('writerId', isEqualTo: user.userId);
    } else if (user.isSales) {
      query = query.where('salesId', isEqualTo: user.userId);
    } else if (user.isTeamLeader && user.team.isNotEmpty) {
      // Team leader only sees tasks where salesTeam matches their team
      query = query.where('salesTeam', isEqualTo: user.team);
    }
    // Admin: no filter → sees all tasks

    return query.snapshots().map((snap) {
      final list = snap.docs
          .map((d) => TaskModel.fromMap(d.data(), d.id))
          .toList();
      list.sort((a, b) {
        final da = DateTime.tryParse(a.dateAssigned)?.millisecondsSinceEpoch ?? 0;
        final db2 = DateTime.tryParse(b.dateAssigned)?.millisecondsSinceEpoch ?? 0;
        return db2.compareTo(da);
      });
      return list;
    });
  }

  // ← CHANGED: now saves salesTeam onto the task document
  Future<String> assignTask(TaskModel task, String dealId) async {
    // Delete any existing task for this deal first
    final existing = await _db
        .collection(AppConstants.colTasks)
        .where('dealId', isEqualTo: dealId)
        .get();
    for (final doc in existing.docs) {
      await doc.reference.delete();
    }

    // Create the new task
    final data = task.toMap();
    data['createdAt'] = DateTime.now().toIso8601String();
    final doc = await _db.collection(AppConstants.colTasks).add(data);

    await _db.collection(AppConstants.colDeals).doc(dealId).update({
      'assignStatus':   'Assigned',
      'writerAssigned': task.writerName,
      'writerTaskId':   doc.id,
    });

    await _logAudit(task.salesName, task.salesId,
        'Assigned task to ${task.writerName} for ${task.clientName}', doc.id);
    return doc.id;
  }

  Future<void> updateTask(String id, Map<String, dynamic> data) async {
    await _db.collection(AppConstants.colTasks).doc(id).update(data);
  }

  Future<void> deleteTask(String taskId, String dealId) async {
    await _db.collection(AppConstants.colTasks).doc(taskId).delete();
    if (dealId.isNotEmpty) {
      try {
        await _db.collection(AppConstants.colDeals).doc(dealId).update({
          'assignStatus': 'Open',
          'writerAssigned': '',
          'writerTaskId': '',
        });
      } catch (_) {}
    }
    await _logAudit('Admin', 'superadmin', 'Deleted task: $taskId', taskId);
  }

  Future<void> submitTaskCompletion(String taskId, String fileLink) async {
    await _db.collection(AppConstants.colTasks).doc(taskId).update({
      'status': 'Completed',
      'fileLink': fileLink,
      'completedDate': DateTime.now().toIso8601String(),
    });
  }

  Future<void> reviewTask(String taskId, String action, String reviewerName) async {
    if (action == 'review') {
      await _db.collection(AppConstants.colTasks).doc(taskId).update({
        'status': 'Reviewed',
        'teamLeaderReviewed': 'Reviewed by $reviewerName',
      });
    } else if (action == 'forward') {
      await _db.collection(AppConstants.colTasks).doc(taskId).update({
        'status': 'Forwarded to Sales',
        'forwardedToSales': 'Forwarded by $reviewerName',
      });
    }
  }

  Future<void> addComment(String taskId, Map<String, dynamic> comment) async {
    await _db.collection(AppConstants.colTasks).doc(taskId).update({
      'comments': FieldValue.arrayUnion([comment]),
    });
  }

  // ══════════════════════════════════════════
  // DASHBOARD STATS
  // ══════════════════════════════════════════

  Future<Map<String, dynamic>> getDashboardStats(
      UserModel user, {
        String filter = '',
      }) async {
    final stats = <String, dynamic>{
      'totalLeads': 0,
      'totalDeals': 0,
      'totalRevenue': 0.0,
      'pendingPayment': 0,
      'tasksPending': 0,
      'tasksCompleted': 0,
      'pendingAmount': 0.0,
      'partialAmount': 0.0,
      'paidAmount': 0.0,
    };

    bool matchesFilter(String? dateStr) {
      if (filter.isEmpty) return true;
      if (dateStr == null || dateStr.isEmpty) return false;
      return dateStr.startsWith(filter);
    }

    try {
      if (user.canViewLeads) {
        Query<Map<String, dynamic>> leadsQ =
        _db.collection(AppConstants.colLeads);
        if (user.isSales) {
          leadsQ = leadsQ.where('salesId', isEqualTo: user.userId);
        }
        final lSnap = await leadsQ.get();
        int leadCount = 0;
        for (final doc in lSnap.docs) {
          if (matchesFilter(doc.data()['date']?.toString())) leadCount++;
        }
        stats['totalLeads'] = leadCount;
      }

      Query<Map<String, dynamic>> dealsQ =
      _db.collection(AppConstants.colDeals);
      if (user.isSales) {
        dealsQ = dealsQ.where('salesId', isEqualTo: user.userId);
      } else if (user.isTeamLeader && user.team.isNotEmpty) {
        dealsQ = dealsQ.where('team', isEqualTo: user.team);
      }
      final dSnap = await dealsQ.get();
      int dealCount = 0;
      double rev = 0;
      int pendingPay = 0;
      double pendingAmt = 0.0;
      double partialAmt = 0.0;
      double paidAmt = 0.0;

      for (final doc in dSnap.docs) {
        final d = doc.data();
        if (!matchesFilter(d['date']?.toString())) continue;
        dealCount++;
        final dealValue =
            double.tryParse(d['totalDealValue']?.toString() ?? '0') ?? 0;
        rev += dealValue;
        final payStatus = (d['paymentStatus'] ?? '').toString();
        final firstPay =
            double.tryParse(d['payment1st']?.toString() ?? '0') ?? 0;
        if (payStatus == 'Pending') pendingPay++;
        switch (payStatus) {
          case 'Pending':
            pendingAmt += dealValue;
            break;
          case 'Partial':
            partialAmt += firstPay;
            pendingAmt += (dealValue - firstPay);
            break;
          case 'Paid':
            paidAmt += dealValue;
            break;
        }
      }
      stats['totalDeals'] = dealCount;
      stats['totalRevenue'] = rev;
      stats['pendingPayment'] = pendingPay;
      stats['pendingAmount'] = pendingAmt;
      stats['partialAmount'] = partialAmt;
      stats['paidAmount'] = paidAmt;

      Query<Map<String, dynamic>> tasksQ =
      _db.collection(AppConstants.colTasks);
      if (user.isSales) {
        tasksQ = tasksQ.where('salesId', isEqualTo: user.userId);
      } else if (user.isWriter) {
        tasksQ = tasksQ.where('writerId', isEqualTo: user.userId);
      } else if (user.isTeamLeader && user.team.isNotEmpty) {
        // ← CHANGED: dashboard stats also respect team filter
        tasksQ = tasksQ.where('salesTeam', isEqualTo: user.team);
      }
      final tSnap = await tasksQ.get();
      int pendingT = 0, completedT = 0;
      for (final doc in tSnap.docs) {
        final d = doc.data();
        if (!matchesFilter(d['dateAssigned']?.toString())) continue;
        final status = d['status']?.toString() ?? '';
        if (status == 'Completed' ||
            status == 'Reviewed' ||
            status == 'Forwarded to Sales') {
          completedT++;
        } else {
          pendingT++;
        }
      }
      stats['tasksPending'] = pendingT;
      stats['tasksCompleted'] = completedT;
    } catch (_) {}

    return stats;
  }

  // ══════════════════════════════════════════
  // MONTHLY CHART
  // ══════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getMonthlyChartData(
      UserModel user, {
        String filter = '',
      }) async {
    try {
      Query<Map<String, dynamic>> q = _db.collection(AppConstants.colDeals);
      if (user.isSales) q = q.where('salesId', isEqualTo: user.userId);
      if (user.isTeamLeader && user.team.isNotEmpty) {
        q = q.where('team', isEqualTo: user.team);
      }
      final snap = await q.get();
      final monthly = <String, Map<String, dynamic>>{};

      for (final doc in snap.docs) {
        final d = doc.data();
        final dateStr = d['date']?.toString() ?? '';
        if (dateStr.length < 7) continue;
        if (filter.isNotEmpty && !dateStr.startsWith(filter)) continue;
        final month = dateStr.substring(0, 7);
        monthly.putIfAbsent(
            month, () => {'month': month, 'revenue': 0.0, 'deals': 0, 'paid': 0});
        monthly[month]!['revenue'] = (monthly[month]!['revenue'] as double) +
            (double.tryParse(d['totalDealValue']?.toString() ?? '0') ?? 0);
        monthly[month]!['deals'] = (monthly[month]!['deals'] as int) + 1;
        if (d['paymentStatus'] == 'Paid') {
          monthly[month]!['paid'] = (monthly[month]!['paid'] as int) + 1;
        }
      }
      final sorted = monthly.values.toList()
        ..sort((a, b) => (a['month'] as String).compareTo(b['month'] as String));
      return sorted;
    } catch (_) {
      return [];
    }
  }

  // ══════════════════════════════════════════
  // LEADERBOARD
  // ══════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getLeaderboardData(
      UserModel user,
      String period, {
        String filter = '',
      }) async {
    try {
      Query<Map<String, dynamic>> q = _db.collection(AppConstants.colDeals);
      if (user.isTeamLeader && user.team.isNotEmpty) {
        q = q.where('team', isEqualTo: user.team);
      }
      final snap = await q.get();
      final totals = <String, Map<String, dynamic>>{};
      final now = DateTime.now();
      final thisMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      for (final doc in snap.docs) {
        final d = doc.data();
        final dateStr = d['date']?.toString() ?? '';

        if (filter.isNotEmpty) {
          if (!dateStr.startsWith(filter)) continue;
        } else {
          if (period == 'thismonth') {
            if (dateStr.length < 7) continue;
            if (dateStr.substring(0, 7) != thisMonth) continue;
          } else if (period == 'thisyear') {
            if (!dateStr.startsWith(now.year.toString())) continue;
          }
        }

        final sid = d['salesId']?.toString() ?? '';
        if (sid.isEmpty) continue;
        totals.putIfAbsent(sid, () => {
          'salesId': sid,
          'name': d['salesName'] ?? '',
          'team': d['team'] ?? '',
          'rev': 0.0,
          'deals': 0,
          'paid': 0,
        });
        totals[sid]!['rev'] = (totals[sid]!['rev'] as double) +
            (double.tryParse(d['totalDealValue']?.toString() ?? '0') ?? 0);
        totals[sid]!['deals'] = (totals[sid]!['deals'] as int) + 1;
        if (d['paymentStatus'] == 'Paid') {
          totals[sid]!['paid'] = (totals[sid]!['paid'] as int) + 1;
        }
      }
      final sorted = totals.values.toList()
        ..sort((a, b) => (b['rev'] as double).compareTo(a['rev'] as double));
      return sorted;
    } catch (_) {
      return [];
    }
  }

  // ══════════════════════════════════════════
  // WRITER STATS
  // ══════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getWriterStats(UserModel user) async {
    try {
      final snap = await _db.collection(AppConstants.colTasks).get();
      final stats = <String, Map<String, dynamic>>{};
      final today = DateTime.now();

      for (final doc in snap.docs) {
        final d = doc.data();
        final wid = d['writerId']?.toString() ?? '';
        if (wid.isEmpty) continue;
        stats.putIfAbsent(wid, () => {
          'writerId': wid,
          'name': d['writerName'] ?? '',
          'total': 0,
          'done': 0,
          'onTime': 0,
          'late': 0,
          'pending': 0,
        });
        stats[wid]!['total'] = (stats[wid]!['total'] as int) + 1;
        final status = d['status']?.toString() ?? '';
        final isDone = status == 'Completed' ||
            status == 'Reviewed' ||
            status == 'Forwarded to Sales';
        if (isDone) {
          stats[wid]!['done'] = (stats[wid]!['done'] as int) + 1;
          final deadline = DateTime.tryParse(d['deadline']?.toString() ?? '');
          final completed =
              DateTime.tryParse(d['completedDate']?.toString() ?? '') ?? today;
          if (deadline != null &&
              completed.isBefore(deadline.add(const Duration(days: 1)))) {
            stats[wid]!['onTime'] = (stats[wid]!['onTime'] as int) + 1;
          } else {
            stats[wid]!['late'] = (stats[wid]!['late'] as int) + 1;
          }
        } else {
          stats[wid]!['pending'] = (stats[wid]!['pending'] as int) + 1;
        }
      }

      final list = stats.values.toList();
      for (final s in list) {
        final done = s['done'] as int;
        final total = s['total'] as int;
        final onTime = s['onTime'] as int;
        s['onTimeRate'] = done > 0 ? ((onTime / done) * 100).round() : 0;
        s['completionRate'] =
        total > 0 ? ((done / total) * 100).round() : 0;
      }
      list.sort((a, b) => (b['done'] as int).compareTo(a['done'] as int));
      return list;
    } catch (_) {
      return [];
    }
  }

  // ══════════════════════════════════════════
  // AUDIT LOG
  // ══════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getAuditLog({int limit = 200}) async {
    try {
      final snap =
      await _db.collection(AppConstants.colAudit).limit(limit).get();
      final list = snap.docs
          .map((d) => <String, dynamic>{...d.data(), 'id': d.id})
          .toList();
      list.sort((a, b) {
        final ta = a['time']?.toString() ?? '';
        final tb = b['time']?.toString() ?? '';
        return tb.compareTo(ta);
      });
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<void> _logAudit(
      String userName, String role, String action, String recordId) async {
    try {
      await _db.collection(AppConstants.colAudit).add({
        'time': DateTime.now().toIso8601String(),
        'user': userName,
        'role': role,
        'action': action,
        'record': recordId,
      });
    } catch (_) {}
  }

  Future<void> logAudit(
      String userName, String role, String action, String recordId) async {
    await _logAudit(userName, role, action, recordId);
  }

  // ══════════════════════════════════════════
  // EXPORT HELPERS
  // ══════════════════════════════════════════

  Future<List<LeadModel>> getAllLeadsForUser(String salesId) async {
    final snap = await _db
        .collection(AppConstants.colLeads)
        .where('salesId', isEqualTo: salesId)
        .get();
    final list =
    snap.docs.map((d) => LeadModel.fromMap(d.data(), d.id)).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<List<DealModel>> getAllDealsForUser(String salesId) async {
    final snap = await _db
        .collection(AppConstants.colDeals)
        .where('salesId', isEqualTo: salesId)
        .get();
    final list =
    snap.docs.map((d) => DealModel.fromMap(d.data(), d.id)).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<List<TaskModel>> getAllTasksForWriter(String writerId) async {
    final snap = await _db
        .collection(AppConstants.colTasks)
        .where('writerId', isEqualTo: writerId)
        .get();
    final list =
    snap.docs.map((d) => TaskModel.fromMap(d.data(), d.id)).toList();
    list.sort((a, b) => b.dateAssigned.compareTo(a.dateAssigned));
    return list;
  }

  Future<List<TaskModel>> getAllTasks() async {
    final snap = await _db.collection(AppConstants.colTasks).get();
    final list =
    snap.docs.map((d) => TaskModel.fromMap(d.data(), d.id)).toList();
    list.sort((a, b) => b.dateAssigned.compareTo(a.dateAssigned));
    return list;
  }

  Future<List<LeadModel>> getLeadsForUserFiltered(
      String salesId, String filter) async {
    final snap = await _db
        .collection(AppConstants.colLeads)
        .where('salesId', isEqualTo: salesId)
        .get();
    final list = snap.docs
        .map((d) => LeadModel.fromMap(d.data(), d.id))
        .where((l) => filter.isEmpty || l.date.startsWith(filter))
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<List<DealModel>> getDealsForUserFiltered(
      String salesId, String filter) async {
    final snap = await _db
        .collection(AppConstants.colDeals)
        .where('salesId', isEqualTo: salesId)
        .get();
    final list = snap.docs
        .map((d) => DealModel.fromMap(d.data(), d.id))
        .where((d) => filter.isEmpty || d.date.startsWith(filter))
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<List<TaskModel>> getTasksForWriterFiltered(
      String writerId, String filter) async {
    final snap = await _db
        .collection(AppConstants.colTasks)
        .where('writerId', isEqualTo: writerId)
        .get();
    final list = snap.docs
        .map((d) => TaskModel.fromMap(d.data(), d.id))
        .where((t) => filter.isEmpty || t.dateAssigned.startsWith(filter))
        .toList();
    list.sort((a, b) => b.dateAssigned.compareTo(a.dateAssigned));
    return list;
  }

  Future<List<LeadModel>> getAllLeadsFiltered(String filter) async {
    final snap = await _db.collection(AppConstants.colLeads).get();
    final list = snap.docs
        .map((d) => LeadModel.fromMap(d.data(), d.id))
        .where((l) => filter.isEmpty || l.date.startsWith(filter))
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<List<DealModel>> getAllDealsFiltered(String filter) async {
    final snap = await _db.collection(AppConstants.colDeals).get();
    final list = snap.docs
        .map((d) => DealModel.fromMap(d.data(), d.id))
        .where((d) => filter.isEmpty || d.date.startsWith(filter))
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<List<TaskModel>> getAllTasksFiltered(String filter) async {
    final snap = await _db.collection(AppConstants.colTasks).get();
    final list = snap.docs
        .map((d) => TaskModel.fromMap(d.data(), d.id))
        .where((t) => filter.isEmpty || t.dateAssigned.startsWith(filter))
        .toList();
    list.sort((a, b) => b.dateAssigned.compareTo(a.dateAssigned));
    return list;
  }
}
