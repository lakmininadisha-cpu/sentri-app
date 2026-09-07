// ML Kit's image labeling model returns fairly generic, general-purpose
// labels (it's not specifically trained on personal belongings). This
// maps those general labels to the categories Sentri actually uses, so
// the suggestion feels relevant instead of showing a raw ML Kit term
// the user has never heard of.
class LabelCategoryMapper {
  static const Map<String, String> _keywordToCategory = {
    'bag': 'Bag',
    'luggage': 'Bag',
    'handbag': 'Bag',
    'backpack': 'Backpack',
    'wallet': 'Wallet',
    'mobile phone': 'Phone',
    'telephone': 'Phone',
    'smartphone': 'Phone',
    'laptop': 'Laptop',
    'computer': 'Laptop',
    'glasses': 'Glasses',
    'sunglasses': 'Glasses',
    'key': 'Keys',
    'umbrella': 'Umbrella',
    'watch': 'Watch',
    'headphones': 'Headphones',
    'earphone': 'Headphones',
    'jewellery': 'Jewelry',
    'jewelry': 'Jewelry',
    'passport': 'Passport',
    'book': 'Documents',
    'paper': 'Documents',
    'card': 'Office ID',
  };

  // Goes through the labels ML Kit returned (already sorted by
  // confidence) and returns the first one that matches something in
  // our category list. Returns null if nothing recognisable matched.
  static String? suggestCategory(List<String> labels) {
    for (final label in labels) {
      final lowerLabel = label.toLowerCase();
      for (final keyword in _keywordToCategory.keys) {
        if (lowerLabel.contains(keyword)) {
          return _keywordToCategory[keyword];
        }
      }
    }
    return null;
  }
}