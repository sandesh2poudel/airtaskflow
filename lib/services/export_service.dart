// lib/services/export_service.dart
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;

import '../models/deal_model.dart';
import '../models/lead_model.dart';
import '../models/task_model.dart';
import '../models/user_model.dart';
import 'firestore_service.dart';

class ExportService {
  final FirestoreService _svc = FirestoreService();

  // ══════════════════════════════════════════════════════════════
  // PER-USER EXPORTS
  // ══════════════════════════════════════════════════════════════

  Future<void> exportUserLeads(UserModel user, {String filter = ''}) async {
    final excel = _newExcel();
    final sheet = excel[_safe('${user.name} Leads')];
    final items = await _svc.getLeadsForUserFiltered(user.userId, filter);
    _leadsHeader(sheet);
    for (var i = 0; i < items.length; i++) {
      _leadsRow(sheet, i, items[i]);
    }
    _leadsFooter(sheet, items);
    _download(excel, '${_safe(user.name)}_Leads_${_label(filter)}.xlsx');
  }

  Future<void> exportUserDeals(UserModel user, {String filter = ''}) async {
    final excel = _newExcel();
    final sheet = excel[_safe('${user.name} Deals')];
    final items = await _svc.getDealsForUserFiltered(user.userId, filter);
    _dealsHeader(sheet);
    for (var i = 0; i < items.length; i++) {
      _dealsRow(sheet, i, items[i]);
    }
    _dealsFooter(sheet, items);
    _download(excel, '${_safe(user.name)}_Deals_${_label(filter)}.xlsx');
  }

  Future<void> exportWriterTasks(UserModel writer, {String filter = ''}) async {
    final excel = _newExcel();
    final sheet = excel[_safe('${writer.name} Tasks')];
    final items = await _svc.getTasksForWriterFiltered(writer.userId, filter);
    _tasksHeader(sheet);
    for (var i = 0; i < items.length; i++) {
      _tasksRow(sheet, i, items[i]);
    }
    _tasksFooter(sheet, items);
    _download(excel, '${_safe(writer.name)}_Tasks_${_label(filter)}.xlsx');
  }

  // ══════════════════════════════════════════════════════════════
  // ALL-USERS EXPORTS
  // ══════════════════════════════════════════════════════════════

  Future<void> exportAllLeads({String filter = ''}) async {
    final excel = _newExcel();
    final users = await _svc.getAllUsers();
    for (final u in users.where((u) => u.isSales)) {
      final sheet = excel[_safe('${u.name} Leads')];
      final items = await _svc.getLeadsForUserFiltered(u.userId, filter);
      _leadsHeader(sheet);
      for (var i = 0; i < items.length; i++) {
        _leadsRow(sheet, i, items[i]);
      }
      _leadsFooter(sheet, items);
    }
    _download(excel, 'AirTaskFlow_All_Leads_${_label(filter)}.xlsx');
  }

  Future<void> exportAllDeals({String filter = ''}) async {
    final excel = _newExcel();
    final users = await _svc.getAllUsers();
    for (final u in users.where((u) => u.isSales)) {
      final sheet = excel[_safe('${u.name} Deals')];
      final items = await _svc.getDealsForUserFiltered(u.userId, filter);
      _dealsHeader(sheet);
      for (var i = 0; i < items.length; i++) {
        _dealsRow(sheet, i, items[i]);
      }
      _dealsFooter(sheet, items);
    }
    _download(excel, 'AirTaskFlow_All_Deals_${_label(filter)}.xlsx');
  }

  Future<void> exportAllTasks({String filter = ''}) async {
    final excel = _newExcel();
    final sheet = excel['All Tasks'];
    final items = await _svc.getAllTasksFiltered(filter);
    _hdr(sheet, [
      '#', 'Task ID', 'Date Assigned', 'Client', 'Subject',
      'Type', 'Words', 'Deadline', 'Priority',
      'Sales Person', 'Writer', 'Status', 'File Link',
    ]);
    for (var i = 0; i < items.length; i++) {
      final t = items[i];
      sheet.appendRow([
        TextCellValue('${i + 1}'),
        TextCellValue(t.taskId),
        TextCellValue(t.dateAssigned),
        TextCellValue(t.clientName),
        TextCellValue(t.subject),
        TextCellValue(t.assignmentType),
        TextCellValue(t.wordCount),
        TextCellValue(t.deadline),
        TextCellValue(t.priority),
        TextCellValue(t.salesName),
        TextCellValue(t.writerName),
        TextCellValue(t.status),
        TextCellValue(t.fileLink),
      ]);
    }
    _allTasksFooter(sheet, items);
    _download(excel, 'AirTaskFlow_All_Tasks_${_label(filter)}.xlsx');
  }

