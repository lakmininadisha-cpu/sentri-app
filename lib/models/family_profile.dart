import 'package:cloud_firestore/cloud_firestore.dart';

// Represents a family member being monitored under the main account —
// e.g. a child whose school bag or smartwatch the parent wants to
// keep track of, without that child needing their own separate login.
class FamilyProfile {
  final String id;
  final String name;
  final String relation; // e.g. "Child", "Spouse", "Parent"

  FamilyProfile({
    required this.id,
    required this.name,
    required this.relation,
  });

  factory FamilyProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FamilyProfile(
      id: doc.id,
      name: data['name'] ?? '',
      relation: data['relation'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'relation': relation,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}