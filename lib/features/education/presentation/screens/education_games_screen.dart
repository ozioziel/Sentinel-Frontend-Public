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

  List<_EducationGameQuestion> get _questions {
    final l10n = AppLanguageService.instance;
    final trueOption = l10n.tr('education.games.true_option');
    final falseOption = l10n.tr('education.games.false_option');

    return [
      _EducationGameQuestion(
        category: l10n.pick(es: 'Consentimiento', en: 'Consent'),
        prompt: l10n.pick(
          es: 'El consentimiento debe ser claro y puede retirarse en cualquier momento.',
          en: 'Consent must be clear and can be withdrawn at any time.',
        ),
        options: [trueOption, falseOption],
        correctIndex: 0,
        explanation: l10n.pick(
          es: 'El consentimiento necesita ser libre, claro y continuo. Si cambia la decision, tambien cambia el acuerdo.',
          en: 'Consent must be free, clear and ongoing. If the decision changes, the agreement changes too.',
        ),
      ),
      _EducationGameQuestion(
        category: l10n.pick(es: 'Anticoncepcion', en: 'Contraception'),
        prompt: l10n.pick(
          es: 'Informarte sobre metodos anticonceptivos solo sirve despues de tener relaciones.',
          en: 'Learning about contraceptive methods only helps after having sex.',
        ),
        options: [trueOption, falseOption],
        correctIndex: 1,
        explanation: l10n.pick(
          es: 'Informarse antes ayuda a decidir con calma, conocer opciones y buscar apoyo profesional si hace falta.',
          en: 'Learning beforehand helps you decide calmly, understand options and seek professional support if needed.',
        ),
      ),
      _EducationGameQuestion(
        category: l10n.pick(es: 'Apoyo', en: 'Support'),
        prompt: l10n.pick(
          es: 'Pedir ayuda si sientes presion, miedo o violencia tambien es una forma de autocuidado.',
          en: 'Asking for help if you feel pressure, fear or violence is also a form of self-care.',
        ),
        options: [trueOption, falseOption],
        correctIndex: 0,
        explanation: l10n.pick(
          es: 'Buscar apoyo en una persona segura o en un servicio de salud puede ayudarte a protegerte y tomar decisiones mas informadas.',
          en: 'Seeking support from a safe person or a health service can help you protect yourself and make more informed decisions.',
        ),
      ),
    ];
  }

  int _currentIndex = 0;
  int _correctAnswers = 0;
  int? _selectedAnswerIndex;
  bool _showExplanation = false;
  bool _isComplete = false;
  bool _isApplyingReward = false;
  EducationGameRewardResult? _reward;

  _EducationGameQuestion get _currentQuestion => _questions[_currentIndex];

  String _localizedOption(BuildContext context, String option) {
    return option;
  }

  void _selectAnswer(int index) {
    if (_showExplanation || _isComplete) {
      return;
    }

    setState(() {
      _selectedAnswerIndex = index;
      _showExplanation = true;
      if (index == _currentQuestion.correctIndex) {
        _correctAnswers += 1;
      }
    });
  }

  Future<void> _continueGame() async {
    if (_isComplete || !_showExplanation) {
      return;
    }

    if (_currentIndex == _questions.length - 1) {
      await _applyRewardAndComplete();
      return;
    }

    setState(() {
      _currentIndex += 1;
      _selectedAnswerIndex = null;
      _showExplanation = false;
    });
  }

  void _restartGame() {
    setState(() {
      _currentIndex = 0;
      _correctAnswers = 0;
      _selectedAnswerIndex = null;
      _showExplanation = false;
      _isComplete = false;
      _isApplyingReward = false;
      _reward = null;
    });
  }

  Future<void> _applyRewardAndComplete() async {
    if (_isApplyingReward) {
      return;
    }

    setState(() {
      _isApplyingReward = true;
      _isComplete = true;
    });

    try {
      final reward = await _petService.rewardGame(
        correctAnswers: _correctAnswers,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _reward = reward;
        _isApplyingReward = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isApplyingReward = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('education.games.save_reward_error')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: Text(context.tr('education.games.title'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderCard(),
              const SizedBox(height: 16),
              if (_isComplete) _buildSummaryCard() else _buildQuestionCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return CustomCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeaderChip(
                icon: Icons.psychology_alt_rounded,
                label: context.tr('education.games.chip_informative'),
              ),
              _HeaderChip(
                icon: Icons.favorite_border_rounded,
                label: context.tr('education.games.chip_sex_ed'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            context.tr('education.games.heading'),
            style: AppTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('education.games.description'),
            style: AppTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _HeaderStat(
                  label: context.tr('education.games.stat_questions'),
                  value: '${_questions.length}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HeaderStat(
                  label: context.tr('education.games.stat_hits'),
                  value: '$_correctAnswers',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard() {
    final question = _currentQuestion;

    return CustomCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  question.category,
                  style: const TextStyle(
                    color: AppTheme.primaryLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                context.tr(
                  'education.games.question_progress',
                  params: {
                    'current': '${_currentIndex + 1}',
                    'total': '${_questions.length}',
                  },
                ),
                style: AppTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(question.prompt, style: AppTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            context.tr('education.games.explanation_hint'),
            style: AppTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < question.options.length; index++) ...[
            _AnswerCard(
              label: String.fromCharCode(65 + index),
              text: _localizedOption(context, question.options[index]),
              onTap: () => _selectAnswer(index),
              isSelected: _selectedAnswerIndex == index,
              isCorrect: _showExplanation && question.correctIndex == index,
              isIncorrect:
                  _showExplanation &&
                  _selectedAnswerIndex == index &&
                  question.correctIndex != index,
            ),
            if (index != question.options.length - 1)
              const SizedBox(height: 10),
          ],
          if (_showExplanation) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('education.games.important'),
                    style: AppTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(question.explanation, style: AppTheme.bodyLarge),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _continueGame,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(
                  _currentIndex == _questions.length - 1
                      ? context.tr('education.games.see_summary')
                      : context.tr('education.games.next_question'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final passed = _correctAnswers >= 2;

    return CustomCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: (passed ? AppTheme.success : AppTheme.accent).withValues(
                alpha: 0.16,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              passed ? Icons.verified_rounded : Icons.menu_book_rounded,
              color: passed ? AppTheme.success : AppTheme.accent,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('education.games.summary_title'),
            style: AppTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(
              'education.games.summary_result',
              params: {
                'correct': '$_correctAnswers',
                'total': '${_questions.length}',
              },
            ),
            style: AppTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          if (_isApplyingReward) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.tr('education.games.saving_reward'),
                      style: AppTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_reward != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.22),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('education.games.reward_title'),
                    style: AppTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr(
                      'education.games.reward_food',
                      params: {'value': '${_reward!.foodEarned}'},
                    ),
                    style: AppTheme.bodyLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr(
                      'education.games.reward_coins',
                      params: {'value': '${_reward!.coinsEarned}'},
                    ),
                    style: AppTheme.bodyLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr(
                      'education.games.reward_inventory',
                      params: {
                        'food': '${_reward!.state.foodBalance}',
                        'coins': '${_reward!.state.coins}',
                      },
                    ),
                    style: AppTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('education.games.ideas_title'),
                  style: AppTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr('education.games.idea_1'),
                  style: AppTheme.bodyMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr('education.games.idea_2'),
                  style: AppTheme.bodyMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr('education.games.idea_3'),
                  style: AppTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isApplyingReward ? null : _restartGame,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.tr('education.games.play_again')),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  final String label;
  final String text;
  final bool isSelected;
  final bool isCorrect;
  final bool isIncorrect;
  final VoidCallback onTap;

  const _AnswerCard({
    required this.label,
    required this.text,
    required this.isSelected,
    required this.isCorrect,
    required this.isIncorrect,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    var borderColor = AppTheme.divider;
    var backgroundColor = AppTheme.primary.withValues(alpha: 0.06);
    var labelColor = AppTheme.textPrimary;

    if (isCorrect) {
      borderColor = AppTheme.success;
      backgroundColor = AppTheme.success.withValues(alpha: 0.14);
      labelColor = AppTheme.success;
    } else if (isIncorrect) {
      borderColor = AppTheme.error;
      backgroundColor = AppTheme.error.withValues(alpha: 0.14);
      labelColor = AppTheme.error;
    } else if (isSelected) {
      borderColor = AppTheme.primary;
      backgroundColor = AppTheme.primary.withValues(alpha: 0.12);
      labelColor = AppTheme.primaryLight;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: AppTheme.bodyLarge)),
          ],
        ),
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeaderChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Text(label, style: AppTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String label;
  final String value;

  const _HeaderStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(label, style: AppTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _EducationGameQuestion {
  final String category;
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const _EducationGameQuestion({
    required this.category,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}
