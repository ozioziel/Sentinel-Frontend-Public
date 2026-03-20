import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Future<void> _openVideoExample(BuildContext context) async {
    final uri = Uri.parse(topic.videoUrl);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (opened || !context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se pudo abrir el video de ejemplo.')),
    );
  }

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
                  const SizedBox(height: 24),
                  const EducationSectionHeader(
                    title: 'Video de ejemplo',
                    subtitle:
                        'El video principal queda arriba y cambia segun el tema elegido.',
                  ),
                  const SizedBox(height: 12),
                  EducationVideoShowcase(
                    topic: topic,
                    onOpenVideo: () => _openVideoExample(context),
                  ),
                  const SizedBox(height: 24),
                  const EducationSectionHeader(
                    title: 'Comic de ejemplo',
                    subtitle:
                        'El comic se muestra completo en vertical para leerlo bajando.',
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
                  const EducationSectionHeader(
                    title: 'Informacion en texto',
                    subtitle:
                        'Al final dejamos el espacio solo para bloques de lectura.',
                  ),
                  const SizedBox(height: 12),
                  for (final block in topic.textBlocks) ...[
                    EducationTextBlockCard(text: block, color: topic.color),
                    const SizedBox(height: 12),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
