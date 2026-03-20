import 'package:flutter/material.dart';

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

  static const List<_EducationGameQuestion> _questions = [
    _EducationGameQuestion(
      category: 'Consentimiento',
      prompt:
          'El consentimiento debe ser claro y puede retirarse en cualquier momento.',
      options: ['Verdadero', 'Falso'],
      correctIndex: 0,
      explanation:
          'El consentimiento necesita ser libre, claro y continuo. Si cambia la decision, tambien cambia el acuerdo.',
    ),
    _EducationGameQuestion(
      category: 'Anticoncepcion',
      prompt:
          'Informarte sobre metodos anticonceptivos solo sirve despues de tener relaciones.',
      options: ['Verdadero', 'Falso'],
      correctIndex: 1,
      explanation:
          'Informarse antes ayuda a decidir con calma, conocer opciones y buscar apoyo profesional si hace falta.',
    ),
    _EducationGameQuestion(
      category: 'Apoyo',
      prompt:
          'Pedir ayuda si sientes presion, miedo o violencia tambien es una forma de autocuidado.',
      options: ['Verdadero', 'Falso'],
      correctIndex: 0,
      explanation:
          'Buscar apoyo en una persona segura o en un servicio de salud puede ayudarte a protegerte y tomar decisiones mas informadas.',
    ),
  ];

  int _currentIndex = 0;
  int _correctAnswers = 0;
  int? _selectedAnswerIndex;
  bool _showExplanation = false;
  bool _isComplete = false;
  bool _isApplyingReward = false;
  EducationGameRewardResult? _reward;

  _EducationGameQuestion get _currentQuestion => _questions[_currentIndex];

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
        const SnackBar(
          content: Text('No se pudo guardar la recompensa del juego.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: const Text('Juegos de educacion')),
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
            children: const [
              _HeaderChip(
                icon: Icons.psychology_alt_rounded,
                label: 'Juego informativo',
              ),
              _HeaderChip(
                icon: Icons.favorite_border_rounded,
                label: 'Educacion sexual',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text('Mito o realidad', style: AppTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Responde preguntas cortas, aprende algo util y gana comida o monedas para seguir cuidando a la mascota.',
            style: AppTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _HeaderStat(
                  label: 'Preguntas',
                  value: '${_questions.length}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HeaderStat(
                  label: 'Aciertos',
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
                'Pregunta ${_currentIndex + 1} de ${_questions.length}',
                style: AppTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(question.prompt, style: AppTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Toca una opcion para ver la explicacion.',
            style: AppTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < question.options.length; index++) ...[
            _AnswerCard(
              label: String.fromCharCode(65 + index),
              text: question.options[index],
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
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Lo importante', style: AppTheme.labelLarge),
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
                      ? 'Ver resumen'
                      : 'Siguiente pregunta',
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
          Text('Resumen del juego', style: AppTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Respondiste $_correctAnswers de ${_questions.length} preguntas correctamente.',
            style: AppTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          if (_isApplyingReward) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
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
                      'Guardando recompensa del juego...',
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
                  Text('Recompensa ganada', style: AppTheme.labelLarge),
                  const SizedBox(height: 8),
                  Text(
                    '+${_reward!.foodEarned} comida para la mascota',
                    style: AppTheme.bodyLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '+${_reward!.coinsEarned} monedas guardadas',
                    style: AppTheme.bodyLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Inventario actual: ${_reward!.state.foodBalance} comida y ${_reward!.state.coins} monedas.',
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
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.divider),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ideas clave', style: AppTheme.labelLarge),
                SizedBox(height: 8),
                Text(
                  'El consentimiento se comunica y puede cambiarse.',
                  style: AppTheme.bodyMedium,
                ),
                SizedBox(height: 6),
                Text(
                  'La informacion confiable ayuda a decidir antes de actuar.',
                  style: AppTheme.bodyMedium,
                ),
                SizedBox(height: 6),
                Text(
                  'Pedir apoyo es parte del autocuidado.',
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
              label: const Text('Jugar otra vez'),
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
    var backgroundColor = Colors.white.withValues(alpha: 0.03);
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
                color: Colors.white.withValues(alpha: 0.06),
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
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.divider),
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
        color: Colors.white.withValues(alpha: 0.03),
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
