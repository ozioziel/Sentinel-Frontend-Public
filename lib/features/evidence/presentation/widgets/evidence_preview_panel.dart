import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_card.dart';
import '../../domain/models/evidence_record.dart';
import 'evidence_components.dart';

class EvidencePreviewPanel extends StatelessWidget {
  final EvidenceRecord evidence;

  const EvidencePreviewPanel({super.key, required this.evidence});

  @override
  Widget build(BuildContext context) {
    switch (evidence.type.toLowerCase()) {
      case 'imagen':
        return _ImagePreview(evidence: evidence);
      case 'video':
        return _VideoPreview(evidence: evidence);
      case 'audio':
        return _AudioPreview(evidence: evidence);
      default:
        return _DocumentPreview(evidence: evidence);
    }
  }
}

class _ImagePreview extends StatelessWidget {
  final EvidenceRecord evidence;

  const _ImagePreview({required this.evidence});

  @override
  Widget build(BuildContext context) {
    final fileUrl = evidence.fileUrl.trim();
    if (fileUrl.isEmpty) {
      return const _PreviewFallback(
        icon: Icons.image_not_supported_outlined,
        title: 'No hay vista previa disponible',
        subtitle: 'La evidencia no incluye una URL o archivo para mostrar.',
      );
    }

    final image = fileUrl.startsWith('http')
        ? Image.network(
            fileUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const _PreviewFallback(
              icon: Icons.broken_image_outlined,
              title: 'No se pudo cargar la imagen',
              subtitle: 'Intenta abrir el archivo de forma externa.',
            ),
          )
        : Image.file(
            File(fileUrl),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const _PreviewFallback(
              icon: Icons.broken_image_outlined,
              title: 'No se pudo abrir la imagen',
              subtitle: 'El archivo local ya no esta disponible.',
            ),
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(aspectRatio: 16 / 10, child: image),
    );
  }
}

class _VideoPreview extends StatefulWidget {
  final EvidenceRecord evidence;

  const _VideoPreview({required this.evidence});

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final source = widget.evidence.fileUrl.trim();
    if (source.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No hay un archivo disponible para reproducir.';
      });
      return;
    }

    try {
      final controller = source.startsWith('http')
          ? VideoPlayerController.networkUrl(Uri.parse(source))
          : VideoPlayerController.file(File(source));
      await controller.initialize();
      await controller.setLooping(false);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'No se pudo inicializar la vista previa del video.';
      });
    }
  }

  @override
  void dispose() {
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const _PreviewLoading(label: 'Preparando video...');
    }

    if (_errorMessage != null || _controller == null) {
      return _PreviewFallback(
        icon: Icons.videocam_off_rounded,
        title: 'No se pudo cargar el video',
        subtitle: _errorMessage ?? 'Intenta abrir el archivo externamente.',
      );
    }

    final controller = _controller!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: ColoredBox(
        color: Colors.black,
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: controller.value.aspectRatio == 0
                  ? 16 / 9
                  : controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () async {
                      if (controller.value.isPlaying) {
                        await controller.pause();
                      } else {
                        await controller.play();
                      }
                      if (mounted) {
                        setState(() {});
                      }
                    },
                    icon: Icon(
                      controller.value.isPlaying
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_fill_rounded,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Expanded(
                    child: VideoProgressIndicator(
                      controller,
                      allowScrubbing: true,
                      colors: VideoProgressColors(
                        playedColor: AppTheme.primary,
                        bufferedColor: AppTheme.textSecondary.withValues(
                          alpha: 0.32,
                        ),
                        backgroundColor: AppTheme.divider,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioPreview extends StatefulWidget {
  final EvidenceRecord evidence;

  const _AudioPreview({required this.evidence});

  @override
  State<_AudioPreview> createState() => _AudioPreviewState();
}

class _AudioPreviewState extends State<_AudioPreview> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _playerStateSubscription;
  bool _isLoading = true;
  String? _errorMessage;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final source = widget.evidence.fileUrl.trim();
    if (source.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No hay un archivo disponible para reproducir.';
      });
      return;
    }

    try {
      if (source.startsWith('http')) {
        await _player.setUrl(source);
      } else {
        await _player.setFilePath(source);
      }

      _duration = _player.duration ?? Duration.zero;
      _player.positionStream.listen((position) {
        if (!mounted) return;
        setState(() => _position = position);
      });
      _player.durationStream.listen((duration) {
        if (!mounted || duration == null) return;
        setState(() => _duration = duration);
      });
      _playerStateSubscription = _player.playerStateStream.listen((state) {
        if (!mounted) return;
        setState(() => _isPlaying = state.playing);
      });

      setState(() => _isLoading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'No se pudo inicializar el reproductor de audio.';
      });
    }
  }

  @override
  void dispose() {
    unawaited(_playerStateSubscription?.cancel());
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const _PreviewLoading(label: 'Preparando audio...');
    }

    if (_errorMessage != null) {
      return _PreviewFallback(
        icon: Icons.volume_off_rounded,
        title: 'No se pudo cargar el audio',
        subtitle: _errorMessage!,
      );
    }

    final maxMillis = _duration.inMilliseconds <= 0
        ? 1.0
        : _duration.inMilliseconds.toDouble();
    final currentMillis = _position.inMilliseconds
        .clamp(0, maxMillis.toInt())
        .toDouble();

    return CustomCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: IconButton(
                  onPressed: () async {
                    if (_isPlaying) {
                      await _player.pause();
                    } else {
                      await _player.play();
                    }
                  },
                  icon: Icon(
                    _isPlaying
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.evidence.title, style: AppTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                      style: AppTheme.bodyMedium.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Slider(
            value: currentMillis,
            min: 0,
            max: maxMillis,
            activeColor: AppTheme.primary,
            inactiveColor: AppTheme.divider,
            onChanged: (value) {
              setState(() => _position = Duration(milliseconds: value.round()));
            },
            onChangeEnd: (value) {
              _player.seek(Duration(milliseconds: value.round()));
            },
          ),
        ],
      ),
    );
  }
}

class _DocumentPreview extends StatelessWidget {
  final EvidenceRecord evidence;

  const _DocumentPreview({required this.evidence});

  Future<void> _openEvidenceFile() async {
    final source = evidence.fileUrl.trim();
    if (source.isEmpty) {
      return;
    }

    final uri = source.startsWith('http')
        ? Uri.parse(source)
        : Uri.file(source);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final style = evidenceTypeStyleFor(evidence.type);
    final canOpen = evidence.fileUrl.trim().isNotEmpty;

    return CustomCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: style.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(style.icon, color: style.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      evidence.fileName.isEmpty
                          ? evidence.title
                          : evidence.fileName,
                      style: AppTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      evidence.mimeType.trim().isEmpty
                          ? style.label
                          : evidence.mimeType,
                      style: AppTheme.bodyMedium.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'La vista previa de documentos queda preparada para abrir o descargar el archivo segun el soporte disponible.',
            style: AppTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: canOpen ? _openEvidenceFile : null,
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(canOpen ? 'Abrir archivo' : 'Archivo no disponible'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewLoading extends StatelessWidget {
  final String label;

  const _PreviewLoading({required this.label});

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const CircularProgressIndicator(color: AppTheme.primary),
          const SizedBox(height: 12),
          Text(label, style: AppTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _PreviewFallback extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PreviewFallback({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.textSecondary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 14),
          Text(title, style: AppTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: AppTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
