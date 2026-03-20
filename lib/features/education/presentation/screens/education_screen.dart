import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/education_topics_catalog.dart';
import '../../domain/models/education_pet_state.dart';
import '../../domain/models/education_topic.dart';
import '../services/education_pet_service.dart';
import '../widgets/education_empty_state.dart';
import '../widgets/education_games_cta_card.dart';
import '../widgets/education_library_intro_card.dart';
import '../widgets/education_learning_spotlight_card.dart';
import '../widgets/education_pet_card.dart';
import '../widgets/education_topic_card.dart';
import 'education_games_screen.dart';
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
  bool _isFeedingPet = false;

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

  Future<void> _feedPet() async {
    if (_isFeedingPet || _isLoadingPet) {
      return;
    }

    setState(() => _isFeedingPet = true);

    try {
      final result = await _petService.feedPet();

      if (!mounted) {
        return;
      }

      setState(() {
        _petState = result.state;
        _isFeedingPet = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() => _isFeedingPet = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo actualizar la mascota localmente.'),
        ),
      );
    }
  }

  void _openTopic(EducationTopic topic) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EducationTopicDetailScreen(topic: topic),
      ),
    );
  }

  Future<void> _openGames() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const EducationGamesScreen()),
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
          ? AppBar(title: const Text('Educacion DSDR'))
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
                      Text('Educacion', style: AppTheme.headlineLarge),
                      const SizedBox(height: 6),
                      Text(
                        'Derechos Sexuales y Reproductivos',
                        style: AppTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                    ],
                    EducationLibraryIntroCard(
                      totalTopics: EducationTopicsCatalog.topics.length,
                      visibleTopics: visibleTopics.length,
                      isFiltering: isFiltering,
                    ),
                    const SizedBox(height: 20),
                    const EducationLearningSpotlightCard(),
                    const SizedBox(height: 16),
                    EducationPetCard(
                      petState: _petState,
                      isLoading: _isLoadingPet,
                      isFeeding: _isFeedingPet,
                      onFeed: _feedPet,
                    ),
                    const SizedBox(height: 12),
                    EducationGamesCtaCard(onTap: _openGames),
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
                          hintText: 'Buscar tema...',
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
                      isFiltering ? 'Resultados' : 'Temas disponibles',
                      style: AppTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isFiltering
                          ? 'Selecciona el tema que quieras abrir.'
                          : 'Cada tarjeta abre otra pantalla con video, comic vertical y texto.',
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