  // ══════════════════════════════════════════════════════════════
  // LEADS helpers
  // ══════════════════════════════════════════════════════════════

  void _leadsHeader(Sheet sheet) {
    _hdr(sheet, [
      '#', 'Date', 'Client Name', 'Status', 'Subject/Task',
      'Source', 'Remarks', 'Profile Link', 'Follow Up', 'WhatsApp',
    ]);
  }

  void _leadsRow(Sheet sheet, int i, LeadModel l) {
    sheet.appendRow([
      TextCellValue('${i + 1}'),
      TextCellValue(l.date),
      TextCellValue(l.clientName),
      TextCellValue(l.dealClosingStatus),
      TextCellValue(l.subjectsTask),
      TextCellValue(l.source),
      TextCellValue(l.remarks),
      TextCellValue(l.clientProfileLink),
      TextCellValue(l.followupTextCall),
      TextCellValue(l.whatsappNumber),
    ]);
  }

  void _leadsFooter(Sheet sheet, List<LeadModel> items) {
    if (items.isEmpty) return;
    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([TextCellValue('--- SUMMARY ---')]);
    sheet.appendRow([TextCellValue('Total Leads'), TextCellValue('${items.length}')]);

    final counts = <String, int>{};
    for (final l in items) {
      counts[l.dealClosingStatus] = (counts[l.dealClosingStatus] ?? 0) + 1;
    }
    for (final e in counts.entries) {
      sheet.appendRow([TextCellValue(e.key), TextCellValue('${e.value}')]);
    }
  }

  // ══════════════════════════════════════════════════════════════
  // DEALS helpers
  // ══════════════════════════════════════════════════════════════

  void _dealsHeader(Sheet sheet) {
    _hdr(sheet, [
      '#', 'Task Code', 'Sales ID', 'Date', 'Client', 'Words',
      'Total (AUD)', '1st Pay', '2nd Pay', 'Pay Status',
      'Assign', 'Writer', 'Notes',
      'Task File Link', 'Pay Screenshot', 'WhatsApp', 'Client Profile',
    ]);
  }

  void _dealsRow(Sheet sheet, int i, DealModel d) {
    sheet.appendRow([
      TextCellValue('${i + 1}'),
      TextCellValue(d.taskCode),
      TextCellValue(d.salesTaskId),          // ← ADD THIS
      TextCellValue(d.date),
      TextCellValue(d.clientName),
      TextCellValue(d.wordCount),
      TextCellValue(d.totalDealValue),
      TextCellValue(d.payment1st),
      TextCellValue(d.payment2nd),
      TextCellValue(d.paymentStatus),
      TextCellValue(d.assignStatus),
      TextCellValue(d.writerAssigned),
      TextCellValue(d.notes),
      TextCellValue(d.salesFileLink),        // Task File Link
      TextCellValue(d.paymentScreenshot),    // Pay Screenshot
      TextCellValue(d.whatsappNumber),       // WhatsApp
      TextCellValue(d.clientProfileLink),    // Client Profile
    ]);
  }
  void _dealsFooter(Sheet sheet, List<DealModel> items) {
    if (items.isEmpty) return;

    double totalValue   = 0;
    double totalPaid    = 0;
    double totalPartial = 0;
    double totalPending = 0;
    int    countPaid    = 0;
    int    countPartial = 0;
    int    countPending = 0;

    for (final d in items) {
      final val  = double.tryParse(d.totalDealValue) ?? 0;
      final pay1 = double.tryParse(d.payment1st)     ?? 0;
      totalValue += val;
      switch (d.paymentStatus) {
        case 'Paid':
          totalPaid    += val;
          countPaid++;
          break;
        case 'Partial':
          totalPartial += pay1;
          totalPending += (val - pay1);
          countPartial++;
          break;
        case 'Pending':
          totalPending += val;
          countPending++;
          break;
      }
    }

    final outstanding = totalValue - totalPaid - totalPartial;

    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([TextCellValue('--- FINANCIAL SUMMARY ---')]);
    sheet.appendRow([TextCellValue('Total Deals'),                        TextCellValue('${items.length}')]);
    sheet.appendRow([TextCellValue('Total Deal Value (AUD)'),             TextCellValue('\$${totalValue.toStringAsFixed(2)}')]);
    sheet.appendRow([TextCellValue(''),                                   TextCellValue('')]);
    sheet.appendRow([TextCellValue('Paid Deals ($countPaid)'),            TextCellValue('\$${totalPaid.toStringAsFixed(2)}')]);
    sheet.appendRow([TextCellValue('Partial Deals ($countPartial) — Received'), TextCellValue('\$${totalPartial.toStringAsFixed(2)}')]);
    sheet.appendRow([TextCellValue('Pending Deals ($countPending)'),      TextCellValue('\$${totalPending.toStringAsFixed(2)}')]);
    sheet.appendRow([TextCellValue(''),                                   TextCellValue('')]);
    sheet.appendRow([TextCellValue('Outstanding (AUD)'),                  TextCellValue('\$${outstanding.toStringAsFixed(2)}')]);
  }

