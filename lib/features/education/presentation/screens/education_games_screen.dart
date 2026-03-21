import 'package:flutter/material.dart';

import '../../../../core/localization/app_language_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_card.dart';
import '../services/education_pet_service.dart';

class EducationGamesScreen extends StatefulWidget {
  const EducationGamesScreen({super.key});

  @override
  State<EducationGamesScreen> createState() => _EducationGamesScreenState();
}

class _EducationGamesScreenState extends State<EducationGamesScreen> {
  final EducationPetService _petService = EducationPetService();

  final List<_QuestionItem> _questions = const [
    _QuestionItem(
      question:
          '¿Qué debes hacer si alguien te hace sentir incómoda o incómodo con contacto no deseado?',
      options: [
        'Quedarte callada o callado',
        'Alejarte o hablar con una persona de confianza',
        'Aceptar para evitar problemas',
      ],
      correctIndex: 1,
    ),
    _QuestionItem(
      question: '¿La violencia sexual puede ocurrir sin consentimiento?',
      options: ['Sí', 'No', 'Solo a veces'],
      correctIndex: 0,
    ),
    _QuestionItem(
      question:
          '¿Hablar con una persona de confianza puede ayudarte ante una situación de riesgo?',
      options: ['Sí', 'No', 'No sirve'],
      correctIndex: 0,
    ),
  ];

  int _currentQuestionIndex = 0;
  int? _selectedOptionIndex;
  int _correctAnswers = 0;
  bool _isSubmitting = false;
  bool _isApplyingReward = false;
  bool _quizFinished = false;
  EducationGameRewardResult? _reward;

  _QuestionItem get _currentQuestion => _questions[_currentQuestionIndex];

  Future<void> _submitAnswer() async {
    if (_selectedOptionIndex == null || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final isCorrect = _selectedOptionIndex == _currentQuestion.correctIndex;

    if (isCorrect) {
      _correctAnswers++;
    }

    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    final isLastQuestion = _currentQuestionIndex == _questions.length - 1;

    if (isLastQuestion) {
      await _applyRewardAndComplete();
    } else {
      setState(() {
        _currentQuestionIndex++;
        _selectedOptionIndex = null;
        _isSubmitting = false;
      });
    }
  }

  Future<void> _applyRewardAndComplete() async {
    if (_isApplyingReward) {
      return;
    }

    setState(() {
      _isApplyingReward = true;
    });

    try {
      final reward = await _petService.rewardGame(
        correctAnswers: _correctAnswers,
      );

      if (!mounted) return;

      setState(() {
        _reward = reward;
        _quizFinished = true;
        _isSubmitting = false;
        _isApplyingReward = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
        _isApplyingReward = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('education.games.save_reward_error')),
        ),
      );
    }
  }

  void _resetQuiz() {
    setState(() {
      _currentQuestionIndex = 0;
      _selectedOptionIndex = null;
      _correctAnswers = 0;
      _isSubmitting = false;
      _isApplyingReward = false;
      _quizFinished = false;
      _reward = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(context.tr('education.games.title')),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: _quizFinished ? _buildResultView() : _buildQuizView(),
        ),
      ),
    );
  }

  Widget _buildQuizView() {
    final progress = (_currentQuestionIndex + 1) / _questions.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '🧠 Juego de preguntas',
                  style: TextStyle(
                    color: AppTheme.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text('Responde correctamente', style: AppTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Contesta las preguntas y gana recompensas para tu mascota.',
                style: AppTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(value: progress, minHeight: 8),
              ),
              const SizedBox(height: 8),
              Text(
                'Pregunta ${_currentQuestionIndex + 1} de ${_questions.length}',
                style: AppTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        CustomCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_currentQuestion.question, style: AppTheme.titleLarge),
              const SizedBox(height: 16),
              ...List.generate(_currentQuestion.options.length, (index) {
                final isSelected = _selectedOptionIndex == index;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _isSubmitting
                        ? null
                        : () {
                            setState(() {
                              _selectedOptionIndex = index;
                            });
                          },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primary.withValues(alpha: 0.12)
                            : AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.divider,
                        ),
                      ),
                      child: Text(
                        _currentQuestion.options[index],
                        style: AppTheme.bodyLarge,
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_selectedOptionIndex == null || _isSubmitting)
                      ? null
                      : _submitAnswer,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(
                    _currentQuestionIndex == _questions.length - 1
                        ? 'Finalizar'
                        : 'Siguiente',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultView() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppTheme.success.withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.verified_rounded,
            color: AppTheme.success,
            size: 48,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '¡Juego completado!',
          style: AppTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Respondiste $_correctAnswers de ${_questions.length} correctamente.',
          style: AppTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        if (_reward != null) ...[
          CustomCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Recompensa', style: AppTheme.labelLarge),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _RewardItem(
                        icon: '🍕',
                        label: 'Comida',
                        value: '${_reward!.foodEarned}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _RewardItem(
                        icon: '💰',
                        label: 'Monedas',
                        value: '${_reward!.coinsEarned}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total de tu mascota', style: AppTheme.bodyMedium),
                      Text(
                        '🍕 ${_reward!.state.foodBalance} | 💰 ${_reward!.state.coins}',
                        style: AppTheme.labelLarge,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _resetQuiz,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(context.tr('education.games.play_again')),
          ),
        ),
      ],
    );
  }
}

class _RewardItem extends StatelessWidget {
  final String icon;
  final String label;
  final String value;

  const _RewardItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 6),
          Text(label, style: AppTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(
            '+$value',
            style: AppTheme.labelLarge.copyWith(color: AppTheme.success),
          ),
        ],
      ),
    );
  }
}

class _QuestionItem {
  final String question;
  final List<String> options;
  final int correctIndex;

  const _QuestionItem({
    required this.question,
    required this.options,
    required this.correctIndex,
  });
}
