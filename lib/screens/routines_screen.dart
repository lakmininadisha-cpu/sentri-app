import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/routine.dart';
import '../services/notification_service.dart';
import '../widgets/app_widgets.dart';

// Manages recurring routine tasks (e.g. "pay bills on the 5th"), health
// reminders (medication, water intake), and one-off calendar-style
// reminders — all under one unified, schedule-aware system.
class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({super.key});

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  final _titleController = TextEditingController();
  String _selectedCategory = 'Routine';
  String _selectedScheduleType = 'daily';
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  int _selectedDayOfMonth = 1;
  DateTime? _selectedDate;

  final List<String> _categories = ['Routine', 'Health', 'Calendar'];
  final List<String> _scheduleTypes = ['daily', 'weekly', 'monthly', 'once'];

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _addRoutine() async {
    if (_titleController.text.trim().isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final routine = Routine(
      id: '',
      title: _titleController.text.trim(),
      category: _selectedCategory,
      scheduleType: _selectedScheduleType,
      hour: _selectedTime.hour,
      minute: _selectedTime.minute,
      dayOfMonth: _selectedScheduleType == 'monthly' ? _selectedDayOfMonth : null,
      specificDate: _selectedScheduleType == 'once' ? _selectedDate : null,
    );

    await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('routines').add(routine.toFirestore());
    _titleController.clear();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _markCompleted(Routine routine) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('routines').doc(routine.id).update({'lastCompletedAt': Timestamp.now()});
  }

  Future<void> _deleteRoutine(String routineId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('routines').doc(routineId).delete();
  }

  Future<void> _checkDueRoutines() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('routines').get();
    final routines = snapshot.docs.map((doc) => Routine.fromFirestore(doc)).toList();
    final dueRoutines = routines.where((r) => r.isDueToday()).toList();

    if (dueRoutines.isEmpty) {
      await NotificationService().showNotification(id: 2, title: 'All caught up!', body: 'No routines or reminders due right now.');
    } else {
      final titles = dueRoutines.map((r) => r.title).join(', ');
      await NotificationService().showNotification(id: 2, title: 'You have ${dueRoutines.length} thing(s) due', body: titles);
    }
  }

  void _showAddRoutineSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16), alignment: Alignment.center,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                    const Text('Add Routine or Reminder', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(labelText: 'Title', hintText: 'e.g. Pay electricity bill', prefixIcon: const Icon(Icons.edit_note), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      decoration: InputDecoration(labelText: 'Category', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (value) { if (value != null) setSheetState(() => _selectedCategory = value); },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedScheduleType,
                      decoration: InputDecoration(labelText: 'Repeats', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      items: _scheduleTypes.map((s) => DropdownMenuItem(value: s, child: Text(s[0].toUpperCase() + s.substring(1)))).toList(),
                      onChanged: (value) { if (value != null) setSheetState(() => _selectedScheduleType = value); },
                    ),
                    const SizedBox(height: 12),
                    if (_selectedScheduleType == 'monthly')
                      DropdownButtonFormField<int>(
                        initialValue: _selectedDayOfMonth,
                        decoration: InputDecoration(labelText: 'Day of month', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                        items: List.generate(28, (i) => i + 1).map((d) => DropdownMenuItem(value: d, child: Text('$d'))).toList(),
                        onChanged: (value) { if (value != null) setSheetState(() => _selectedDayOfMonth = value); },
                      ),
                    if (_selectedScheduleType == 'once')
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                          if (picked != null) setSheetState(() => _selectedDate = picked);
                        },
                        style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(_selectedDate == null ? 'Pick a date' : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'),
                      ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showTimePicker(context: context, initialTime: _selectedTime);
                        if (picked != null) setSheetState(() => _selectedTime = picked);
                      },
                      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      icon: const Icon(Icons.access_time),
                      label: Text('Time: ${_selectedTime.format(context)}'),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _addRoutine,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), backgroundColor: kTeal, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('Add'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: kBackground,
      body: Stack(
        children: [
          const BackgroundAccents(),
          Column(
            children: [
              GradientHeader(
                title: 'Routines & Reminders',
                subtitle: 'Daily tasks, health, and events',
                actions: [
                  HeaderIconButton(icon: Icons.notifications_active_outlined, tooltip: 'Check what\'s due now', onPressed: _checkDueRoutines),
                ],
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).collection('routines').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const SkeletonListView();
                    if (snapshot.hasError) return ErrorView(message: 'Something went wrong: ${snapshot.error}');

                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return EmptyState(
                        icon: Icons.checklist_outlined,
                        color: kAmber,
                        title: 'Nothing scheduled yet',
                        message: 'Add a daily task, health reminder, or a one-off reminder.',
                        actionLabel: 'Add Routine',
                        onAction: _showAddRoutineSheet,
                      );
                    }

                    final routines = docs.map((doc) => Routine.fromFirestore(doc)).toList();
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: routines.length,
                      itemBuilder: (context, index) {
                        final routine = routines[index];
                        final isDue = routine.isDueToday();
                        final categoryColor = routine.category == 'Health' ? kCoral : (routine.category == 'Calendar' ? kBlue : kTeal);

                        return StaggeredListItem(
                          index: index,
                          child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: SentriCard(
                            color: isDue ? const Color(0xFFFFF3E0) : Colors.white,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: categoryColor.withValues(alpha: 0.12), shape: BoxShape.circle),
                                  child: Icon(_categoryIcon(routine.category), color: categoryColor, size: 20),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(routine.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                                      Text('${routine.category} \u00b7 ${_scheduleDescription(routine)}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                if (isDue)
                                  IconButton(icon: const Icon(Icons.check_circle_outline, color: kGreen), tooltip: 'Mark as done', onPressed: () => _markCompleted(routine)),
                                IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey), onPressed: () => _deleteRoutine(routine.id)),
                              ],
                            ),
                          ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kTeal,
        onPressed: _showAddRoutineSheet,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Health':
        return Icons.favorite_outline;
      case 'Calendar':
        return Icons.event_outlined;
      default:
        return Icons.checklist_outlined;
    }
  }

  String _scheduleDescription(Routine routine) {
    switch (routine.scheduleType) {
      case 'daily':
        return 'Every day';
      case 'weekly':
        return 'Every Monday';
      case 'monthly':
        return 'Day ${routine.dayOfMonth} of each month';
      case 'once':
        if (routine.specificDate == null) return 'One-time';
        return 'On ${routine.specificDate!.day}/${routine.specificDate!.month}/${routine.specificDate!.year}';
      default:
        return '';
    }
  }
}