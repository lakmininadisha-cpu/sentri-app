import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/item.dart';
import '../models/family_profile.dart';
import '../services/location_service.dart';
import '../services/image_recognition_service.dart';
import '../services/label_category_mapper.dart';
import '../widgets/app_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

// Form for registering a new belonging, or editing an existing one.
// Pass an existingItem to switch the screen into edit mode.
class AddItemScreen extends StatefulWidget {
  final Item? existingItem;

  const AddItemScreen({super.key, this.existingItem});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _notesController;

  late String _selectedCategory;
  late String _selectedPriority;
  late String _selectedColorHex;
  File? _pickedImage;
  String? _existingPhotoBase64;
  bool _isSaving = false;

  bool _isAnalyzingPhoto = false;
  String? _detectedSuggestion;

  List<FamilyProfile> _familyProfiles = [];
  late String _selectedProfileId;
  late String _selectedProfileName;

  final List<String> _categories = [
    'Wallet', 'Keys', 'Laptop', 'Bag', 'Backpack', 'Passport', 'Phone',
    'Documents', 'Office ID', 'Glasses', 'Umbrella', 'Charger',
    'Headphones', 'Watch', 'Jewelry', 'Other',
  ];

  final List<String> _colorOptions = [
    '#0F6E56', '#E24B4A', '#378ADD', '#FAC775', '#7F77DD', '#639922', '#888780', '#D46FB3',
  ];

