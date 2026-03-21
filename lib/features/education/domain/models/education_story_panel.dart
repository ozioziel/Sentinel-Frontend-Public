import 'package:flutter/material.dart';

class EducationStoryPanel {
  final String eyebrow;
  final String title;
  final String caption;
  final String bubbleText;
  final String footer;
  final IconData icon;
  final Color color;
  final String? imageAssetPath;
  final String? imageSemanticLabel;

  const EducationStoryPanel({
    required this.eyebrow,
    required this.title,
    required this.caption,
    required this.bubbleText,
    required this.footer,
    required this.icon,
    required this.color,
    this.imageAssetPath,
    this.imageSemanticLabel,
  });
}
