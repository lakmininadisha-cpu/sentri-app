import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

// A small shared design system so every screen in Sentri looks and
// behaves consistently, instead of each screen re-inventing its own
// header, card, loading, and error styling. Import this file wherever
// a screen needs one of these building blocks.

const kTeal = Color(0xFF0F6E56);
const kTealDark = Color(0xFF17936F);
const kBackground = Color(0xFFF6F8F7);

// Shared accent palette, reused across every screen. Defined once here
// so screens that import multiple other screens (e.g. Home importing
// both FamilyScreen and ItemDetailScreen) never hit a duplicate top-level
// constant name collision.
const kCoral = Color(0xFFE24B4A);
const kBlue = Color(0xFF378ADD);
const kAmber = Color(0xFFC9861A);
const kPurple = Color(0xFF7F77DD);
const kGreen = Color(0xFF5C8F2E);
const kPink = Color(0xFFB3559B);
const kNavy = Color(0xFF1E2761);

/// A colourful, curved gradient header used at the top of every screen,
/// replacing the plain default AppBar. Supports an optional back button,
/// a leading icon badge, and any number of trailing action icons.
class GradientHeader extends StatefulWidget {
  final String title;
  final String? subtitle;
  final bool showBackButton;
  final List<Widget> actions;
  final double height;

  const GradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showBackButton = true,
    this.actions = const [],
    this.height = 130,
  });

  @override
  State<GradientHeader> createState() => _GradientHeaderState();
}

class _GradientHeaderState extends State<GradientHeader> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // A gentle cycle through a few colours from the app's own palette,
  // so headers feel alive rather than static, without ever clashing
  // with the rest of the screen (still teal-dominant most of the time).
  static const _cycleColors = [kTeal, kTealDark, kBlue, kTeal];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _colorAt(double t) {
    final segment = 1 / (_cycleColors.length - 1);
    final index = (t / segment).floor().clamp(0, _cycleColors.length - 2);
    final localT = ((t - index * segment) / segment).clamp(0.0, 1.0);
    return Color.lerp(_cycleColors[index], _cycleColors[index + 1], localT)!;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final topColor = _colorAt(_controller.value);
        final bottomColor = _colorAt((_controller.value + 0.4) % 1.0);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: widget.height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [topColor, bottomColor],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
            ),
            Positioned(
              top: -30, right: -20,
              child: Container(
                width: 110, height: 110,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            Positioned(
              top: 30, right: 70,
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.10)),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: Row(
                  children: [
                    if (widget.showBackButton)
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                        onPressed: () => Navigator.of(context).maybePop(),
                      )
                    else
                      const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700),
                          ),
                          if (widget.subtitle != null)
                            Text(
                              widget.subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11.5),
                            ),
                        ],
                      ),
                    ),
                    ...widget.actions,
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A compact icon button meant to sit inside a GradientHeader's actions.
class HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const HeaderIconButton({super.key, required this.icon, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: Colors.white, size: 18),
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
    );
  }
}

/// Standard white, rounded, soft-shadowed card used for content blocks
/// throughout the app (form sections, list rows, summary tiles).
class SentriCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  const SentriCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: child,
    );
  }
}

/// A gentle, organically-shaped illustration (drawn with math, no image
/// assets needed) used behind an icon for empty states across the app —
/// "no items", "no family members", "no routines", etc.
class BlobIllustration extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const BlobIllustration({super.key, required this.icon, this.color = kTeal, this.size = 160});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BlobPainter(color: color.withValues(alpha: 0.12)),
        child: Center(child: Icon(icon, size: size * 0.36, color: color)),
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  final Color color;
  _BlobPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
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
  bool shouldRepaint(covariant _BlobPainter oldDelegate) => oldDelegate.color != color;
}

/// A friendly, reusable empty-state block: illustration + title + message.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color color;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.color = kTeal,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BlobIllustration(icon: icon, color: color),
            const SizedBox(height: 24),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF20241F))),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 13.5)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              BouncyTap(
                child: ElevatedButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(actionLabel!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A consistent loading state, used instead of a bare CircularProgressIndicator
/// so every screen "loads" the same way.
class LoadingView extends StatelessWidget {
  final String? label;
  const LoadingView({super.key, this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: kTeal),
          if (label != null) ...[
            const SizedBox(height: 12),
            Text(label!, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

/// A consistent error state with a retry action, used anywhere a Firestore
/// stream or async call might fail, instead of a bare Text widget.
class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorView({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}

/// A soft pair of background blobs meant to sit behind a screen's content
/// (inside a Stack, before the real content), giving continuity with the
/// GradientHeader's colour instead of an abrupt white cutoff.
class BackgroundAccents extends StatelessWidget {
  const BackgroundAccents({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 160, right: -60,
          child: Container(width: 150, height: 150, decoration: BoxDecoration(shape: BoxShape.circle, color: kTeal.withValues(alpha: 0.04))),
        ),
        Positioned(
          top: 400, left: -50,
          child: Container(width: 130, height: 130, decoration: BoxDecoration(shape: BoxShape.circle, color: kTeal.withValues(alpha: 0.035))),
        ),
      ],
    );
  }
}

/// Wraps a list item so it gently fades and slides up into place a
/// short moment after the screen builds, staggered by [index] so items
/// cascade in one after another rather than all popping in at once.
/// Used for item lists, family members, and routines.
class StaggeredListItem extends StatefulWidget {
  final int index;
  final Widget child;

  const StaggeredListItem({super.key, required this.index, required this.child});

  @override
  State<StaggeredListItem> createState() => _StaggeredListItemState();
}

class _StaggeredListItemState extends State<StaggeredListItem> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(_fade);

    // Cap the stagger delay so a long list doesn't feel sluggish to load.
    final delayMs = (widget.index * 45).clamp(0, 400);
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// A single shimmering placeholder row, shaped like a typical Sentri
/// list card (a circular avatar + two lines of text), used to build
/// skeleton loading screens.
class SkeletonRow extends StatelessWidget {
  const SkeletonRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(width: 48, height: 48, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE5E9E7))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 14, width: 130, decoration: BoxDecoration(color: const Color(0xFFE5E9E7), borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 8),
                Container(height: 11, width: 90, decoration: BoxDecoration(color: const Color(0xFFEDF0EF), borderRadius: BorderRadius.circular(4))),
              ],
            ),
          ),
          Container(width: 56, height: 22, decoration: BoxDecoration(color: const Color(0xFFE5E9E7), borderRadius: BorderRadius.circular(20))),
        ],
      ),
    );
  }
}

