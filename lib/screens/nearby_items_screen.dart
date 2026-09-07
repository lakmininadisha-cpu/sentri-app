import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../models/item.dart';
import '../services/location_service.dart';
import '../widgets/app_widgets.dart';
import 'item_detail_screen.dart';

// Shows every registered item sorted by how far it currently is from
// the user, using their live GPS position compared against each item's
// last known check-in location. Items with no recorded location are
// listed separately underneath, since distance can't be calculated
// for them.
class NearbyItemsScreen extends StatefulWidget {
  const NearbyItemsScreen({super.key});

  @override
  State<NearbyItemsScreen> createState() => _NearbyItemsScreenState();
}

class _NearbyItemsScreenState extends State<NearbyItemsScreen> {
  Position? _currentPosition;
  bool _isLoadingLocation = true;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    final position = await LocationService().getCurrentLocation();

    setState(() {
      _currentPosition = position;
      _isLoadingLocation = false;
      if (position == null) {
        _locationError = 'Could not get your current location. Check that location permission is granted.';
      }
    });
  }

  // Converts a raw metre distance into a short, friendly label.
  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m away';
    return '${(meters / 1000).toStringAsFixed(1)} km away';
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
                title: 'Nearby Items',
                subtitle: 'Sorted by distance from you right now',
                actions: [
                  HeaderIconButton(icon: Icons.refresh, tooltip: 'Refresh my location', onPressed: _loadCurrentLocation),
                ],
              ),
              Expanded(
                child: _isLoadingLocation
                    ? const SkeletonListView()
                    : _locationError != null
                        ? ErrorView(message: _locationError!, onRetry: _loadCurrentLocation)
                        : StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).collection('items').snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const SkeletonListView();
                              }
                              if (snapshot.hasError) {
                                return ErrorView(message: 'Something went wrong: ${snapshot.error}');
                              }

                              final docs = snapshot.data?.docs ?? [];
                              if (docs.isEmpty) {
                                return const EmptyState(
                                  icon: Icons.near_me_outlined,
                                  color: kBlue,
                                  title: 'No items yet',
                                  message: 'Register a belonging first, and it\'ll show up here once it has a location.',
                                );
                              }

                              final allItems = docs.map((doc) => Item.fromFirestore(doc)).toList();

                              final withLocation = <_ItemWithDistance>[];
                              final withoutLocation = <Item>[];

                              for (final item in allItems) {
                                if (item.lastLatitude != null && item.lastLongitude != null) {
                                  final distance = Geolocator.distanceBetween(
                                    _currentPosition!.latitude,
                                    _currentPosition!.longitude,
                                    item.lastLatitude!,
                                    item.lastLongitude!,
                                  );
                                  withLocation.add(_ItemWithDistance(item, distance));
                                } else {
                                  withoutLocation.add(item);
                                }
                              }

                              withLocation.sort((a, b) => a.distance.compareTo(b.distance));

                              return ListView(
                                padding: const EdgeInsets.all(16),
                                children: [
                                  if (withLocation.isEmpty && withoutLocation.isEmpty)
                                    const EmptyState(
                                      icon: Icons.near_me_outlined,
                                      color: kBlue,
                                      title: 'Nothing to show yet',
                                      message: 'Update an item\'s location from its detail screen to see it here.',
                                    ),
                                  ...withLocation.asMap().entries.map((entry) {
                                    return StaggeredListItem(
                                      index: entry.key,
                                      child: _nearbyItemCard(entry.value.item, _formatDistance(entry.value.distance), kTeal),
                                    );
                                  }),
                                  if (withoutLocation.isNotEmpty) ...[
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      child: Text('No location recorded yet', style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5, fontWeight: FontWeight.w600)),
                                    ),
                                    ...withoutLocation.asMap().entries.map((entry) {
                                      return StaggeredListItem(
                                        index: withLocation.length + entry.key,
                                        child: _nearbyItemCard(entry.value, 'Unknown distance', Colors.grey),
                                      );
                                    }),
                                  ],
                                ],
                              );
                            },
                          ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _nearbyItemCard(Item item, String distanceLabel, Color accentColor) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ItemDetailScreen(item: item))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: SentriCard(
          child: Row(
            children: [
              item.photoBase64 != null
                  ? CircleAvatar(radius: 22, backgroundImage: MemoryImage(base64Decode(item.photoBase64!)))
                  : CircleAvatar(radius: 22, backgroundColor: accentColor.withValues(alpha: 0.12), child: Icon(Icons.inventory_2_outlined, color: accentColor)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    Text(item.category, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.place_outlined, size: 13, color: accentColor),
                    const SizedBox(width: 4),
                    Text(distanceLabel, style: TextStyle(color: accentColor, fontSize: 11.5, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemWithDistance {
  final Item item;
  final double distance;
  _ItemWithDistance(this.item, this.distance);
}