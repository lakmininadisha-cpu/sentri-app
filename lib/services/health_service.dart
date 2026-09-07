import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Tracks two things: whether the phone has moved recently (using the
// accelerometer, for the inactivity nudge — unchanged from before), and
// today's step count (using the device's built-in pedometer sensor,
// new).
//
// The pedometer package reports a *cumulative* step count since the
// phone last rebooted, not "steps today" — so to get a daily figure we
// record a baseline count at the start of each day and subtract it
// from the live reading. The baseline is stored locally so it survives
// the app being closed and reopened.
class HealthService {
  // ---- Inactivity tracking (accelerometer) ----
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  DateTime _lastMovementAt = DateTime.now();
  double? _previousMagnitude;
  static const double _movementThreshold = 1.5;

  void startTracking() {
    _accelSubscription = accelerometerEventStream().listen((event) {
      final magnitude = (event.x.abs() + event.y.abs() + event.z.abs());

      if (_previousMagnitude != null) {
        final change = (magnitude - _previousMagnitude!).abs();
        if (change > _movementThreshold) {
          _lastMovementAt = DateTime.now();
        }
      }

      _previousMagnitude = magnitude;
    });
  }

  void stopTracking() {
    _accelSubscription?.cancel();
  }

  Duration get inactiveDuration => DateTime.now().difference(_lastMovementAt);

  // ---- Step tracking (pedometer) ----
  StreamSubscription<StepCount>? _stepSubscription;
  int? _todayBaseline;
  int _todaySteps = 0;
  final _stepsController = StreamController<int>.broadcast();

  Stream<int> get todayStepsStream => _stepsController.stream;
  int get todaySteps => _todaySteps;

  // Starts listening to the device's step sensor and works out how many
  // of the cumulative steps belong to today specifically.
  Future<void> startStepTracking() async {
    await _loadOrResetBaseline();

    _stepSubscription = Pedometer.stepCountStream.listen(
      (event) {
        final baseline = _todayBaseline;
        if (baseline == null) return;
        final steps = event.steps - baseline;
        _todaySteps = steps < 0 ? 0 : steps; // guard against a device reboot resetting the sensor mid-day
        _stepsController.add(_todaySteps);
      },
      onError: (_) {
        // No step sensor available (common on emulators) — fail
        // gracefully rather than crashing; the UI shows 0 / unavailable.
      },
      cancelOnError: false,
    );
  }

  void stopStepTracking() {
    _stepSubscription?.cancel();
  }

  Future<void> _loadOrResetBaseline() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final storedDate = prefs.getString('stepBaselineDate');

    if (storedDate == today && prefs.containsKey('stepBaselineCount')) {
      _todayBaseline = prefs.getInt('stepBaselineCount');
      return;
    }

    // New day (or first run) — the next reading we get from the sensor
    // becomes today's starting point.
    try {
      final firstReading = await Pedometer.stepCountStream.first;
      _todayBaseline = firstReading.steps;
    } catch (_) {
      _todayBaseline = 0;
    }
    await prefs.setString('stepBaselineDate', today);
    await prefs.setInt('stepBaselineCount', _todayBaseline!);
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  void disposeSteps() {
    _stepsController.close();
  }
}