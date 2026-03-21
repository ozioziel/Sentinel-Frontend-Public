import 'dart:io';

import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/localization/app_language_service.dart';

class EmergencyCaptureResult {
  final bool videoStarted;
  final bool audioStarted;
  final Position? position;
  final String? videoPath;
  final String? audioPath;
  final List<String> issues;

  const EmergencyCaptureResult({
    required this.videoStarted,
    required this.audioStarted,
    required this.position,
    required this.videoPath,
    required this.audioPath,
    required this.issues,
  });

  bool get hasAnyAction => videoStarted || audioStarted || position != null;

  String? get mapsUrl {
    final current = position;
    if (current == null) return null;
    return 'https://maps.google.com/?q=${current.latitude},${current.longitude}';
  }
}

class EmergencyCaptureStopResult {
  final Position? position;
  final String? videoPath;
  final String? audioPath;
  final String? sessionDirectoryPath;
  final List<String> issues;

  const EmergencyCaptureStopResult({
    required this.position,
    required this.videoPath,
    required this.audioPath,
    required this.sessionDirectoryPath,
    required this.issues,
  });

  List<String> get attachmentPaths {
    final paths = <String>[];
    if (_fileExists(videoPath)) paths.add(videoPath!);
    if (_fileExists(audioPath)) paths.add(audioPath!);
    return paths;
  }

  bool get hasEvidence => attachmentPaths.isNotEmpty;

  String? get mapsUrl {
    final current = position;
    if (current == null) return null;
    return 'https://maps.google.com/?q=${current.latitude},${current.longitude}';
  }

  bool _fileExists(String? path) {
    if (path == null || path.isEmpty) return false;
    return File(path).existsSync();
  }
}

class EmergencyLocationResult {
  final Position? position;
  final List<String> issues;

  const EmergencyLocationResult({
    required this.position,
    required this.issues,
  });

  String? get mapsUrl {
    final current = position;
    if (current == null) return null;
    return 'https://maps.google.com/?q=${current.latitude},${current.longitude}';
  }
}

class EmergencyCaptureService {
  CameraController? _cameraController;
  Directory? _sessionDirectory;

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

  Future<EmergencyCaptureResult> startEmergencyCapture() async {
    final issues = <String>[];
    var videoStarted = false;
    var audioStarted = false;
    String? videoPath;
    Position? position;

    final cameraGranted = await _requestPermission(Permission.camera);
    final microphoneGranted = await _requestPermission(Permission.microphone);
    final locationGranted = await _requestLocationPermission();

    if (!cameraGranted) {
      issues.add(
        _t(
          es: 'Sin permiso de camara.',
          en: 'Camera permission is missing.',
          ay: 'Janiw camara permisox utjkiti.',
          qu: 'Camara permisoqa mana kanchu.',
        ),
      );
    }
    if (!microphoneGranted) {
      issues.add(
        _t(
          es: 'Sin permiso de microfono.',
          en: 'Microphone permission is missing.',
          ay: 'Janiw microfono permisox utjkiti.',
          qu: 'Microfono permisoqa mana kanchu.',
        ),
      );
    }
    if (!locationGranted) {
      issues.add(
        _t(
          es: 'Sin permiso de ubicacion.',
          en: 'Location permission is missing.',
          ay: 'Janiw ubicacion permisox utjkiti.',
          qu: 'Ubicacion permisoqa mana kanchu.',
        ),
      );
    }

    final sessionDirectory = await _createSessionDirectory();
    _sessionDirectory = sessionDirectory;

    if (cameraGranted) {
      try {
        final cameras = await availableCameras();
        final selectedCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first,
        );

        final controller = CameraController(
          selectedCamera,
          ResolutionPreset.medium,
          enableAudio: microphoneGranted,
        );

        await controller.initialize();
        if (Platform.isIOS) {
          await controller.prepareForVideoRecording();
        }

        videoPath = p.join(sessionDirectory.path, 'sos_video.mp4');
        await controller.startVideoRecording();
        _cameraController = controller;
        videoStarted = true;
        audioStarted = microphoneGranted;
      } catch (_) {
        issues.add(
          _t(
            es: 'No se pudo iniciar la grabacion de video.',
            en: 'The video recording could not start.',
            ay: 'Janiw video grabacion qalltañjamakiti.',
            qu: 'Video grabacionqa mana qallariyta atikurqanchu.',
          ),
        );
      }
    }

