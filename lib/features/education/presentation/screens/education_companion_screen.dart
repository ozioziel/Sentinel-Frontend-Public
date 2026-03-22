import 'package:flutter/material.dart';

import '../../../../core/localization/app_language_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/education_pet_state.dart';
import '../services/education_pet_service.dart';
import '../widgets/education_pet_card.dart';
import 'education_games_screen.dart';

class EducationCompanionScreen extends StatefulWidget {
  const EducationCompanionScreen({super.key});

  @override
  State<EducationCompanionScreen> createState() =>
      _EducationCompanionScreenState();
}

class _EducationCompanionScreenState extends State<EducationCompanionScreen> {
  final EducationPetService _petService = EducationPetService();

  EducationPetState _petState = EducationPetState.initial();
  bool _isLoadingPet = true;
  bool _isFeedingPet = false;

  @override
  void initState() {
    super.initState();
    _loadPetState();
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
        SnackBar(
          content: Text(
            AppLanguageService.instance.pick(
              es: 'No se pudo actualizar la mascota localmente.',
              en: 'The local pet could not be updated.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _playWithPet() async {
    if (_isLoadingPet) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const EducationGamesScreen()),
    );

    if (!mounted) return;

    await _loadPetState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(context.tr('education.companion.title')),
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            EducationPetCard(
              petState: _petState,
              isLoading: _isLoadingPet,
              isFeeding: _isFeedingPet,
              onFeed: _feedPet,
              onPlay: _playWithPet,
            ),
          ],
        ),
      ),
    );
  }
}