  // ══════════════════════════════════════════════════════════════
  // TASKS helpers
  // ══════════════════════════════════════════════════════════════

  void _tasksHeader(Sheet sheet) {
    _hdr(sheet, [
      '#', 'Task ID','Sales Task ID',  'Date Assigned', 'Client', 'Subject',
      'Type', 'Words', 'Deadline', 'Priority',
      'Sales Person', 'Status', 'File Link',
    ]);
  }

  void _tasksRow(Sheet sheet, int i, TaskModel t) {
    sheet.appendRow([
      TextCellValue('${i + 1}'),
      TextCellValue(t.taskId),
      TextCellValue(t.salesTaskId),
      TextCellValue(t.dateAssigned),
      TextCellValue(t.clientName),
      TextCellValue(t.subject),
      TextCellValue(t.assignmentType),
      TextCellValue(t.wordCount),
      TextCellValue(t.deadline),
      TextCellValue(t.priority),
      TextCellValue(t.salesName),
      TextCellValue(t.status),
      TextCellValue(t.fileLink),
    ]);
  }

  void _tasksFooter(Sheet sheet, List<TaskModel> items) {
    if (items.isEmpty) return;

    final counts = <String, int>{};
    for (final t in items) {
      counts[t.status] = (counts[t.status] ?? 0) + 1;
    }
    final done = (counts['Completed'] ?? 0) +
        (counts['Reviewed'] ?? 0) +
        (counts['Forwarded to Sales'] ?? 0);
    final pending = items.length - done;

    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([TextCellValue('--- TASK SUMMARY ---')]);
    sheet.appendRow([TextCellValue('Total Tasks'),          TextCellValue('${items.length}')]);
    sheet.appendRow([TextCellValue('Completed / Done'),     TextCellValue('$done')]);
    sheet.appendRow([TextCellValue('Pending / In Progress'),TextCellValue('$pending')]);
    sheet.appendRow([TextCellValue('')]);
    for (final e in counts.entries) {
      sheet.appendRow([TextCellValue(e.key), TextCellValue('${e.value}')]);
    }
  }

  void _allTasksFooter(Sheet sheet, List<TaskModel> items) {
    if (items.isEmpty) return;

    final counts = <String, int>{};
    for (final t in items) {
      counts[t.status] = (counts[t.status] ?? 0) + 1;
    }

    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([TextCellValue('--- TASK SUMMARY ---')]);
    sheet.appendRow([TextCellValue('Total Tasks'), TextCellValue('${items.length}')]);
    for (final e in counts.entries) {
      sheet.appendRow([TextCellValue(e.key), TextCellValue('${e.value}')]);
    }
  }

  // ══════════════════════════════════════════════════════════════
  // SHARED HELPERS
  // ══════════════════════════════════════════════════════════════

  Excel _newExcel() {
    final e = Excel.createExcel();
    e.delete('Sheet1');
    return e;
  }

  void _hdr(Sheet sheet, List<String> cols) {
    sheet.appendRow(cols.map((c) => TextCellValue(c)).toList());
    sheet.setColumnWidth(0, 6.0);
    for (var i = 1; i < cols.length; i++) {
      sheet.setColumnWidth(i, 22.0);
    }
  }

  String _safe(String name) {
    final s = name.replaceAll(RegExp(r'[\/\\\?\*\[\]:]'), '_');
    return s.length > 31 ? s.substring(0, 31) : s;
  }

  String _label(String filter) => filter.isEmpty ? 'All' : filter;

  void _download(Excel excel, String filename) {
    final bytes = excel.encode();
    if (bytes == null) return;
    if (kIsWeb) {
      final content = html.Blob(
        [bytes],
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      final url = html.Url.createObjectUrlFromBlob(content);
      html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click();
      html.Url.revokeObjectUrl(url);
    }
  }
}