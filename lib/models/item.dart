import 'package:cloud_firestore/cloud_firestore.dart';

// Represents a single belonging the user wants Sentri to keep track of,
// e.g. wallet, laptop, keys, passport.
class Item {
  final String id;
  final String profileId; // which family member this item belongs to
  final String profileName;
  final String name;
  final String category;
  final String priority; // 'high', 'medium', or 'low'
  final String? color;
  final String? photoBase64; // stored as text since we're not using Firebase Storage
  final String? notes;
  final String? bluetoothDeviceId;
  final String? bluetoothDeviceName;
  final double? lastLatitude;
  final double? lastLongitude;
  final DateTime? lastSeenAt;
  final DateTime? createdAt;

  Item({
    required this.id,
    required this.profileId,
    required this.profileName,
    required this.name,
    required this.category,
    required this.priority,
    this.color,
    this.photoBase64,
    this.notes,
    this.bluetoothDeviceId,
    this.bluetoothDeviceName,
    this.lastLatitude,
    this.lastLongitude,
    this.lastSeenAt,
    this.createdAt,
  });

  factory Item.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Item(
      id: doc.id,
      profileId: data['profileId'] ?? 'self',
      profileName: data['profileName'] ?? 'Me',
      name: data['name'] ?? '',
      category: data['category'] ?? '',
      priority: data['priority'] ?? 'medium',
      color: data['color'],
      photoBase64: data['photoBase64'],
      notes: data['notes'],
      bluetoothDeviceId: data['bluetoothDeviceId'],
      bluetoothDeviceName: data['bluetoothDeviceName'],
      lastLatitude: (data['lastLatitude'] as num?)?.toDouble(),
      lastLongitude: (data['lastLongitude'] as num?)?.toDouble(),
      lastSeenAt: (data['lastSeenAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'profileId': profileId,
      'profileName': profileName,
      'name': name,
      'category': category,
      'priority': priority,
      'color': color,
      'photoBase64': photoBase64,
      'notes': notes,
      'bluetoothDeviceId': bluetoothDeviceId,
      'bluetoothDeviceName': bluetoothDeviceName,
      'lastLatitude': lastLatitude,
      'lastLongitude': lastLongitude,
      'lastSeenAt': lastSeenAt != null ? Timestamp.fromDate(lastSeenAt!) : FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}