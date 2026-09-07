import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/item.dart';
import '../models/family_profile.dart';
import '../services/location_service.dart';
import '../services/weather_service.dart';
import '../services/notification_service.dart';
import '../services/health_service.dart';
import 'add_item_screen.dart';
import 'item_detail_screen.dart';
import 'productivity_summary_screen.dart';
import 'family_screen.dart';
import 'voice_assistant_screen.dart';
import 'routines_screen.dart';
import 'nearby_items_screen.dart';
import 'health_screen.dart';
import 'settings_screen.dart';
import 'package:provider/provider.dart';
import '../state/language_state.dart';
import '../widgets/app_widgets.dart';

// The main screen a logged-in user sees — a colourful header, weather
// and health cards, and a live-updating list of everything registered
// with Sentri.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  WeatherResult? _weather;
  List<DailyForecast> _forecast = [];
  bool _isLoadingWeather = false;
  bool _useFahrenheit = false;

  final HealthService _healthService = HealthService();
  Timer? _inactivityCheckTimer;
  Duration _inactiveDuration = Duration.zero;

  static const Duration _inactivityThreshold = Duration(minutes: 2);

  // Search, filter, and sort state for the item list. All filtering is
  // done client-side over the live Firestore stream, since the app's
  // scale (one user's own belongings) makes that simpler and just as
  // fast as composing multiple Firestore where-clauses.
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _categoryFilter = 'All';
  String _priorityFilter = 'All';
  String _personFilter = 'All';
  String _sortOption = 'Newest';
  bool _showFilters = false;
  List<FamilyProfile> _familyProfiles = [];
  bool _showWelcomeBanner = false;
  String? _welcomeName;

  @override
  void initState() {
    super.initState();
    _loadTemperatureUnitPreference();
    _loadWeather();
    _loadFamilyProfiles();
    _checkFirstVisit();
    _healthService.startTracking();
    _inactivityCheckTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      setState(() {
        _inactiveDuration = _healthService.inactiveDuration;
      });
    });
  }

  // Shows a friendly, one-time welcome banner the very first time a
  // user reaches Home after signing up — a small personal touch that
  // costs nothing to build since we already have their profile name
  // in Firestore, and dismisses itself permanently once seen.
  Future<void> _checkFirstVisit() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadySeen = prefs.getBool('hasSeenWelcomeBanner') ?? false;
    if (alreadySeen) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final name = (doc.data()?['name'] as String?)?.trim();

    if (mounted) {
      setState(() {
        _showWelcomeBanner = true;
        _welcomeName = (name != null && name.isNotEmpty) ? name.split(' ').first : null;
      });
    }
  }

  Future<void> _dismissWelcomeBanner() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenWelcomeBanner', true);
    if (mounted) setState(() => _showWelcomeBanner = false);
  }

  Future<void> _loadTemperatureUnitPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _useFahrenheit = prefs.getBool('useFahrenheit') ?? false);
  }

  Future<void> _toggleTemperatureUnit() async {
    final prefs = await SharedPreferences.getInstance();
    final newValue = !_useFahrenheit;
    await prefs.setBool('useFahrenheit', newValue);
    if (mounted) setState(() => _useFahrenheit = newValue);
  }

  double _displayTemp(double celsius) => _useFahrenheit ? WeatherService.celsiusToFahrenheit(celsius) : celsius;
  String get _unitLabel => _useFahrenheit ? '\u00b0F' : '\u00b0C';

  Future<void> _loadFamilyProfiles() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('familyProfiles').get();
    if (mounted) {
      setState(() => _familyProfiles = snapshot.docs.map((doc) => FamilyProfile.fromFirestore(doc)).toList());
    }
  }

  @override
  void dispose() {
    _healthService.stopTracking();
    _inactivityCheckTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadWeather() async {
    setState(() => _isLoadingWeather = true);
    try {
      final position = await LocationService().getCurrentLocation();
      if (position == null) return;
      final weatherService = WeatherService();
      final result = await weatherService.getCurrentWeather(position);
      final forecast = await weatherService.getForecast(position);
      if (mounted) {
        setState(() {
          _weather = result;
          _forecast = forecast;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingWeather = false);
    }
  }

  Future<void> _checkBeforeLeaving(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Reuse whatever weather we already loaded for the home screen,
    // rather than making a second API call just for this check.
    String? weatherNote;
    if (_weather != null && WeatherService.isRainy(_weather!.condition)) {
      weatherNote = '\u2614 ${_weather!.suggestion}';
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('items')
        .where('priority', isEqualTo: 'high')
        .get();

    final items = snapshot.docs.map((doc) => Item.fromFirestore(doc)).toList();
    final staleItems = items.where((item) {
      if (item.lastSeenAt == null) return true;
      final hoursSinceSeen = DateTime.now().difference(item.lastSeenAt!).inHours;
      return hoursSinceSeen > 6;
    }).toList();

    if (staleItems.isEmpty && weatherNote == null) {
      await NotificationService().showNotification(
        id: 1,
        title: 'All good!',
        body: items.isEmpty
            ? 'No high-priority items registered, and no weather concerns right now.'
            : 'All your high-priority items have been recently checked.',
      );
    } else {
      final parts = <String>[];
      if (staleItems.isNotEmpty) {
        final itemNames = staleItems.map((item) => item.name).join(', ');
        parts.add('Check that you have: $itemNames');
      }
      if (weatherNote != null) {
        parts.add(weatherNote);
      }
      await NotificationService().showNotification(
        id: 1,
        title: 'Before you leave...',
        body: parts.join('\n'),
      );
    }
  }

  // Applies the current search text, category/priority/person filters,
  // and chosen sort order to a list of items. All done client-side
  // over the already-live Firestore stream.
  List<Item> _applyFiltersAndSort(List<Item> items) {
    var result = items.where((item) {
      final matchesSearch = _searchQuery.isEmpty || item.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _categoryFilter == 'All' || item.category == _categoryFilter;
      final matchesPriority = _priorityFilter == 'All' || item.priority == _priorityFilter.toLowerCase();
      final matchesPerson = _personFilter == 'All' || item.profileName == _personFilter;
      return matchesSearch && matchesCategory && matchesPriority && matchesPerson;
    }).toList();

    switch (_sortOption) {
      case 'Priority':
        const order = {'high': 0, 'medium': 1, 'low': 2};
        result.sort((a, b) => (order[a.priority] ?? 3).compareTo(order[b.priority] ?? 3));
        break;
      case 'Name (A-Z)':
        result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case 'Newest':
      default:
        result.sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
    }

    return result;
  }

  bool get _hasActiveFilters => _categoryFilter != 'All' || _priorityFilter != 'All' || _personFilter != 'All' || _sortOption != 'Newest';

  Widget _buildSearchAndFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search your items...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: IconButton(
                  icon: const Icon(Icons.near_me_outlined, color: kBlue),
                  tooltip: 'Nearby items',
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NearbyItemsScreen())),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: _hasActiveFilters ? kTeal : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: IconButton(
                  icon: Icon(Icons.tune, color: _hasActiveFilters ? Colors.white : kTeal),
                  tooltip: 'Filter \u0026 sort',
                  onPressed: () => setState(() => _showFilters = !_showFilters),
                ),
              ),
            ],
          ),
          if (_showFilters) ...[
            const SizedBox(height: 10),
            SentriCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _filterDropdown('Category', _categoryFilter, ['All', ..._categories], (v) => setState(() => _categoryFilter = v!)),
                  const SizedBox(height: 10),
                  _filterDropdown('Priority', _priorityFilter, const ['All', 'High', 'Medium', 'Low'], (v) => setState(() => _priorityFilter = v!)),
                  const SizedBox(height: 10),
                  _filterDropdown('Person', _personFilter, ['All', 'Me', ..._familyProfiles.map((p) => p.name)], (v) => setState(() => _personFilter = v!)),
                  const SizedBox(height: 10),
                  _filterDropdown('Sort by', _sortOption, const ['Newest', 'Priority', 'Name (A-Z)'], (v) => setState(() => _sortOption = v!)),
                  if (_hasActiveFilters) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => setState(() {
                          _categoryFilter = 'All';
                          _priorityFilter = 'All';
                          _personFilter = 'All';
                          _sortOption = 'Newest';
                        }),
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Clear filters'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static const _categories = [
    'Wallet', 'Keys', 'Laptop', 'Bag', 'Backpack', 'Passport', 'Phone',
    'Documents', 'Office ID', 'Glasses', 'Umbrella', 'Charger',
    'Headphones', 'Watch', 'Jewelry', 'Other',
  ];

  Widget _filterDropdown(String label, String value, List<String> options, ValueChanged<String?> onChanged) {
    return Row(
      children: [
        SizedBox(width: 70, child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5))),
        Expanded(
          child: DropdownButton<String>(
            value: options.contains(value) ? value : options.first,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            style: const TextStyle(color: Color(0xFF20241F), fontSize: 13.5, fontWeight: FontWeight.w600),
            items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      body: Stack(
        children: [
          // Soft background blobs continuing the header's colour theme
          // down into the body, so the white area doesn't feel like an
          // abrupt cutoff below the header.
          Positioned(
            top: 180, right: -60,
            child: Container(
              width: 160, height: 160,
              decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF0F6E56).withValues(alpha: 0.04)),
            ),
          ),
          Positioned(
            top: 420, left: -50,
            child: Container(
              width: 140, height: 140,
              decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF0F6E56).withValues(alpha: 0.035)),
            ),
          ),
          CustomScrollView(
        slivers: [
          // ---------- Colourful header ----------
          SliverToBoxAdapter(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 150,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0F6E56), Color(0xFF17936F)],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28),
                    ),
                  ),
                ),
                // Decorative translucent circles
                Positioned(
                  top: -30, right: -20,
                  child: Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08)),
                  ),
                ),
                Positioned(
                  top: 40, right: 60,
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.10)),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 6, 0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.shield_outlined, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Sentri',
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.visible,
                            style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700),
                          ),
                        ),
                        _headerIconButton(Icons.mic_none_outlined, 'Ask Sentri', () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const VoiceAssistantScreen()));
                        }),
                        _headerIconButton(Icons.family_restroom_outlined, 'Family members', () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const FamilyScreen()));
                        }),
                        _headerIconButton(Icons.checklist_outlined, 'Routines', () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const RoutinesScreen()));
                        }),
                        _headerIconButton(Icons.bar_chart_outlined, 'Weekly summary', () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductivitySummaryScreen()));
                        }),
                        _headerIconButton(Icons.exit_to_app, 'Leaving check', () => _checkBeforeLeaving(context)),
                        _headerIconButton(Icons.settings_outlined, 'Settings', () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          SliverToBoxAdapter(child: _buildWelcomeBanner()),
          SliverToBoxAdapter(child: _buildWeatherCard()),
          SliverToBoxAdapter(child: _buildHealthEntryCard()),
          SliverToBoxAdapter(child: _buildHealthCard()),
          SliverToBoxAdapter(child: _buildSearchAndFilterBar()),

          // ---------- Item list ----------
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user?.uid)
                .collection('items')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: SkeletonListView(),
                );
              }

              if (snapshot.hasError) {
                return SliverFillRemaining(
                  child: Center(child: Text('Something went wrong: ${snapshot.error}')),
                );
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.inventory_2_outlined,
                    color: kTeal,
                    title: 'Nothing registered yet',
                    message: 'Register your wallet, keys, laptop, or anything else you don\'t want to lose.',
                    actionLabel: 'Add Your First Item',
                    onAction: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddItemScreen())),
                  ),
                );
              }

              var items = docs.map((doc) => Item.fromFirestore(doc)).toList();
              items = _applyFiltersAndSort(items);

              if (items.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text('No items match your search or filters', style: TextStyle(color: Colors.grey.shade600), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = items[index];
                      return StaggeredListItem(
                        index: index,
                        child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => ItemDetailScreen(item: item)),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
                            ],
                          ),
                          child: Row(
                            children: [
                              Hero(
                                tag: 'item-photo-${item.id}',
                                child: Container(
                                  padding: const EdgeInsets.all(2.5),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: _itemColor(item.color), width: 2.5),
                                  ),
                                  child: item.photoBase64 != null
                                      ? CircleAvatar(
                                          radius: 24,
                                          backgroundImage: MemoryImage(base64Decode(item.photoBase64!)),
                                        )
                                      : CircleAvatar(
                                          radius: 24,
                                          backgroundColor: _itemColor(item.color).withValues(alpha: 0.15),
                                          child: Icon(Icons.inventory_2_outlined, color: _itemColor(item.color)),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                    const SizedBox(height: 2),
                                    Text('${item.category} \u00b7 ${item.profileName}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
                                  ],
                                ),
                              ),
                              _priorityBadge(item.priority),
                            ],
                          ),
                        ),
                        ),
                      );
                    },
                    childCount: items.length,
                  ),
                ),
              );
            },
          ),
        ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0F6E56),
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const AddItemScreen()));
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _headerIconButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, color: Colors.white, size: 18),
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
    );
  }

  Widget _buildWeatherCard() {
    if (_isLoadingWeather) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: LinearProgressIndicator(),
      );
    }
    if (_weather == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFEAF6F2), Color(0xFFDCF0E8)]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(color: Color(0xFF0F6E56), shape: BoxShape.circle),
                child: Icon(_weatherIcon(_weather!.condition), size: 24, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_displayTemp(_weather!.temperatureCelsius).toStringAsFixed(0)}$_unitLabel \u00b7 ${_weather!.description}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(_weather!.suggestion, style: const TextStyle(color: Colors.black87, fontSize: 12.5)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _toggleTemperatureUnit,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(20)),
                  child: Text(_useFahrenheit ? '\u00b0F' : '\u00b0C', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF0F6E56))),
                ),
              ),
            ],
          ),
          if (_forecast.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            SizedBox(
              height: 76,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _forecast.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final day = _forecast[index];
                  return Container(
                    width: 62,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_weekdayLabel(day.date), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF20241F))),
                        const SizedBox(height: 4),
                        Icon(_weatherIcon(day.condition), size: 18, color: const Color(0xFF0F6E56)),
                        const SizedBox(height: 4),
                        Text('${_displayTemp(day.temperatureCelsius).toStringAsFixed(0)}\u00b0', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _weekdayLabel(DateTime date) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[date.weekday - 1];
  }

  Widget _buildWelcomeBanner() {
    if (!_showWelcomeBanner) return const SizedBox.shrink();
    final lang = context.watch<LanguageState>();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [kTeal, kTealDark]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
            child: const Icon(Icons.waving_hand_outlined, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _welcomeName != null ? lang.t('welcome_banner_named').replaceFirst('{name}', _welcomeName!) : lang.t('welcome_banner_default'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 3),
                Text(
                  lang.t('welcome_banner_subtitle'),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 18),
            onPressed: _dismissWelcomeBanner,
          ),
        ],
      ),
    );
  }

  Widget _buildHealthEntryCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HealthScreen())),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: const BoxDecoration(color: kCoral, shape: BoxShape.circle),
                child: const Icon(Icons.favorite_outline, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('View your steps, water intake, and weekly trend', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHealthCard() {
    final isInactiveTooLong = _inactiveDuration >= _inactivityThreshold;
    if (!isInactiveTooLong) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFF3E0), Color(0xFFFFE8CC)]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
            child: const Icon(Icons.directions_walk, size: 24, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('You\'ve been still for a while', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(
                  'It\'s been ${_inactiveDuration.inMinutes} minutes without much movement \u2014 maybe take a short walk.',
                  style: const TextStyle(color: Colors.black87, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _weatherIcon(String condition) {
    switch (condition) {
      case 'Rain':
      case 'Drizzle':
        return Icons.umbrella;
      case 'Thunderstorm':
        return Icons.thunderstorm;
      case 'Clear':
        return Icons.wb_sunny;
      case 'Clouds':
        return Icons.cloud;
      default:
        return Icons.wb_cloudy;
    }
  }

  Color _itemColor(String? hex) {
    if (hex == null) return const Color(0xFF0F6E56);
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  }

  Widget _priorityBadge(String priority) {
    final color = priority == 'high' ? Colors.red : (priority == 'low' ? Colors.green : Colors.orange);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        priority[0].toUpperCase() + priority.substring(1),
        style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// A hand-drawn-feeling empty state built entirely from shapes and icons —
// no external image asset needed. A soft blob behind a layered
// box+magnifier icon composition, in the app's own colour palette.
class _EmptyStateIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 180,
              height: 180,
              child: CustomPaint(
                painter: _BlobPainter(),
                child: const Center(
                  child: Icon(Icons.inventory_2_outlined, size: 64, color: Color(0xFF0F6E56)),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Nothing registered yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF20241F)),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button below to register your wallet, keys, laptop, or anything else you don\'t want to lose.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13.5),
            ),
          ],
        ),
      ),
    );
  }
}

// Draws a soft, organic blob shape (not a plain circle) behind the icon,
// purely with math — this is what gives the empty state a slightly more
// "illustrated" feel instead of looking like a placeholder.
class _BlobPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFEAF6F2);
    final center = Offset(size.width / 2, size.height / 2);
    final path = Path();
    const points = 8;
    for (int i = 0; i <= points; i++) {
      final angle = (i / points) * 2 * math.pi;
      final radius = (size.width / 2) * (0.85 + 0.15 * math.sin(angle * 3));
      final point = Offset(center.dx + radius * math.cos(angle), center.dy + radius * math.sin(angle));
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}