import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/item.dart';
import '../services/voice_assistant_service.dart';
import '../services/voice_query_parser.dart';
import '../services/gemini_service.dart';
import '../widgets/app_widgets.dart';

// Lets the user ask "Where is my wallet?" out loud and get a spoken +
// on-screen answer, based on that item's last known location. This uses
// on-device speech recognition and a simple rule-based match against
// the user's own registered items — not a full NLP model — which keeps
// it free, offline-capable, and easy to explain in the report.
class VoiceAssistantScreen extends StatefulWidget {
  const VoiceAssistantScreen({super.key});

  @override
  State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen> with SingleTickerProviderStateMixin {
  final VoiceAssistantService _voiceService = VoiceAssistantService();

  bool _isReady = false;
  bool _isListening = false;
  bool _isThinking = false;
  String _transcribedText = '';
  String _responseText = '';

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _setup();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _setup() async {
    final available = await _voiceService.initialize();
    setState(() => _isReady = available);
  }

  void _startListening() {
    setState(() {
      _isListening = true;
      _transcribedText = '';
      _responseText = '';
    });

    _voiceService.startListening(onResult: (text) {
      setState(() => _transcribedText = text);
    });
  }

  Future<void> _stopListeningAndAnswer() async {
    _voiceService.stopListening();
    setState(() {
      _isListening = false;
      _isThinking = true;
    });

    if (_transcribedText.trim().isEmpty) {
      setState(() => _isThinking = false);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('items').get();
    final items = snapshot.docs.map((doc) => Item.fromFirestore(doc)).toList();

    final response = await _getAiResponse(_transcribedText, items) ?? _getFallbackResponse(_transcribedText, items);

    setState(() {
      _responseText = response;
      _isThinking = false;
    });
    await _voiceService.speak(response);
  }

  // Genuine AI-powered understanding: gives Gemini the full list of the
  // user's registered items as context, and lets it interpret the
  // question naturally — meaning it can handle phrasing that never
  // literally mentions an item's name (e.g. "the thing I pay with"
  // correctly matching "Wallet"), which the previous keyword-only
  // matching could never do. Returns null (triggering the fallback
  // below) if the API call fails for any reason — offline, no key
  // configured, quota, etc. — so the feature degrades gracefully
  // rather than breaking entirely.
  Future<String?> _getAiResponse(String question, List<Item> items) async {
    if (items.isEmpty) return null;

    final itemsDescription = items.map((item) {
      final lastSeen = item.lastSeenAt != null
          ? '${DateTime.now().difference(item.lastSeenAt!).inMinutes} minutes ago'
          : 'never recorded';
      return '- ${item.name} (category: ${item.category}, priority: ${item.priority}, last seen: $lastSeen)';
    }).join('\n');

    final prompt = '''
You are Sentri, a friendly assistant inside a lost-item tracking app. The user just asked, out loud: "$question"

Here is the user's full list of registered belongings:
$itemsDescription

Work out which item (if any) they're asking about, even if they don't say its exact name. Reply in one short, natural, spoken-style sentence stating its last-seen time. If nothing in the list plausibly matches, say so briefly and kindly. Do not mention that you are an AI or explain your reasoning — just give the direct spoken answer.
''';

    final aiResponse = await GeminiService().generateText(prompt);
    return aiResponse;
  }

  // The original rule-based keyword match, kept as a safety net for
  // when the AI call is unavailable (see _getAiResponse above).
  String _getFallbackResponse(String question, List<Item> items) {
    final matchedItem = VoiceQueryParser.findMentionedItem(question, items);

    if (matchedItem == null) {
      return 'Sorry, I couldn\'t match that to any of your registered items.';
    } else if (matchedItem.lastSeenAt == null) {
      return 'I don\'t have a recorded location for your ${matchedItem.name} yet.';
    } else {
      final minutesAgo = DateTime.now().difference(matchedItem.lastSeenAt!).inMinutes;
      final timeDescription = minutesAgo < 60 ? '$minutesAgo minutes ago' : '${(minutesAgo / 60).floor()} hours ago';
      return 'Your ${matchedItem.name} was last seen $timeDescription.';
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
              const GradientHeader(title: 'Ask Sentri', subtitle: 'Speak, and Sentri will answer'),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Text('Try asking: "Where is my wallet?"', style: TextStyle(color: Colors.grey.shade600), textAlign: TextAlign.center),
                      const SizedBox(height: 36),

                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final scale = _isListening ? 1.0 + (_pulseController.value * 0.08) : 1.0;
                          return Transform.scale(scale: scale, child: child);
                        },
                        child: GestureDetector(
                          onTap: !_isReady ? null : (_isListening ? _stopListeningAndAnswer : _startListening),
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft, end: Alignment.bottomRight,
                                colors: _isListening ? [kCoral, const Color(0xFFC0392B)] : [kTeal, kTealDark],
                              ),
                              boxShadow: [BoxShadow(color: (_isListening ? kCoral : kTeal).withValues(alpha: 0.35 + (_isListening ? _pulseController.value * 0.25 : 0)), blurRadius: 24 + (_isListening ? _pulseController.value * 12 : 0), offset: const Offset(0, 8))],
                            ),
                            child: Icon(_isListening ? Icons.stop : Icons.mic, color: Colors.white, size: 46),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        !_isReady
                            ? 'Voice recognition not available on this device'
                            : (_isThinking ? 'Thinking...' : (_isListening ? 'Listening... tap to stop' : 'Tap to ask a question')),
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 32),

                      if (_transcribedText.isNotEmpty)
                        SentriCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('YOU SAID', style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                              const SizedBox(height: 6),
                              Text(_transcribedText, style: const TextStyle(fontSize: 16)),
                            ],
                          ),
                        ),

                      if (_responseText.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        SentriCard(
                          color: const Color(0xFFEAF6F2),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: const BoxDecoration(color: kTeal, shape: BoxShape.circle),
                                child: const Icon(Icons.assistant, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 14),
                              Expanded(child: Text(_responseText, style: const TextStyle(fontWeight: FontWeight.w600))),
                            ],
                          ),
                        ),
                      ],
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
}