/// A skeleton loading screen for lists — shows a handful of shimmering
/// placeholder rows instead of a bare spinner, so the layout the user
/// is about to see is already hinted at while data loads. Used on
/// Home, Family, and Routines.
class SkeletonListView extends StatelessWidget {
  final int rowCount;
  const SkeletonListView({super.key, this.rowCount = 5});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFEFF2F1),
      highlightColor: Colors.white,
      period: const Duration(milliseconds: 1400),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: rowCount,
        itemBuilder: (context, index) => const SkeletonRow(),
      ),
    );
  }
}

/// Animates a number counting up from 0 to [value] over a short
/// duration, used for stat displays (Weekly Summary, Health) so they
/// feel alive rather than just appearing.
class CountUpNumber extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final String prefix;
  final String suffix;

  const CountUpNumber({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return Text('$prefix$animatedValue$suffix', style: style);
      },
    );
  }
}

/// Wraps any widget (typically a button) so it visually scales down
/// slightly while pressed and springs back on release. Uses raw pointer
/// events (Listener) rather than its own tap recognizer, so it never
/// competes with — or interferes with — the wrapped widget's own
/// onPressed/onTap handling. Safe to drop around any existing button.
class BouncyTap extends StatefulWidget {
  final Widget child;

  const BouncyTap({super.key, required this.child});

  @override
  State<BouncyTap> createState() => _BouncyTapState();
}

class _BouncyTapState extends State<BouncyTap> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.94).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _controller.forward(),
      onPointerUp: (_) => _controller.reverse(),
      onPointerCancel: (_) => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(scale: _scale.value, child: child),
        child: widget.child,
      ),
    );
  }
}

/// A circular, animated progress ring — used in place of a linear bar
/// for goal-style metrics (steps, water, priority share) where a ring
/// reads more like "progress toward a target" at a glance.
class AnimatedProgressRing extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final Color color;
  final double size;
  final double strokeWidth;
  final Widget? center;

  const AnimatedProgressRing({
    super.key,
    required this.progress,
    required this.color,
    this.size = 64,
    this.strokeWidth = 7,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: 1,
                  strokeWidth: strokeWidth,
                  color: color.withValues(alpha: 0.15),
                ),
              ),
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: animatedValue,
                  strokeWidth: strokeWidth,
                  color: color,
                  strokeCap: StrokeCap.round,
                ),
              ),
              ?center,
            ],
          ),
        );
      },
    );
  }
}

/// Briefly shows an animated success checkmark (scale + fade in, short
/// pause, fade out) as a small overlay dialog — used after actions like
/// saving an item, so the app confirms success with more than just a
/// silent screen change.
Future<void> showSuccessAnimation(BuildContext context, {String message = 'Saved!'}) async {
  final future = showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black26,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
    transitionBuilder: (context, anim1, anim2, child) {
      final scale = CurvedAnimation(parent: anim1, curve: Curves.elasticOut);
      return Opacity(
        opacity: anim1.value.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: 0.7 + (0.3 * scale.value.clamp(0.0, 1.5)),
          child: Center(
            child: Container(
              width: 140,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 8)),
              ]),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(color: kTeal, shape: BoxShape.circle),
                    child: const Icon(Icons.check, color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 12),
                  Text(message, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  // Give the entrance animation a moment to be seen, then dismiss
  // automatically — the caller doesn't need to close this themselves.
  Future.delayed(const Duration(milliseconds: 750), () {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  });

  await future;
}

/// Shows a friendly, branded explanation of *why* Sentri needs a
/// permission, before Android's own system permission dialog appears.
/// Returns true if the user chose to continue, false if they backed out
/// — the caller decides what to do with that (typically: only trigger
/// the real OS permission request if this returns true).
Future<bool> showPermissionPrimer(
  BuildContext context, {
  required IconData icon,
  required Color color,
  required String title,
  required String message,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isDismissible: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(height: 18),
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 13.5, height: 1.4)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: BouncyTap(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Continue'),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Not now', style: TextStyle(color: Colors.grey.shade500)),
              ),
            ],
          ),
        ),
      );
    },
  );

  return result ?? false;
}