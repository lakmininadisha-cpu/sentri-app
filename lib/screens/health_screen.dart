import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/health_service.dart';
import '../widgets/app_widgets.dart';

// A dedicated Health screen covering three related features: today's
// step count (from the device's pedometer), a quick water-intake
// logger against a daily goal, and a simple 7-day history of both,
// all stored in a per-day Firestore document so a week's trend can be
// shown without needing a heavy charting dependency.
class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  final HealthService _healthService = HealthService();
  int _todaySteps = 0;
  int _todayWaterGlasses = 0;
  static const int _waterGoal = 8;
  static const int _stepGoal = 6000;

  List<_DayHealthLog> _weekHistory = [];
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _healthService.startStepTracking();
    _healthService.todayStepsStream.listen((steps) {
      if (mounted) setState(() => _todaySteps = steps);
      _saveTodayLog();
    });
    _loadTodayWater();
    _loadWeekHistory();
  }

  @override
  void dispose() {
    _healthService.stopStepTracking();
    super.dispose();
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadTodayWater() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('healthLogs').doc(_todayKey()).get();
    if (doc.exists && mounted) {
      setState(() => _todayWaterGlasses = (doc.data()?['waterGlasses'] as num?)?.toInt() ?? 0);
    }
  }

  Future<void> _saveTodayLog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('healthLogs').doc(_todayKey()).set({
      'date': Timestamp.now(),
      'steps': _todaySteps,
      'waterGlasses': _todayWaterGlasses,
    }, SetOptions(merge: true));
  }

  Future<void> _adjustWater(int delta) async {
    setState(() {
      _todayWaterGlasses = (_todayWaterGlasses + delta).clamp(0, 99);
    });
    await _saveTodayLog();
    _loadWeekHistory();
  }

  Future<void> _loadWeekHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final List<_DayHealthLog> history = [];

    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('healthLogs').doc(key).get();

      final steps = i == 0 ? _todaySteps : (doc.data()?['steps'] as num?)?.toInt() ?? 0;
      final water = i == 0 ? _todayWaterGlasses : (doc.data()?['waterGlasses'] as num?)?.toInt() ?? 0;
      history.add(_DayHealthLog(date: day, steps: steps, waterGlasses: water));
    }

    if (mounted) {
      setState(() {
      _weekHistory = history;
      _isLoadingHistory = false;
    });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: Stack(
        children: [
          const BackgroundAccents(),
          Column(
            children: [
              const GradientHeader(title: 'Health', subtitle: 'Steps, water, and your weekly trend'),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(child: _stepCard()),
                          const SizedBox(width: 12),
                          Expanded(child: _waterCard()),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _sectionTitle('This Week', Icons.bar_chart_outlined, kCoral),
                      const SizedBox(height: 10),
                      _isLoadingHistory ? const SkeletonListView(rowCount: 2) : _weekChart(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _stepCard() {
    final progress = (_todaySteps / _stepGoal).clamp(0.0, 1.0);
    return SentriCard(
      color: kCoral.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: kCoral, shape: BoxShape.circle),
            child: const Icon(Icons.directions_walk, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 10),
          Center(
            child: AnimatedProgressRing(
              progress: progress,
              color: kCoral,
              size: 90,
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CountUpNumber(value: _todaySteps, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kCoral)),
                  Text('steps', style: TextStyle(color: Colors.grey.shade600, fontSize: 9.5)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(child: Text('Goal: $_stepGoal', style: TextStyle(color: Colors.grey.shade500, fontSize: 10.5))),
        ],
      ),
    );
  }

  Widget _waterCard() {
    final progress = (_todayWaterGlasses / _waterGoal).clamp(0.0, 1.0);
    return SentriCard(
      color: kBlue.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: kBlue, shape: BoxShape.circle),
            child: const Icon(Icons.local_drink_outlined, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 10),
          Center(
            child: AnimatedProgressRing(
              progress: progress,
              color: kBlue,
              size: 90,
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CountUpNumber(value: _todayWaterGlasses, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kBlue), suffix: '/$_waterGoal'),
                  Text('glasses', style: TextStyle(color: Colors.grey.shade600, fontSize: 9.5)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: BouncyTap(
                  child: OutlinedButton(
                    onPressed: _todayWaterGlasses > 0 ? () => _adjustWater(-1) : null,
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 6), minimumSize: Size.zero),
                    child: const Icon(Icons.remove, size: 16),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: BouncyTap(
                  child: ElevatedButton(
                    onPressed: () => _adjustWater(1),
                    style: ElevatedButton.styleFrom(backgroundColor: kBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 6), minimumSize: Size.zero),
                    child: const Icon(Icons.add, size: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _weekChart() {
    if (_weekHistory.isEmpty) {
      return Text('No history yet.', style: TextStyle(color: Colors.grey.shade600));
    }

    final maxSteps = _weekHistory.map((d) => d.steps).fold(1, (a, b) => a > b ? a : b);
    final maxWater = _weekHistory.map((d) => d.waterGlasses).fold(1, (a, b) => a > b ? a : b);

    return SentriCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.directions_walk, size: 14, color: kCoral),
            const SizedBox(width: 6),
            Text('Steps', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            height: 70,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _weekHistory.map((day) {
                final heightFraction = maxSteps > 0 ? day.steps / maxSteps : 0.0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: 50 * heightFraction.clamp(0.04, 1.0),
                          decoration: BoxDecoration(color: kCoral.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(4)),
                        ),
                        const SizedBox(height: 4),
                        Text(_weekdayLabel(day.date), style: TextStyle(fontSize: 9.5, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),
          Row(children: [
            const Icon(Icons.local_drink_outlined, size: 14, color: kBlue),
            const SizedBox(width: 6),
            Text('Water (glasses)', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            height: 70,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _weekHistory.map((day) {
                final heightFraction = maxWater > 0 ? day.waterGlasses / maxWater : 0.0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: 50 * heightFraction.clamp(0.04, 1.0),
                          decoration: BoxDecoration(color: kBlue.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(4)),
                        ),
                        const SizedBox(height: 4),
                        Text(_weekdayLabel(day.date), style: TextStyle(fontSize: 9.5, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _weekdayLabel(DateTime date) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return labels[date.weekday - 1];
  }
}

class _DayHealthLog {
  final DateTime date;
  final int steps;
  final int waterGlasses;
  _DayHealthLog({required this.date, required this.steps, required this.waterGlasses});
}