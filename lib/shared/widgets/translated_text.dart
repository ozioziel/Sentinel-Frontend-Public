import 'package:flutter/material.dart';

import '../../core/localization/app_language_service.dart';
import '../../core/services/backend_translation_service.dart';

/// Displays backend-returned text, auto-translating it to the current app
/// language. Shows the original text immediately, then replaces with the
/// translation once the async call completes. Automatically re-translates
/// when the user changes the app language.
class TranslatedText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  const TranslatedText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  @override
  State<TranslatedText> createState() => _TranslatedTextState();
}

class _TranslatedTextState extends State<TranslatedText> {
  String _display = '';
  String? _pendingText;

  @override
  void initState() {
    super.initState();
    _display = widget.text;
    AppLanguageService.instance.addListener(_onLanguageChanged);
    _kick(widget.text);
  }

  @override
  void didUpdateWidget(TranslatedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _display = widget.text;
      _kick(widget.text);
    }
  }

  @override
  void dispose() {
    AppLanguageService.instance.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onLanguageChanged() {
    if (!mounted) return;
    setState(() => _display = widget.text);
    _kick(widget.text);
  }

  void _kick(String text) {
    _pendingText = text;
    BackendTranslationService.instance.translate(text).then((result) {
      if (!mounted || _pendingText != text) return;
      if (result != _display) setState(() => _display = result);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _display,
      style: widget.style,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      textAlign: widget.textAlign,
    );
  }
}