  bool get _isEditing => widget.existingItem != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingItem;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _notesController = TextEditingController(text: existing?.notes ?? '');
    _selectedCategory = existing?.category ?? _categories.first;
    _selectedPriority = existing?.priority ?? 'medium';
    _selectedColorHex = existing?.color ?? '#0F6E56';
    _existingPhotoBase64 = existing?.photoBase64;
    _selectedProfileId = existing?.profileId ?? 'self';
    _selectedProfileName = existing?.profileName ?? 'Me';
    _loadFamilyProfiles();
  }

  Future<void> _loadFamilyProfiles() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users').doc(user.uid).collection('familyProfiles').get();

    setState(() {
      _familyProfiles = snapshot.docs.map((doc) => FamilyProfile.fromFirestore(doc)).toList();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined, color: kTeal),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: kTeal),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, maxWidth: 600, imageQuality: 60);

    if (pickedFile != null) {
      setState(() {
        _pickedImage = File(pickedFile.path);
        _existingPhotoBase64 = null;
      });
      await _analyzePhoto(File(pickedFile.path));
    }
  }

  Future<void> _analyzePhoto(File imageFile) async {
    setState(() => _isAnalyzingPhoto = true);
    try {
      final recognitionService = ImageRecognitionService();
      final labels = await recognitionService.recognizeLabels(imageFile);
      recognitionService.dispose();

      final suggestedCategory = LabelCategoryMapper.suggestCategory(labels);
      if (suggestedCategory != null && _categories.contains(suggestedCategory)) {
        setState(() {
          _detectedSuggestion = suggestedCategory;
          _selectedCategory = suggestedCategory;
        });
      }
    } finally {
      if (mounted) setState(() => _isAnalyzingPhoto = false);
    }
  }

  // Shows a friendly explanation of why Sentri wants location access,
  // but only the very first time this happens anywhere in the app —
  // after that, the OS permission dialog (or silent grant, if already
  // allowed) proceeds directly without repeating the explainer.
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

  Future<void> _saveItem() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please give this item a name first.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String? photoBase64 = _existingPhotoBase64;
      if (_pickedImage != null) {
        final bytes = await _pickedImage!.readAsBytes();
        photoBase64 = base64Encode(bytes);
      }

      final itemsRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('items');

      if (_isEditing) {
        await itemsRef.doc(widget.existingItem!.id).update({
          'name': _nameController.text.trim(),
          'category': _selectedCategory,
          'priority': _selectedPriority,
          'color': _selectedColorHex,
          'photoBase64': photoBase64,
          'notes': _notesController.text.trim(),
          'profileId': _selectedProfileId,
          'profileName': _selectedProfileName,
        });
      } else {
        final position = await _getLocationWithPriming();
        final newItem = Item(
          id: '',
          profileId: _selectedProfileId,
          profileName: _selectedProfileName,
          name: _nameController.text.trim(),
          category: _selectedCategory,
          priority: _selectedPriority,
          color: _selectedColorHex,
          photoBase64: photoBase64,
          notes: _notesController.text.trim(),
          lastLatitude: position?.latitude,
          lastLongitude: position?.longitude,
          lastSeenAt: position != null ? DateTime.now() : null,
        );
        await itemsRef.add(newItem.toFirestore());
      }

      if (mounted) {
        await showSuccessAnimation(context, message: _isEditing ? 'Updated!' : 'Item saved!');
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Couldn\'t save item: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
              GradientHeader(
                title: _isEditing ? 'Edit Item' : 'Add Item',
                subtitle: _isEditing ? 'Update the details below' : 'Takes less than a minute',
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Photo picker
                      Center(
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
                            ),
                            child: _buildImagePreview(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text('Tap to add a photo', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                      ),
                      const SizedBox(height: 16),

                      if (_isAnalyzingPhoto)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2, color: kTeal)),
                              SizedBox(width: 10),
                              Text('Analyzing photo...', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),

                      if (_detectedSuggestion != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: const Color(0xFFEAF6F2), borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              const Icon(Icons.auto_awesome, color: kTeal, size: 20),
                              const SizedBox(width: 10),
                              Expanded(child: Text('This looks like a $_detectedSuggestion. Category set automatically.')),
                            ],
                          ),
                        ),

                      // Form card
                      SentriCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Item name',
                                hintText: 'e.g. Office ID Card',
                                prefixIcon: const Icon(Icons.label_outline),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(height: 14),

                            DropdownButtonFormField<String>(
                              initialValue: _selectedCategory,
                              decoration: InputDecoration(
                                labelText: 'Category',
                                prefixIcon: const Icon(Icons.category_outlined),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                              onChanged: (value) {
                                if (value != null) setState(() => _selectedCategory = value);
                              },
                            ),
                            const SizedBox(height: 14),

                            DropdownButtonFormField<String>(
                              initialValue: _selectedProfileId,
                              decoration: InputDecoration(
                                labelText: 'Whose item is this?',
                                prefixIcon: const Icon(Icons.person_outline),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: [
                                const DropdownMenuItem(value: 'self', child: Text('Me')),
                                ..._familyProfiles.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  _selectedProfileId = value;
                                  _selectedProfileName = value == 'self' ? 'Me' : _familyProfiles.firstWhere((p) => p.id == value).name;
                                });
                              },
                            ),
                            const SizedBox(height: 18),

                            const Align(alignment: Alignment.centerLeft, child: Text('Color', style: TextStyle(fontWeight: FontWeight.w600))),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12,
                              children: _colorOptions.map((hex) {
                                final isSelected = _selectedColorHex == hex;
                                final color = Color(int.parse(hex.replaceFirst('#', '0xFF')));
                                return GestureDetector(
                                  onTap: () => setState(() => _selectedColorHex = hex),
                                  child: Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: isSelected ? Border.all(color: Colors.black87, width: 3) : null,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 18),

                            TextField(
                              controller: _notesController,
                              maxLines: 3,
                              decoration: InputDecoration(
                                labelText: 'Notes (optional)',
                                hintText: 'e.g. distinctive marks, contents, where it\'s usually kept',
                                alignLabelWithHint: true,
                                prefixIcon: const Padding(padding: EdgeInsets.only(bottom: 40), child: Icon(Icons.notes_outlined)),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(height: 18),

                            const Align(alignment: Alignment.centerLeft, child: Text('Priority', style: TextStyle(fontWeight: FontWeight.w600))),
                            const SizedBox(height: 8),
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(value: 'low', label: Text('Low')),
                                ButtonSegment(value: 'medium', label: Text('Medium')),
                                ButtonSegment(value: 'high', label: Text('High')),
                              ],
                              selected: {_selectedPriority},
                              onSelectionChanged: (selection) => setState(() => _selectedPriority = selection.first),
                              style: SegmentedButton.styleFrom(selectedBackgroundColor: kTeal, selectedForegroundColor: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      BouncyTap(
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveItem,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: kTeal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isSaving
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(_isEditing ? 'Save Changes' : 'Save Item'),
                        ),
                      ),
                      const SizedBox(height: 20),
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

  Widget _buildImagePreview() {
    if (_pickedImage != null) {
      return ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.file(_pickedImage!, fit: BoxFit.cover));
    }
    if (_existingPhotoBase64 != null) {
      return ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.memory(base64Decode(_existingPhotoBase64!), fit: BoxFit.cover));
    }
    return const Icon(Icons.add_a_photo_outlined, size: 36, color: kTeal);
  }
}