    if (locationGranted) {
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
      } catch (_) {
        issues.add(
          _t(
            es: 'No se pudo obtener la ubicacion actual.',
            en: 'The current location could not be fetched.',
            ay: 'Jichha ubicacion janiw apsusiskaspati.',
            qu: 'Kunan pachapi ubicacionqa mana tarikusqachu.',
          ),
        );
      }
    }

    return EmergencyCaptureResult(
      videoStarted: videoStarted,
      audioStarted: audioStarted,
      position: position,
      videoPath: videoPath,
      audioPath: null,
      issues: issues,
    );
  }

  Future<EmergencyCaptureStopResult> stopEmergencyCapture() async {
    final issues = <String>[];
    final sessionDirectoryPath = _sessionDirectory?.path;
    String? videoPath;
    Position? position;

    try {
      final controller = _cameraController;
      if (controller != null) {
        if (controller.value.isRecordingVideo) {
          final recordedVideo = await controller.stopVideoRecording();
          videoPath = await _finalizeVideoFile(recordedVideo.path);
          if (videoPath == null || videoPath.isEmpty) {
            issues.add(
              _t(
                es: 'No se pudo preparar el video de la alerta.',
                en: 'The alert video could not be prepared.',
                ay: 'Janiw alerta videox wakicht\'at akiti.',
                qu: 'Alerta videota mana wakichiyta atikurqanchu.',
              ),
            );
          }
        }
        await controller.dispose();
      }
    } catch (_) {
      issues.add(
        _t(
          es: 'No se pudo guardar el video de la alerta.',
          en: 'The alert video could not be saved.',
          ay: 'Janiw alerta videox imat akiti.',
          qu: 'Alerta videota mana waqaychayta atikurqanchu.',
        ),
      );
    } finally {
      _cameraController = null;
    }

    try {
      if (await _hasLocationAccess()) {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
      }
      } catch (_) {
      issues.add(
        _t(
          es: 'No se pudo actualizar la ubicacion final.',
          en: 'The final location could not be updated.',
          ay: 'Janiw qhipa ubicacion machaqtayañjamakiti.',
          qu: 'Qhipa ubicacionqa mana musuqyachiyta atikurqanchu.',
        ),
      );
    } finally {
      _sessionDirectory = null;
    }

    return EmergencyCaptureStopResult(
      position: position,
      videoPath: videoPath,
      audioPath: null,
      sessionDirectoryPath: sessionDirectoryPath,
      issues: issues,
    );
  }

  Future<EmergencyLocationResult> captureCurrentLocation() async {
    final issues = <String>[];

    final locationGranted = await _requestLocationPermission();
    if (!locationGranted) {
      issues.add(
        _t(
          es: 'Sin permiso de ubicacion.',
          en: 'Location permission is missing.',
          ay: 'Janiw ubicacion permisox utjkiti.',
          qu: 'Ubicacion permisoqa mana kanchu.',
        ),
      );
      return EmergencyLocationResult(position: null, issues: issues);
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      return EmergencyLocationResult(position: position, issues: issues);
    } catch (_) {
      issues.add(
        _t(
          es: 'No se pudo obtener la ubicacion actual.',
          en: 'The current location could not be fetched.',
          ay: 'Jichha ubicacion janiw apsusiskaspati.',
          qu: 'Kunan pachapi ubicacionqa mana tarikusqachu.',
        ),
      );
      return EmergencyLocationResult(position: null, issues: issues);
    }
  }

  Future<bool> _requestPermission(Permission permission) async {
    final status = await permission.request();
    return status.isGranted || status.isLimited;
  }

  Future<bool> _requestLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    final status = await Permission.locationWhenInUse.request();
    return status.isGranted || status.isLimited;
  }

  Future<bool> _hasLocationAccess() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    final status = await Permission.locationWhenInUse.status;
    return status.isGranted || status.isLimited;
  }

  Future<Directory> _createSessionDirectory() async {
    final baseDirectory = await getApplicationDocumentsDirectory();
    final evidenceDirectory = Directory(
      p.join(baseDirectory.path, 'emergency_evidence'),
    );
    if (!await evidenceDirectory.exists()) {
      await evidenceDirectory.create(recursive: true);
    }

    final sessionDirectory = Directory(
      p.join(
        evidenceDirectory.path,
        'emergency_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );

    if (!await sessionDirectory.exists()) {
      await sessionDirectory.create(recursive: true);
    }

    return sessionDirectory;
  }

  Future<String?> _persistVideoFile(String? sourcePath) async {
    if (sourcePath == null || sourcePath.isEmpty) return null;

    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) return null;

    final sessionDirectory = _sessionDirectory;
    if (sessionDirectory == null) {
      return sourceFile.path;
    }

    final extension = p.extension(sourcePath);
    final targetPath = p.join(
      sessionDirectory.path,
      'sos_video${extension.isEmpty ? '.mp4' : extension}',
    );

    if (p.equals(sourceFile.path, targetPath)) {
      return sourceFile.path;
    }

    try {
      final movedFile = await sourceFile.rename(targetPath);
      return movedFile.path;
    } catch (_) {
      final copiedFile = await sourceFile.copy(targetPath);
      try {
        await sourceFile.delete();
      } catch (_) {
        // Keep cleanup resilient after a successful copy.
      }
      return copiedFile.path;
    }
  }

  Future<String?> _finalizeVideoFile(String? sourcePath) async {
    final persistedPath = await _persistVideoFile(sourcePath);
    if (persistedPath == null || persistedPath.isEmpty) {
      return null;
    }

    final file = File(persistedPath);
    if (!await file.exists()) {
      return null;
    }

    int? lastSize;
    var stableReads = 0;

    for (var attempt = 0; attempt < 12; attempt++) {
      if (!await file.exists()) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        continue;
      }

      final currentSize = await file.length();
      if (currentSize > 0 && currentSize == lastSize) {
        stableReads++;
      } else {
        stableReads = 0;
      }

      lastSize = currentSize;

      if (currentSize > 0 && stableReads >= 1) {
        return file.path;
      }

      await Future<void>.delayed(const Duration(milliseconds: 300));
    }

    return (lastSize ?? 0) > 0 ? file.path : null;
  }
}
