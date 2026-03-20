import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_card.dart';

class EducationScreen extends StatefulWidget {
  final bool isEmbedded;

  const EducationScreen({super.key, this.isEmbedded = false});

  @override
  State<EducationScreen> createState() => _EducationScreenState();
}

class _EducationScreenState extends State<EducationScreen> {
  final List<_Topic> _topics = const [
    _Topic(
      icon: Icons.favorite_rounded,
      color: Color(0xFFD63864),
      title: 'Derechos Sexuales',
      description:
          'Conoce tus derechos sexuales fundamentales y cómo ejercerlos libremente.',
      tag: 'Básico',
    ),
    _Topic(
      icon: Icons.child_care_rounded,
      color: Color(0xFF9C27B0),
      title: 'Derechos Reproductivos',
      description:
          'Información sobre planificación familiar, anticoncepción y salud reproductiva.',
      tag: 'Importante',
    ),
    _Topic(
      icon: Icons.shield_rounded,
      color: Color(0xFF2196F3),
      title: 'Prevención de Violencia',
      description:
          'Aprende a identificar señales de violencia sexual y de género.',
      tag: 'Seguridad',
    ),
    _Topic(
      icon: Icons.medical_services_rounded,
      color: Color(0xFF4CAF50),
      title: 'Métodos Anticonceptivos',
      description:
          'Guía completa sobre tipos, eficacia y acceso a métodos anticonceptivos en Bolivia.',
      tag: 'Salud',
    ),
    _Topic(
      icon: Icons.warning_amber_rounded,
      color: Color(0xFFF57C00),
      title: '¿Qué hacer si estás en riesgo?',
      description:
          'Pasos a seguir si sientes que puedes ser víctima de un ataque o violencia.',
      tag: 'Urgente',
    ),
    _Topic(
      icon: Icons.healing_rounded,
      color: Color(0xFF00BCD4),
      title: 'Qué hacer después',
      description:
          'Apoyo, recursos y pasos legales tras una situación de violencia sexual.',
      tag: 'Recuperación',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: widget.isEmbedded
          ? AppBar(title: const Text('Educación DSDR'))
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
                      Text('Educación', style: AppTheme.headlineLarge),
                      const SizedBox(height: 6),
                      Text(
                        'Derechos Sexuales y Reproductivos',
                        style: AppTheme.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: 20),
                    // Search
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.divider),
                      ),
                      child: TextField(
                        style: AppTheme.bodyLarge,
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
                    Text('Temas disponibles', style: AppTheme.titleLarge),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((_, i) {
                  if (i >= _topics.length) return null;
                  final t = _topics[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _TopicCard(topic: t),
                  );
                }, childCount: _topics.length),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  final _Topic topic;

  const _TopicCard({required this.topic});

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      onTap: () {},
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: topic.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(topic.icon, color: topic.color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(topic.title, style: AppTheme.labelLarge),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: topic.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        topic.tag,
                        style: TextStyle(
                          color: topic.color,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  topic.description,
                  style: AppTheme.bodyMedium.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      'Leer más',
                      style: TextStyle(
                        color: topic.color,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward, color: topic.color, size: 14),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Topic {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final String tag;

  const _Topic({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.tag,
  });
}
