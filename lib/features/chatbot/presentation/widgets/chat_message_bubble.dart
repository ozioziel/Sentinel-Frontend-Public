import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/localization/app_language_service.dart';
import '../../../../core/theme/app_theme.dart';

const String _imgOpen =
    'assets/images/garabato_chatbot/explicando_abierto.png';
const String _imgClosed =
    'assets/images/garabato_chatbot/explicando_cerrado.png';

// ─── Public widget ────────────────────────────────────────────────────────────

class ChatMessageBubble extends StatefulWidget {
  final String text;
  final bool isUser;
  final bool isTyping;

  /// Triggers typewriter effect + mouth animation on first build (newest bot msg).
  final bool animated;

  const ChatMessageBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.isTyping = false,
    this.animated = false,
  });

  @override
  State<ChatMessageBubble> createState() => _ChatMessageBubbleState();
}

class _ChatMessageBubbleState extends State<ChatMessageBubble> {
  String _displayed = '';
  bool _isTypewriting = false;
  Timer? _typeTimer;

  @override
  void initState() {
    super.initState();
    if (!widget.isUser && widget.animated && !widget.isTyping && widget.text.isNotEmpty) {
      _startTypewriter();
    } else {
      _displayed = widget.text;
    }
  }

  void _startTypewriter() {
    _isTypewriting = true;
    _displayed = '';
    int charIndex = 0;
    // Scale speed so total animation stays ≈ 3 s max, min 8 ms/char
    final ms = (3000 / widget.text.length).clamp(8.0, 24.0).toInt();
    _typeTimer = Timer.periodic(Duration(milliseconds: ms), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (charIndex >= widget.text.length) {
        timer.cancel();
        setState(() => _isTypewriting = false);
        return;
      }
      charIndex++;
      setState(() => _displayed = widget.text.substring(0, charIndex));
    });
  }

  @override
  void didUpdateWidget(ChatMessageBubble old) {
    super.didUpdateWidget(old);
    // Typing indicator → real message in same list slot
    if (old.isTyping && !widget.isTyping && widget.text.isNotEmpty) {
      _typeTimer?.cancel();
      if (widget.animated) {
        _startTypewriter();
      } else {
        setState(() => _displayed = widget.text);
      }
    } else if (!_isTypewriting && widget.text != old.text && !widget.isTyping) {
      setState(() => _displayed = widget.text);
    }
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isUser) return _UserBubble(text: widget.text);

    final isTalking = widget.isTyping || _isTypewriting;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _MascotTalking(isAnimating: isTalking),
          const SizedBox(width: 10),
          Expanded(
            child: _BotBubble(
              label: widget.isTyping
                  ? AppLanguageService.instance
                      .pick(es: 'Escribiendo...', en: 'Typing...')
                  : AppLanguageService.instance
                      .pick(es: 'Asistente', en: 'Assistant'),
              text: _displayed,
              isTyping: widget.isTyping,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── User bubble ──────────────────────────────────────────────────────────────

class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 56, bottom: 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(4),
            ),
            border: Border.all(color: AppTheme.primaryLight.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLanguageService.instance.pick(es: 'Tú', en: 'You'),
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.surface.withValues(alpha: 0.72),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                text,
                style: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.surface,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Bot bubble ───────────────────────────────────────────────────────────────

class _BotBubble extends StatelessWidget {
  final String label;
  final String text;
  final bool isTyping;

  const _BotBubble({
    required this.label,
    required this.text,
    required this.isTyping,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 6),
          if (isTyping)
            _TypingDots()
          else
            Text(
              text,
              style: AppTheme.bodyLarge.copyWith(
                color: AppTheme.textPrimary,
                fontSize: 14,
                height: 1.48,
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Typing dots ──────────────────────────────────────────────────────────────

class _TypingDots extends StatefulWidget {
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Each dot peaks at a different phase
            final phase = ((_ctrl.value * 3) - i).clamp(0.0, 1.0);
            final bounce = (phase < 0.5 ? phase : 1 - phase) * 2;
            return Padding(
              padding: EdgeInsets.only(right: i == 2 ? 0 : 5),
              child: Transform.translate(
                offset: Offset(0, -5 * bounce),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary
                        .withValues(alpha: 0.5 + 0.5 * bounce),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ─── Animated mascot ─────────────────────────────────────────────────────────

class _MascotTalking extends StatefulWidget {
  final bool isAnimating;
  const _MascotTalking({required this.isAnimating});

  @override
  State<_MascotTalking> createState() => _MascotTalkingState();
}

class _MascotTalkingState extends State<_MascotTalking> {
  bool _mouthOpen = false;
  Timer? _mouthTimer;

  @override
  void initState() {
    super.initState();
    if (widget.isAnimating) _startMouth();
  }

  @override
  void didUpdateWidget(_MascotTalking old) {
    super.didUpdateWidget(old);
    if (widget.isAnimating && !old.isAnimating) {
      _startMouth();
    } else if (!widget.isAnimating && old.isAnimating) {
      _stopMouth();
    }
  }

  void _startMouth() {
    _mouthTimer?.cancel();
    _mouthTimer = Timer.periodic(const Duration(milliseconds: 260), (_) {
      if (!mounted) return;
      setState(() => _mouthOpen = !_mouthOpen);
    });
  }

  void _stopMouth() {
    _mouthTimer?.cancel();
    setState(() => _mouthOpen = false);
  }

  @override
  void dispose() {
    _mouthTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 120),
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
      child: Image.asset(
        _mouthOpen ? _imgOpen : _imgClosed,
        key: ValueKey(_mouthOpen),
        width: 72,
        height: 72,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
