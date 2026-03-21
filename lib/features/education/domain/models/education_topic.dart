import 'package:flutter/material.dart';

import 'education_story_panel.dart';

class EducationTopic {
  final String id;
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final String tag;
  final List<EducationStoryPanel> storyPanels;
  final List<String> textBlocks;
  final String? videoAssetPath;

  const EducationTopic({
    required this.id,
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.tag,
    required this.storyPanels,
    required this.textBlocks,
    this.videoAssetPath,
  });

  String get videoTitle => title;

  String get videoDescription => description;

  bool get hasVideo =>
      videoAssetPath != null && videoAssetPath!.trim().isNotEmpty;

  bool matchesQuery(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return true;
    }

    final searchableText = [
      title,
      description,
      tag,
      ...textBlocks,
    ].join(' ').toLowerCase();

    return searchableText.contains(normalizedQuery);
  }
}
