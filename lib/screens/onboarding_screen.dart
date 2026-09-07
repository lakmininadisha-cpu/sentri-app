import 'package:flutter/material.dart';
import '../widgets/app_widgets.dart';

// A short, one-time walkthrough shown right after a user signs up,
// before they reach Home for the first time. Purely introductory —
// no permissions or setup happen here, just a friendly overview of
// what Sentri actually does, so the app doesn't just dump a stranger
// straight into an empty item list with no context.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinished;

  const OnboardingScreen({super.key, required this.onFinished});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<_OnboardingSlide> _slides = const [
    _OnboardingSlide(
      icon: Icons.psychology_outlined,
      color: kTeal,
      title: 'Never lose track again',
      description: 'Sentri learns where your things usually are and warns you before you leave without them — not after.',
    ),
    _OnboardingSlide(
      icon: Icons.family_restroom_outlined,
      color: kPink,
      title: 'Look out for your family too',
      description: 'Add a profile for your kids or anyone else, and keep an eye on their belongings from your own device.',
    ),
    _OnboardingSlide(
      icon: Icons.cloud_outlined,
      color: kBlue,
      title: 'A lifestyle companion, not just a tracker',
      description: 'Weather-aware suggestions, health nudges, and a weekly summary — all built on the same smart engine.',
    ),
    _OnboardingSlide(
      icon: Icons.mic_none_outlined,
      color: kCoral,
      title: 'Just ask',
      description: 'Snap a photo and Sentri suggests the category. Or simply ask out loud: "Where is my wallet?"',
    ),
  ];

  void _next() {
    if (_currentPage < _slides.length - 1) {
      _controller.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    } else {
      _finish();
    }
  }

  void _finish() {
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: Text('Skip', style: TextStyle(color: Colors.grey.shade500)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        BlobIllustration(icon: slide.icon, color: slide.color, size: 200),
                        const SizedBox(height: 36),
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          slide.description,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.4),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (index) {
                final isActive = index == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isActive ? 22 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: isActive ? _slides[_currentPage].color : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                child: BouncyTap(
                  child: ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: kTeal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(_currentPage == _slides.length - 1 ? 'Get Started' : 'Next'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlide {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const _OnboardingSlide({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });
}