import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// Wraps flutter_blue_plus for two purposes: scanning nearby Bluetooth
// devices so the user can "link" one to an item (standing in for a
// dedicated BLE tracker tag), and later checking whether that same
// device is currently in range as a rough proximity signal.
class BluetoothTrackerService {
  Future<bool> isBluetoothAvailable() async {
    return await FlutterBluePlus.isSupported;
  }

  // Scans for a few seconds and returns whatever nearby devices were
  // found, so the user can pick one to link to an item.
  Future<List<ScanResult>> scanNearbyDevices() async {
    final List<ScanResult> results = [];

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));

    final subscription = FlutterBluePlus.scanResults.listen((scanResults) {
      results
        ..clear()
        ..addAll(scanResults);
    });

    await Future.delayed(const Duration(seconds: 4));
    await FlutterBluePlus.stopScan();
    await subscription.cancel();

    // De-duplicate by device ID and drop entries with no name at all,
    // since unnamed devices aren't useful for a user to pick from.
    final Map<String, ScanResult> uniqueResults = {};
    for (final result in results) {
      if (result.device.platformName.isNotEmpty) {
        uniqueResults[result.device.remoteId.toString()] = result;
      }
    }

    return uniqueResults.values.toList();
  }

  // Checks whether a specific previously-linked device is currently
  // in range, and returns its signal strength (RSSI) if found. A
  // stronger (less negative) RSSI roughly means the device is closer.
  Future<int?> checkDeviceSignal(String deviceId) async {
    final List<ScanResult> results = [];

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));

    final subscription = FlutterBluePlus.scanResults.listen((scanResults) {
      results
        ..clear()
        ..addAll(scanResults);
    });

    await Future.delayed(const Duration(seconds: 4));
    await FlutterBluePlus.stopScan();
    await subscription.cancel();

    for (final result in results) {
      if (result.device.remoteId.toString() == deviceId) {
        return result.rssi;
      }
    }

    return null; // device not found nearby
  }

  // Translates a raw RSSI value into a plain-English proximity
  // description — this is the "smart" interpretation layer, since raw
  // dBm numbers mean very little to an ordinary user.
  static String describeSignal(int? rssi) {
    if (rssi == null) return 'Not detected nearby';
    if (rssi > -60) return 'Very close (same room)';
    if (rssi > -80) return 'Nearby (within a few meters)';
    return 'Detected, but far away';
  }
}