import 'package:flutter/material.dart';

import '../../../../core/localization/app_language_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_card.dart';
import '../../../../shared/widgets/mascot_image.dart';
import '../../domain/models/education_pet_state.dart';

class EducationPetCard extends StatefulWidget {
  final EducationPetState petState;
  final bool isLoading;
  final bool isFeeding;
  final VoidCallback onFeed;
  final VoidCallback? onPlay;

  const EducationPetCard({
    super.key,
    required this.petState,
    required this.isLoading,
    required this.isFeeding,
    required this.onFeed,
    this.onPlay,
  });

  @override
  State<EducationPetCard> createState() => _EducationPetCardState();
}

class _EducationPetCardState extends State<EducationPetCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  void _triggerBounce() {
    _bounceController.forward().then((_) {
      _bounceController.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = widget.isLoading || widget.isFeeding;
    final canFeed = !isBusy && widget.petState.hasFood;
    final hungerLevel = 100 - (widget.petState.foodBalance * 10).clamp(0, 100);
    final happinessLevel = (widget.petState.progress * 100).toInt();

    return CustomCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          // Header con nombre
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.petState.name,
                      style: AppTheme.headlineMedium.copyWith(fontSize: 28),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr(
                        'education.companion.pet_level',
                        params: {'level': '${widget.petState.level}'},
                      ),
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.primaryLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.accent.withValues(alpha: 0.8),
                      AppTheme.primary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.petState.moodLabel,
                  style: const TextStyle(
                    color: AppTheme.espressoDeep,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Mascota grande y central
          ScaleTransition(
            scale: _bounceAnimation,
            child: Container(
              width: 140,
              height: 160,
              decoration: BoxDecoration(
                color: AppTheme.primaryLight.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const MascotImage(
                    width: 120,
                    height: 120,
                    padding: EdgeInsets.all(10),
                    semanticsLabel: 'Mascota',
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AppTheme.accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        size: 16,
                        color: AppTheme.espressoDeep,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Needs indicators (necesidades)
          Row(
            children: [
              Expanded(
                child: _NeedIndicator(
                  icon: Icons.restaurant_rounded,
                  label: 'Hambre',
                  value: hungerLevel.toInt(),
                  color: hungerLevel > 70 ? Colors.red : Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _NeedIndicator(
                  icon: Icons.sentiment_satisfied_rounded,
                  label: 'Felicidad',
                  value: happinessLevel,
                  color: happinessLevel > 70 ? Colors.green : Colors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // XP Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('EXP', style: AppTheme.labelLarge),
                  Text(
                    '${widget.petState.currentXp}/${EducationPetState.xpPerLevel}',
                    style: AppTheme.labelLarge.copyWith(fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _XpBar(progress: widget.petState.progress),
            ],
          ),
          const SizedBox(height: 16),
          // Stats
          Row(
            children: [
              Expanded(
                child: _StatPill(
                  icon: Icons.trending_up_rounded,
                  value: '${widget.petState.totalXp}',
                  label: 'Total XP',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatPill(
                  icon: Icons.cake_rounded,
                  value: '${widget.petState.foodBalance}',
                  label: 'Comida',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatPill(
                  icon: Icons.monetization_on_rounded,
                  value: '${widget.petState.coins}',
                  label: 'Monedas',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Action buttons - Estilo Pou
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.restaurant_menu_rounded,
                  label: 'Alimentar',
                  onPressed: !canFeed
                      ? null
                      : () {
                          _triggerBounce();
                          widget.onFeed();
                        },
                  isLoading: widget.isFeeding,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 10),
              if (widget.onPlay != null)
                Expanded(
                  child: _ActionButton(
                    icon: Icons.sports_esports_rounded,
                    label: 'Jugar',
                    onPressed: isBusy ? null : widget.onPlay!,
                    color: Colors.blue,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            widget.petState.hasFood
                ? widget.petState.lastFedLabel
                : context.tr('education.companion.no_food_hint'),
            style: AppTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _NeedIndicator extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;

  const _NeedIndicator({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(label, style: AppTheme.bodyMedium.copyWith(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value / 100,
            minHeight: 8,
            backgroundColor: color.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color color;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.color = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.2),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            )
          else
            Icon(icon, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTheme.bodyMedium.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatPill({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.textSecondary),
          const SizedBox(height: 4),
          Text(value, style: AppTheme.labelLarge.copyWith(fontSize: 13)),
          const SizedBox(height: 2),
          Text(label, style: AppTheme.bodyMedium.copyWith(fontSize: 10)),
        ],
      ),
    );
  }
}

class _XpBar extends StatelessWidget {
  final double progress;

  const _XpBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 12,
        backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryLight),
      ),
    );
  }
}
