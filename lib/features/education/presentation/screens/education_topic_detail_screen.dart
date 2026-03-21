import 'package:flutter/material.dart';

import '../../../../core/localization/app_language_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/education_topic.dart';
import '../widgets/education_section_header.dart';
import '../widgets/education_story_panel_card.dart';
import '../widgets/education_text_block_card.dart';
import '../widgets/education_topic_banner.dart';
import '../widgets/education_video_showcase.dart';

class EducationTopicDetailScreen extends StatelessWidget {
  final EducationTopic topic;

  const EducationTopicDetailScreen({super.key, required this.topic});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: Text(topic.title)),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  EducationTopicBanner(topic: topic),
                  if (topic.hasVideo) ...[
                    const SizedBox(height: 24),
                    EducationSectionHeader(
                      title: context.tr('education.detail.video_title'),
                      subtitle: context.tr('education.detail.video_subtitle'),
                    ),
                    const SizedBox(height: 12),
                    EducationVideoShowcase(topic: topic),
                  ],
                  const SizedBox(height: 24),
                  EducationSectionHeader(
                    title: context.tr('education.detail.comic_title'),
                    subtitle: context.tr('education.detail.comic_subtitle'),
                  ),
                  const SizedBox(height: 12),
                  for (
                    var index = 0;
                    index < topic.storyPanels.length;
                    index++
                  ) ...[
                    EducationStoryPanelCard(
                      panel: topic.storyPanels[index],
                      index: index,
                    ),
                    if (index != topic.storyPanels.length - 1)
                      const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 24),
                  EducationSectionHeader(
                    title: context.tr('education.detail.text_title'),
                    subtitle: context.tr('education.detail.text_subtitle'),
                  ),
                  const SizedBox(height: 12),
                  EducationTextBlockCard(
                    textBlocks: topic.textBlocks,
                    color: topic.color,
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
