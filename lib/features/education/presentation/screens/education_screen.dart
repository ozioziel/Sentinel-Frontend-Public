import 'package:flutter/material.dart';

import '../../../../core/localization/app_language_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/education_topics_catalog.dart';
import '../../domain/models/education_pet_state.dart';
import '../../domain/models/education_topic.dart';
import '../services/education_pet_service.dart';
import '../widgets/education_empty_state.dart';
import '../widgets/education_pet_hub_entry_card.dart';
import '../widgets/education_topic_card.dart';
import 'education_companion_screen.dart';
import 'education_topic_detail_screen.dart';

class EducationScreen extends StatefulWidget {
  final bool isEmbedded;

  const EducationScreen({super.key, this.isEmbedded = false});

  @override
  State<EducationScreen> createState() => _EducationScreenState();
}

class _EducationScreenState extends State<EducationScreen> {
  final EducationPetService _petService = EducationPetService();
  String _query = '';
  EducationPetState _petState = EducationPetState.initial();
  bool _isLoadingPet = true;

  @override
  void initState() {
    super.initState();
    _loadPetState();
  }

  List<EducationTopic> get _visibleTopics {
    return EducationTopicsCatalog.topics
        .where((topic) => topic.matchesQuery(_query))
        .toList();
  }

  Future<void> _loadPetState() async {
    try {
      final petState = await _petService.loadPetState();

      if (!mounted) {
        return;
      }

      setState(() {
        _petState = petState;
        _isLoadingPet = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() => _isLoadingPet = false);
    }
  }

  void _openTopic(EducationTopic topic) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EducationTopicDetailScreen(topic: topic),
      ),
    );
  }

  Future<void> _openCompanion() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const EducationCompanionScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadPetState();
  }

  @override
  Widget build(BuildContext context) {
    final visibleTopics = _visibleTopics;
    final isFiltering = _query.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: widget.isEmbedded
          ? AppBar(title: Text(context.tr('education.title_embedded')))
          : null,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!widget.isEmbedded) ...[
                      Text(
                        context.tr('education.title'),
                        style: AppTheme.headlineLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.tr('education.subtitle'),
                        style: AppTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                    ],
                    EducationPetHubEntryCard(
                      petState: _petState,
                      isLoading: _isLoadingPet,
                      onTap: _openCompanion,
                    ),
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.divider),
                      ),
                      child: TextField(
                        style: AppTheme.bodyLarge,
                        onChanged: (value) {
                          setState(() => _query = value);
                        },
                        decoration: InputDecoration(
                          hintText: context.tr('education.search_hint'),
                          hintStyle: AppTheme.bodyMedium,
                          prefixIcon: const Icon(
                            Icons.search,
                            color: AppTheme.textSecondary,
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      isFiltering
                          ? context.tr('education.results_title')
                          : context.tr('education.topics_title'),
                      style: AppTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isFiltering
                          ? context.tr('education.results_subtitle')
                          : context.tr('education.topics_subtitle'),
                      style: AppTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              sliver: visibleTopics.isEmpty
                  ? const SliverToBoxAdapter(child: EducationEmptyState())
                  : SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final topic = visibleTopics[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: EducationTopicCard(
                            topic: topic,
                            onTap: () => _openTopic(topic),
                          ),
                        );
                      }, childCount: visibleTopics.length),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
