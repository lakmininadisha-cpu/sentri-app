import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/family_profile.dart';
import '../widgets/app_widgets.dart';

// Lets the primary account holder add family members (e.g. a child)
// so items like school bags or smartwatches can be tracked under a
// named profile without that person needing their own separate login.
class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final _nameController = TextEditingController();
  String _selectedRelation = 'Child';
  final List<String> _relations = ['Child', 'Spouse', 'Parent', 'Sibling', 'Other'];

  final List<Color> _avatarColors = [kTeal, kBlue, kCoral, kAmber, kPurple];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addProfile() async {
    if (_nameController.text.trim().isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final profile = FamilyProfile(id: '', name: _nameController.text.trim(), relation: _selectedRelation);
    await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('familyProfiles').add(profile.toFirestore());

    _nameController.clear();
    if (mounted) Navigator.pop(context);
  }

  void _showAddProfileSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16), alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const Text('Add Family Member', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Name', hintText: 'e.g. Kavindi',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedRelation,
                decoration: InputDecoration(labelText: 'Relation', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                items: _relations.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (value) { if (value != null) setState(() => _selectedRelation = value); },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _addProfile,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), backgroundColor: kTeal, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Add'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteProfile(String profileId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('familyProfiles').doc(profileId).delete();
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
              const GradientHeader(title: 'Family Members', subtitle: 'Keep an eye on their things too'),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).collection('familyProfiles').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const SkeletonListView();
                    if (snapshot.hasError) return ErrorView(message: 'Something went wrong: ${snapshot.error}');

                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return EmptyState(
                        icon: Icons.family_restroom_outlined,
                        color: kPink,
                        title: 'No family members yet',
                        message: 'Add someone whose belongings you want to help keep track of.',
                        actionLabel: 'Add Family Member',
                        onAction: _showAddProfileSheet,
                      );
                    }

                    final profiles = docs.map((doc) => FamilyProfile.fromFirestore(doc)).toList();
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: profiles.length,
                      itemBuilder: (context, index) {
                        final profile = profiles[index];
                        final color = _avatarColors[index % _avatarColors.length];
                        return StaggeredListItem(
                          index: index,
                          child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: SentriCard(
                            child: Row(
                              children: [
                                CircleAvatar(radius: 22, backgroundColor: color.withValues(alpha: 0.15), child: Icon(Icons.person_outline, color: color)),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(profile.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                      Text(profile.relation, style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
                                    ],
                                  ),
                                ),
                                IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _deleteProfile(profile.id)),
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
        onPressed: _showAddProfileSheet,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}