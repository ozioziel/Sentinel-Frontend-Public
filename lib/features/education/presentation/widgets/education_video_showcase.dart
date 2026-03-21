import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/localization/app_language_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_card.dart';
import '../../domain/models/education_topic.dart';

class EducationVideoShowcase extends StatefulWidget {
  final EducationTopic topic;

  EducationVideoShowcase({super.key, required this.topic})
    : assert(topic.videoAssetPath != null && topic.videoAssetPath != '');

  @override
  State<EducationVideoShowcase> createState() => _EducationVideoShowcaseState();
}

class _EducationVideoShowcaseState extends State<EducationVideoShowcase> {
  VideoPlayerController? _controller;
  bool _isInitializing = true;
  String? _errorMessage;

  String _t({
    required String es,
    required String en,
    required String ay,
    required String qu,
  }) {
    return AppLanguageService.instance.pick(es: es, en: en, ay: ay, qu: qu);
  }

  @override
  void initState() {
    super.initState();
    unawaited(_initializePreview());
  }

  Future<void> _initializePreview() async {
    try {
      final controller = VideoPlayerController.asset(
        widget.topic.videoAssetPath!,
      );
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _isInitializing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _errorMessage = _t(
          es: 'No se pudo preparar la vista previa del video.',
          en: 'The video preview could not be prepared.',
          ay: 'Janiw video nayra uñjañax wakicht\'añjamakiti.',
          qu: 'Video ñawpaq rikuyqa mana wakichiyta atikurqanchu.',
        );
      });
    }
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final isPlaying = controller?.value.isPlaying ?? false;
    final previewSurface =
        Color.lerp(widget.topic.color, AppTheme.surface, 0.72) ??
        AppTheme.surface;
    final previewGlow =
        Color.lerp(widget.topic.color, AppTheme.primaryLight, 0.42) ??
        AppTheme.primaryLight;
    final actionLabel = isPlaying
        ? _t(
            es: 'Pausar vista previa',
            en: 'Pause preview',
            ay: 'Nayra uñjaña sayt\'aya',
            qu: 'Ñawpaq rikuyta sayachiy',
          )
        : _t(
            es: 'Reproducir vista previa',
            en: 'Play preview',
            ay: 'Nayra uñjaña qhantaya',
            qu: 'Ñawpaq rikuyta purichiy',
          );

    return CustomCard(
      backgroundColor: previewSurface,
      padding: const EdgeInsets.all(0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_isInitializing)
                    ColoredBox(color: previewSurface)
                  else if (controller != null && controller.value.isInitialized)
                    FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: controller.value.size.width,
                        height: controller.value.size.height,
                        child: VideoPlayer(controller),
                      ),
                    )
                  else
                    Container(
                      color: previewSurface,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _errorMessage ??
                            _t(
                              es: 'No hay vista previa disponible.',
                              en: 'No preview is available.',
                              ay: 'Janiw nayra uñjañax utjkiti.',
                              qu: 'Mana ñawpaq rikuy kanchu.',
                            ),
                        textAlign: TextAlign.center,
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textPrimary.withValues(alpha: 0.88),
                        ),
                      ),
                    ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          widget.topic.color.withValues(alpha: 0.16),
                          Colors.transparent,
                          previewSurface.withValues(alpha: 0.82),
                        ],
                        stops: const [0, 0.42, 1],
                      ),
                    ),
                  ),
                  Center(
                    child: GestureDetector(
                      onTap:
                          (controller != null && controller.value.isInitialized)
                          ? _togglePlayback
                          : null,
                      child: Container(
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                          color: previewSurface.withValues(alpha: 0.60),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: previewGlow.withValues(alpha: 0.24),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: widget.topic.color.withValues(alpha: 0.28),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 44,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: previewSurface.withValues(alpha: 0.68),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: previewGlow.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.visibility_rounded,
                            size: 14,
                            color: previewGlow,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _t(
                              es: 'Vista previa real',
                              en: 'Real preview',
                              ay: 'Chiqa nayra uñjaña',
                              qu: 'Chiqa ñawpaq rikuy',
                            ),
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.textPrimary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.topic.videoTitle,
                                style: AppTheme.titleLarge.copyWith(
                                  color: AppTheme.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.topic.videoDescription,
                                style: AppTheme.bodyMedium.copyWith(
                                  color: AppTheme.textPrimary.withValues(
                                    alpha: 0.84,
                                  ),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(widget.topic.icon, color: previewGlow, size: 22),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _VideoMetaChip(
                      icon: Icons.play_circle_outline_rounded,
                      label: context.tr('education.detail.video_example'),
                    ),
                    _VideoMetaChip(
                      icon: Icons.visibility_rounded,
                      label: _t(
                        es: 'Se ve antes de abrirlo',
                        en: 'See it before opening',
                        ay: 'Jist\'arañkamaw uñjasini',
                        qu: 'Kicharinaykikama rikuchikun',
                      ),
                    ),
                    _VideoMetaChip(
                      icon: Icons.volume_off_rounded,
                      label: _t(
                        es: 'Sin sonido',
                        en: 'Muted',
                        ay: 'Jan sonido',
                        qu: 'Mana uyarisqachu',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _t(
                    es: 'La vista previa ya muestra el video dentro de la pantalla para que la persona entienda mejor el contenido antes de reproducirlo.',
                    en: 'The preview now shows the video directly on the screen so the person can understand the content better before playing it.',
                    ay: 'Nayra uñjañax video pantallpach uñachtayi ukhamat jaqix contenido janiraq anatkasax amuyt\'añapataki.',
                    qu: 'Ñawpaq rikuyqa video pantallallapim rikuchin, chay hinam runaqa contenido nisqata manaraq purichispallaq aswan allinta unanchan.',
                  ),
                  style: AppTheme.bodyLarge.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed:
                      (controller != null && controller.value.isInitialized)
                      ? _togglePlayback
                      : null,
                  icon: Icon(
                    isPlaying
                        ? Icons.pause_circle_outline_rounded
                        : Icons.play_circle_outline_rounded,
                  ),
                  label: Text(actionLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoMetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _VideoMetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
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
