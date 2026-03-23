import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/localization/app_language_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_card.dart';
import '../../domain/models/evidence_record.dart';
import 'evidence_components.dart';

String _t({
  required String es,
  required String en,
  required String ay,
  required String qu,
}) {
  return AppLanguageService.instance.pick(
    es: es,
    en: en,
    ay: ay,
    qu: qu,
  );
}

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
      return _PreviewFallback(
        icon: Icons.image_not_supported_outlined,
        title: _t(
          es: 'No hay vista previa disponible',
          en: 'No preview available',
          ay: 'Janiw nayra uñjañax utjkiti',
          qu: 'Mana ñawpaq rikuy kanchu',
        ),
        subtitle: _t(
          es: 'La evidencia no incluye una URL o archivo para mostrar.',
          en: 'The evidence does not include a URL or file to display.',
          ay: 'Evidenciax janiw uñacht\'ayañatak URL ni archivo apankiti.',
          qu: 'Evidenciaqa URL nitaq archivo rikuchinapaq mana apamunchu.',
        ),
      );
    }

    final image = fileUrl.startsWith('http')
        ? Image.network(
            fileUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _PreviewFallback(
              icon: Icons.broken_image_outlined,
              title: _t(
                es: 'No se pudo cargar la imagen',
                en: 'The image could not be loaded',
                ay: 'Janiw imagen cargañjamakiti',
                qu: 'Imagenqa mana cargayta atikurqanchu',
              ),
              subtitle: _t(
                es: 'Intenta abrir el archivo de forma externa.',
                en: 'Try opening the file externally.',
                ay: 'Archivor anqaxat jist\'arañ yant\'am.',
                qu: 'Archivota hawa ladtamanta kichariyta yant\'ay.',
              ),
            ),
          )
        : Image.file(
            File(fileUrl),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _PreviewFallback(
              icon: Icons.broken_image_outlined,
              title: _t(
                es: 'No se pudo abrir la imagen',
                en: 'The image could not be opened',
                ay: 'Janiw imagen jist\'arañjamakiti',
                qu: 'Imagenqa mana kichariyta atikurqanchu',
              ),
              subtitle: _t(
                es: 'El archivo local ya no esta disponible.',
                en: 'The local file is no longer available.',
                ay: 'Local archivox janiw utjxiti.',
                qu: 'Local archivoqa manan kashanchu.',
              ),
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
        _errorMessage = _t(
          es: 'No hay un archivo disponible para reproducir.',
          en: 'There is no available file to play.',
          ay: 'Janiw anatayañatakix archivo utjkiti.',
          qu: 'Purichinapaq archivoqa mana kanchu.',
        );
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
        _errorMessage = _t(
          es: 'No se pudo inicializar la vista previa del video.',
          en: 'The video preview could not be initialized.',
          ay: 'Janiw video nayra uñjañax qalltayañjamakiti.',
          qu: 'Video ñawpaq rikuyqa mana qallariyta atikurqanchu.',
        );
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
    AppLanguageScope.watch(context);
    if (_isLoading) {
      return _PreviewLoading(
        label: _t(
          es: 'Preparando video...',
          en: 'Preparing video...',
          ay: 'Video wakicht\'aski...',
          qu: 'Video wakichikushan...',
        ),
      );
    }

    if (_errorMessage != null || _controller == null) {
      return _PreviewFallback(
        icon: Icons.videocam_off_rounded,
        title: _t(
          es: 'No se pudo cargar el video',
          en: 'The video could not be loaded',
          ay: 'Janiw video cargañjamakiti',
          qu: 'Videoqa mana cargayta atikurqanchu',
        ),
        subtitle: _errorMessage ??
            _t(
              es: 'Intenta abrir el archivo externamente.',
              en: 'Try opening the file externally.',
              ay: 'Archivor anqaxat jist\'arañ yant\'am.',
              qu: 'Archivota hawa ladtamanta kichariyta yant\'ay.',
            ),
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
        _errorMessage = _t(
          es: 'No hay un archivo disponible para reproducir.',
          en: 'There is no available file to play.',
          ay: 'Janiw anatayañatakix archivo utjkiti.',
          qu: 'Purichinapaq archivoqa mana kanchu.',
        );
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
        _errorMessage = _t(
          es: 'No se pudo inicializar el reproductor de audio.',
          en: 'The audio player could not be initialized.',
          ay: 'Janiw audio anatirix qalltayañjamakiti.',
          qu: 'Audio purichiqqa mana qallariyta atikurqanchu.',
        );
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
    AppLanguageScope.watch(context);
    if (_isLoading) {
      return _PreviewLoading(
        label: _t(
          es: 'Preparando audio...',
          en: 'Preparing audio...',
          ay: 'Audio wakicht\'aski...',
          qu: 'Audio wakichikushan...',
        ),
      );
    }

    if (_errorMessage != null) {
      return _PreviewFallback(
        icon: Icons.volume_off_rounded,
        title: _t(
          es: 'No se pudo cargar el audio',
          en: 'The audio could not be loaded',
          ay: 'Janiw audio cargañjamakiti',
          qu: 'Audioqa mana cargayta atikurqanchu',
        ),
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
            _t(
              es:
                  'La vista previa de documentos queda preparada para abrir o descargar el archivo segun el soporte disponible.',
              en:
                  'The document preview is ready to open or download the file depending on the available support.',
              ay:
                  'Documentonakan nayra uñjañapax archivo jist\'arañataki jan ukax apaqañataki wakicht\'atawa.',
              qu:
                  'Documento ñawpaq rikuyqa archivo kicharinapaq utaq uraykachinapaq wakichisqa kashan.',
            ),
            style: AppTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: canOpen ? _openEvidenceFile : null,
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(
                canOpen
                    ? _t(
                        es: 'Abrir archivo',
                        en: 'Open file',
                        ay: 'Archivo jist\'ara',
                        qu: 'Archivo kichariy',
                      )
                    : _t(
                        es: 'Archivo no disponible',
                        en: 'File unavailable',
                        ay: 'Archivo janiw utjkiti',
                        qu: 'Archivo mana kanchu',
                      ),
              ),
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
