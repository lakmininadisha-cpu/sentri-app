import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import '../models/item.dart';
import '../services/location_service.dart';
import '../services/prediction_service.dart';
import '../services/bluetooth_service.dart';
import '../widgets/app_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'add_item_screen.dart';

// Shows details for a single item: its photo, a map of its last known
// location, a manual "update location" check-in, a rule-based prediction
// of where it probably is, a Bluetooth tracker link/check, and a
// timeline of past location check-ins.
class ItemDetailScreen extends StatefulWidget {
  final Item item;

  const ItemDetailScreen({super.key, required this.item});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  bool _isUpdatingLocation = false;
  List<PredictionResult>? _predictions;
  bool _isPredicting = false;
  bool _isScanning = false;
  int? _lastRssi;
  bool _hasCheckedSignal = false;

  double? _currentLat;
  double? _currentLng;

  @override
  void initState() {
    super.initState();
    _currentLat = widget.item.lastLatitude;
    _currentLng = widget.item.lastLongitude;
  }

  // Same one-time explainer used in Add Item — shown at most once
  // across the whole app, regardless of which screen triggers the
  // first location request.
  Future<Position?> _getLocationWithPriming() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyPrimed = prefs.getBool('hasSeenLocationPrimer') ?? false;

    if (!alreadyPrimed && mounted) {
      final continueRequested = await showPermissionPrimer(
        context,
        icon: Icons.my_location,
        color: kBlue,
        title: 'Sentri would like your location',
        message: 'This lets Sentri remember where your items were last seen, so it can predict where a lost item probably is.',
      );
      await prefs.setBool('hasSeenLocationPrimer', true);
      if (!continueRequested) return null;
    }

