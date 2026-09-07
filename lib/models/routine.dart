import 'package:cloud_firestore/cloud_firestore.dart';

// A flexible reminder that covers three related needs from the brief:
// recurring routine tasks (e.g. "pay bills on the 5th"), health nudges
// (medication, water), and one-off calendar-style reminders. Rather than
// building three separate systems, one schedule-aware model covers all
// three cleanly, since they're structurally the same thing: a title,
// a category, and when it should next remind the user.
class Routine {
  final String id;
  final String title;
  final String category; // 'Routine', 'Health', or 'Calendar'
  final String scheduleType; // 'daily', 'weekly', 'monthly', 'once'
  final int hour;
  final int minute;
  final int? dayOfMonth; // used only when scheduleType == 'monthly'
  final DateTime? specificDate; // used only when scheduleType == 'once'
  final DateTime? lastCompletedAt;

  Routine({
    required this.id,
    required this.title,
    required this.category,
    required this.scheduleType,
    required this.hour,
    required this.minute,
    this.dayOfMonth,
    this.specificDate,
    this.lastCompletedAt,
  });

  factory Routine.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Routine(
      id: doc.id,
      title: data['title'] ?? '',
      category: data['category'] ?? 'Routine',
      scheduleType: data['scheduleType'] ?? 'daily',
      hour: data['hour'] ?? 9,
      minute: data['minute'] ?? 0,
      dayOfMonth: data['dayOfMonth'],
      specificDate: (data['specificDate'] as Timestamp?)?.toDate(),
      lastCompletedAt: (data['lastCompletedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'category': category,
      'scheduleType': scheduleType,
      'hour': hour,
      'minute': minute,
      'dayOfMonth': dayOfMonth,
      'specificDate': specificDate != null ? Timestamp.fromDate(specificDate!) : null,
      'lastCompletedAt': lastCompletedAt != null ? Timestamp.fromDate(lastCompletedAt!) : null,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  bool isDueToday() {
    final now = DateTime.now();

    switch (scheduleType) {
      case 'daily':
        return !_completedToday(now);
      case 'weekly':
        return now.weekday == 1 && !_completedToday(now);
      case 'monthly':
        return dayOfMonth != null && now.day == dayOfMonth && !_completedToday(now);
      case 'once':
        if (specificDate == null) return false;
        return now.year == specificDate!.year &&
            now.month == specificDate!.month &&
            now.day == specificDate!.day &&
            lastCompletedAt == null;
      default:
        return false;
    }
  }

  bool _completedToday(DateTime now) {
    if (lastCompletedAt == null) return false;
    return lastCompletedAt!.year == now.year &&
        lastCompletedAt!.month == now.month &&
        lastCompletedAt!.day == now.day;
  }
}