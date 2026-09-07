import '../models/item.dart';

// A lightweight, rule-based parser for voice queries like "where are my
// keys" or "find my wallet". Rather than using a full NLP model (which
// would need a paid API and internet connection), this simply checks
// whether any of the user's registered item names appear in what they
// said — a transparent, explainable approach appropriate for a
// student project, and one that's honest about not being true NLP.
class VoiceQueryParser {
  static Item? findMentionedItem(String spokenText, List<Item> items) {
    final lowerText = spokenText.toLowerCase();

    for (final item in items) {
      if (lowerText.contains(item.name.toLowerCase())) {
        return item;
      }
    }

    // Also try matching by category, in case the user says something
    // like "where's my phone" and no item is literally named "phone".
    for (final item in items) {
      if (lowerText.contains(item.category.toLowerCase())) {
        return item;
      }
    }

    return null;
  }
}