    return LocationService().getCurrentLocation();
  }

  Future<void> _updateLocation() async {
    setState(() => _isUpdatingLocation = true);
    try {
      final position = await _getLocationWithPriming();
      if (position == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not get current location. Check location permissions.')),
          );
        }
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final itemRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('items').doc(widget.item.id);

      await itemRef.update({
        'lastLatitude': position.latitude,
        'lastLongitude': position.longitude,
        'lastSeenAt': Timestamp.now(),
      });

      setState(() {
        _currentLat = position.latitude;
        _currentLng = position.longitude;
      });

      await itemRef.collection('locationHistory').add({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': Timestamp.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location updated.')));
      }
    } finally {
      if (mounted) setState(() => _isUpdatingLocation = false);
    }
  }

  Future<void> _runPrediction() async {
    setState(() => _isPredicting = true);
    try {
      final results = await PredictionService().predictLocation(widget.item.id);
      setState(() => _predictions = results);
    } finally {
      if (mounted) setState(() => _isPredicting = false);
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete this item?'),
        content: Text('This will permanently remove "${widget.item.name}" and its location history.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed != true) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('items').doc(widget.item.id).delete();
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _linkBluetoothDevice() async {
    setState(() => _isScanning = true);
    try {
      final devices = await BluetoothTrackerService().scanNearbyDevices();
      if (!mounted) return;

      if (devices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No nearby Bluetooth devices found. Make sure Bluetooth is on.')),
        );
        return;
      }

      final selected = await showModalBottomSheet<ScanResult>(
        context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) {
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: devices.map((result) {
                return ListTile(
                  leading: const Icon(Icons.bluetooth, color: kTeal),
                  title: Text(result.device.platformName),
                  subtitle: Text('Signal: ${result.rssi} dBm'),
                  onTap: () => Navigator.pop(context, result),
                );
              }).toList(),
            ),
          );
        },
      );

      if (selected == null) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('items').doc(widget.item.id).update({
        'bluetoothDeviceId': selected.device.remoteId.toString(),
        'bluetoothDeviceName': selected.device.platformName,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Linked to ${selected.device.platformName}.')));
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _checkBluetoothSignal(String deviceId) async {
    setState(() => _isScanning = true);
    try {
      final rssi = await BluetoothTrackerService().checkDeviceSignal(deviceId);
      setState(() {
        _lastRssi = rssi;
        _hasCheckedSignal = true;
      });
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Scaffold(
      backgroundColor: kBackground,
      body: Stack(
        children: [
          const BackgroundAccents(),
          Column(
            children: [
              GradientHeader(
                title: item.name,
                subtitle: '${item.category} \u00b7 ${item.profileName}',
                actions: [
                  HeaderIconButton(
                    icon: Icons.edit_outlined,
                    tooltip: 'Edit item',
                    onPressed: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (context) => AddItemScreen(existingItem: widget.item)));
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                  HeaderIconButton(icon: Icons.delete_outline, tooltip: 'Delete item', onPressed: () => _confirmDelete(context)),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      Center(
                        child: Hero(
                          tag: 'item-photo-${item.id}',
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
                            ),
                            child: item.photoBase64 != null
                                ? ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.memory(base64Decode(item.photoBase64!), fit: BoxFit.cover))
                                : Center(child: Icon(Icons.inventory_2_outlined, size: 44, color: _itemColor(item.color))),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      SentriCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _detailRow(Icons.flag_outlined, 'Priority', item.priority[0].toUpperCase() + item.priority.substring(1)),
                            const Divider(height: 20),
                            _detailRow(Icons.palette_outlined, 'Colour tag', ''),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      if (item.notes != null && item.notes!.trim().isNotEmpty) ...[
                        SentriCard(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.notes_outlined, size: 18, color: Colors.grey),
                              const SizedBox(width: 10),
                              Expanded(child: Text(item.notes!, style: const TextStyle(height: 1.4))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      if (_currentLat != null && _currentLng != null) ...[
                        _sectionTitle('Location', Icons.map_outlined, kBlue),
                        const SizedBox(height: 8),
                        SentriCard(
                          padding: EdgeInsets.zero,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: SizedBox(
                              height: 200,
                              child: FlutterMap(
                                options: MapOptions(initialCenter: latlong.LatLng(_currentLat!, _currentLng!), initialZoom: 15),
                                children: [
                                  TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.sentri_app'),
                                  MarkerLayer(markers: [
                                    Marker(point: latlong.LatLng(_currentLat!, _currentLng!), width: 40, height: 40, child: const Icon(Icons.location_pin, color: Colors.red, size: 40)),
                                  ]),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isUpdatingLocation ? null : _updateLocation,
                              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              icon: _isUpdatingLocation
                                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.my_location, size: 18),
                              label: Text(_isUpdatingLocation ? 'Updating...' : 'Update', style: const TextStyle(fontSize: 13)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isPredicting ? null : _runPrediction,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                backgroundColor: kTeal,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: _isPredicting
                                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.psychology_outlined, size: 18),
                              label: Text(_isPredicting ? 'Thinking...' : 'Predict', style: const TextStyle(fontSize: 13)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (_predictions != null) ...[
                        if (_predictions!.isEmpty)
                          Text('Not enough history yet \u2014 try updating the location a few more times first.', style: TextStyle(color: Colors.grey.shade600))
                        else
                          ..._predictions!.take(3).map((prediction) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: SentriCard(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: const BoxDecoration(color: Color(0xFFEAF6F2), shape: BoxShape.circle),
                                      child: const Icon(Icons.place_outlined, color: kTeal, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('${prediction.confidencePercent.toStringAsFixed(0)}% likely', style: const TextStyle(fontWeight: FontWeight.w700)),
                                          Text('Last seen ${_formatDateTime(prediction.lastSeenAt)}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        const SizedBox(height: 8),
                      ],

                      const SizedBox(height: 8),
                      _sectionTitle('Bluetooth Tracker', Icons.bluetooth, kPink),
                      const SizedBox(height: 8),
                      SentriCard(
                        child: item.bluetoothDeviceName == null
                            ? SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _isScanning ? null : _linkBluetoothDevice,
                                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                  icon: _isScanning ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.bluetooth_searching),
                                  label: Text(_isScanning ? 'Scanning...' : 'Link a Bluetooth Device'),
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.bluetooth_connected, color: kBlue),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(item.bluetoothDeviceName!, style: const TextStyle(fontWeight: FontWeight.w600)),
                                            Text(_hasCheckedSignal ? BluetoothTrackerService.describeSignal(_lastRssi) : 'Not checked yet', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  OutlinedButton.icon(
                                    onPressed: _isScanning ? null : () => _checkBluetoothSignal(item.bluetoothDeviceId!),
                                    style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                    icon: _isScanning ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.wifi_tethering),
                                    label: Text(_isScanning ? 'Checking...' : 'Check Signal Now'),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 20),

                      _sectionTitle('Location Timeline', Icons.history, kGreen),
                      const SizedBox(height: 8),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users').doc(FirebaseAuth.instance.currentUser?.uid)
                            .collection('items').doc(item.id).collection('locationHistory')
                            .orderBy('timestamp', descending: true).limit(10).snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: LoadingView());
                          }
                          final docs = snapshot.data?.docs ?? [];
                          if (docs.isEmpty) {
                            return Text('No location history yet. Tap "Update" to log the first check-in.', style: TextStyle(color: Colors.grey.shade600));
                          }
                          return SentriCard(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              children: docs.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                final lat = (data['latitude'] as num).toDouble();
                                final lng = (data['longitude'] as num).toDouble();
                                final timestamp = (data['timestamp'] as Timestamp).toDate();
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.location_on_outlined, color: kGreen),
                                  title: Text('${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}', style: const TextStyle(fontSize: 13)),
                                  subtitle: Text(_formatDateTime(timestamp), style: const TextStyle(fontSize: 12)),
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
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

  Widget _detailRow(IconData icon, String label, String value) {
    final item = widget.item;
    if (label == 'Colour tag') {
      return Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          const Spacer(),
          Container(width: 20, height: 20, decoration: BoxDecoration(shape: BoxShape.circle, color: _itemColor(item.color))),
        ],
      );
    }
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: Colors.grey.shade600)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Color _itemColor(String? hex) {
    if (hex == null) return kTeal;
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}