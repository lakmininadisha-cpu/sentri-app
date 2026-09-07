import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/item.dart';
import '../services/gemini_service.dart';
import '../widgets/app_widgets.dart';

// A simple weekly overview of item activity — how many things the user
// has registered, how many were added recently, and a breakdown by
// priority and category. Built entirely from data already collected
// for the lost-item feature rather than needing a separate system.
class ProductivitySummaryScreen extends StatefulWidget {
  const ProductivitySummaryScreen({super.key});

  @override
  State<ProductivitySummaryScreen> createState() => _ProductivitySummaryScreenState();
}

class _ProductivitySummaryScreenState extends State<ProductivitySummaryScreen> {
  bool _isLoading = true;
  List<Item> _items = [];
  String? _aiInsight;
  bool _isLoadingInsight = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('items').get();
    setState(() {
      _items = snapshot.docs.map((doc) => Item.fromFirestore(doc)).toList();
      _isLoading = false;
    });
    _loadAiInsight();
  }

  // Uses Gemini to turn the raw stats into one short, genuinely useful
  // observation — the kind of pattern-spotting a rule-based summary
  // can't really do (e.g. noticing a category is disproportionately
  // high-priority, or that recent additions cluster around one theme).
  // Fails silently if the API call doesn't succeed — the numeric
  // stats and charts below still work fine without it.
  Future<void> _loadAiInsight() async {
    if (_items.isEmpty) return;
    setState(() => _isLoadingInsight = true);

    final highCount = _items.where((i) => i.priority == 'high').length;
    final categoryCounts = <String, int>{};
    for (final item in _items) {
      categoryCounts[item.category] = (categoryCounts[item.category] ?? 0) + 1;
    }
    final categorySummary = categoryCounts.entries.map((e) => '${e.key}: ${e.value}').join(', ');

    final prompt = '''
A user has ${_items.length} belongings registered in a lost-item tracking app. $highCount are marked high priority. Category breakdown: $categorySummary.

Give one short, friendly, specific observation or practical tip based on this data (max 2 sentences). Don't just restate the numbers back — say something genuinely useful about the pattern. Don't mention that you are an AI.
''';

    final insight = await GeminiService().generateText(prompt);
    if (mounted) {
      setState(() {
        _aiInsight = insight;
        _isLoadingInsight = false;
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
              const GradientHeader(title: 'Weekly Summary', subtitle: 'Your Sentri activity at a glance'),
              Expanded(child: _isLoading ? const LoadingView() : _buildSummary()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final now = DateTime.now();
    final oneWeekAgo = now.subtract(const Duration(days: 7));
    final itemsThisWeek = _items.where((item) => item.createdAt != null && item.createdAt!.isAfter(oneWeekAgo)).length;

    final highPriorityCount = _items.where((i) => i.priority == 'high').length;
    final mediumPriorityCount = _items.where((i) => i.priority == 'medium').length;
    final lowPriorityCount = _items.where((i) => i.priority == 'low').length;

    final Map<String, int> categoryCounts = {};
    for (final item in _items) {
      categoryCounts[item.category] = (categoryCounts[item.category] ?? 0) + 1;
    }
    final sortedCategories = categoryCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_isLoadingInsight || _aiInsight != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [kTeal, kTealDark]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _isLoadingInsight
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                        )
                      : Text(_aiInsight!, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4)),
                ),
              ],
            ),
          ),
        ],
        Row(
          children: [
            Expanded(child: _statCard('Total items', _items.length, Icons.inventory_2_outlined, kTeal)),
            const SizedBox(width: 12),
            Expanded(child: _statCard('Added this week', itemsThisWeek, Icons.add_circle_outline, kBlue)),
          ],
        ),
        const SizedBox(height: 20),

        _sectionTitle('Priority Breakdown', Icons.flag_outlined, kAmber),
        const SizedBox(height: 10),
        SentriCard(
          child: Column(
            children: [
              _priorityBar('High', highPriorityCount, _items.length, kCoral),
              const SizedBox(height: 12),
              _priorityBar('Medium', mediumPriorityCount, _items.length, kAmber),
              const SizedBox(height: 12),
              _priorityBar('Low', lowPriorityCount, _items.length, kGreen),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _sectionTitle('Most Tracked Categories', Icons.category_outlined, kPurple),
        const SizedBox(height: 10),
        if (sortedCategories.isEmpty)
          Text('No items registered yet.', style: TextStyle(color: Colors.grey.shade600))
        else
          SentriCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: sortedCategories.take(5).map((entry) {
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.label_outline, color: kPurple, size: 20),
                  title: Text(entry.key),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: kPurple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text('${entry.value}', style: const TextStyle(fontWeight: FontWeight.w700, color: kPurple)),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
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

  Widget _statCard(String label, int value, IconData icon, Color color) {
    return SentriCard(
      color: color.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 10),
          CountUpNumber(value: value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.black87, fontSize: 12.5)),
        ],
      ),
    );
  }

  Widget _priorityBar(String label, int count, int total, Color color) {
    final fraction = total > 0 ? count / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('$count', style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: fraction, minHeight: 8, backgroundColor: Colors.grey.shade200, color: color),
        ),
      ],
    );
  }
}