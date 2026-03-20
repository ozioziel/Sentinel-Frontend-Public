import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../auth/presentation/services/auth_service.dart';
import '../../../auth/presentation/services/contacts_service.dart';
import 'emergency_capture_service.dart';

class EmergencyActionResult {
  final bool success;
  final String? message;

  const EmergencyActionResult({required this.success, this.message});
}

class EmergencyAlertService {
  final AuthService _authService;
  final ContactsService _contactsService;

  EmergencyAlertService({
    AuthService? authService,
    ContactsService? contactsService,
  }) : _authService = authService ?? AuthService(),
       _contactsService = contactsService ?? ContactsService();

  Future<EmergencyActionResult> sendLocationAlert({String? locationUrl}) async {
    final user = await _authService.getSession();
    if (user == null) {
      return const EmergencyActionResult(
        success: false,
        message: 'No hay una sesion activa.',
      );
    }

    final contacts = await _contactsService.getContacts(user.id);
    final contactNamesByPhone = <String, String>{};
    for (final contact in contacts) {
      final normalizedPhone = _normalizePhone(contact.phone);
      if (normalizedPhone.isEmpty) continue;
      contactNamesByPhone.putIfAbsent(normalizedPhone, () => contact.name);
    }

    final phones = contactNamesByPhone.keys.toList();
    if (phones.isEmpty) {
      return const EmergencyActionResult(
        success: false,
        message: 'No tienes contactos de emergencia configurados.',
      );
    }

    final message = _buildEmergencyMessage(locationUrl);
    final opened = phones.length == 1
        ? await _openSingleRecipientAlert(phone: phones.first, message: message)
        : await _shareAlertMessage(phones: phones, message: message);

    if (!opened) {
      return const EmergencyActionResult(
        success: false,
        message: 'No se pudo abrir WhatsApp ni compartir la alerta.',
      );
    }

    final suffix = phones.length == 1
        ? ' para ${contactNamesByPhone[phones.first] ?? 'tu contacto'}.'
        : ' para compartirla con ${phones.length} contactos.';
    return EmergencyActionResult(
      success: true,
      message: 'Se preparo la alerta con tu ubicacion$suffix',
    );
  }

  Future<EmergencyActionResult> shareEvidence({
    required EmergencyCaptureStopResult stopResult,
    String? locationUrl,
  }) async {
    final attachmentPaths = stopResult.attachmentPaths;
    if (attachmentPaths.isEmpty) {
      return const EmergencyActionResult(
        success: false,
        message:
            'La alerta se detuvo, pero no se genero audio o video para compartir.',
      );
    }

    final filesToShare = _buildEvidenceFilesForShare(stopResult);
    if (filesToShare.isEmpty) {
      return const EmergencyActionResult(
        success: false,
        message: 'No se encontro un archivo compatible para compartir.',
      );
    }

    try {
      final shareMessage = _buildEmergencyMessage(locationUrl);
      final result = await SharePlus.instance.share(
        ShareParams(
          text: shareMessage,
          title: 'Evidencia de emergencia',
          subject: 'Evidencia de emergencia',
          files: filesToShare,
        ),
      );

      if (result.status == ShareResultStatus.unavailable) {
        return const EmergencyActionResult(
          success: false,
          message: 'No se pudo abrir el menu para compartir la evidencia.',
        );
      }

      if (result.status == ShareResultStatus.dismissed) {
        return const EmergencyActionResult(
          success: false,
          message: 'Se canceló el envio de la evidencia.',
        );
      }

      return EmergencyActionResult(
        success: true,
        message: _buildEvidenceShareMessage(
          stopResult: stopResult,
          locationUrl: locationUrl,
        ),
      );
    } catch (_) {
      return const EmergencyActionResult(
        success: false,
        message: 'No se pudo preparar la evidencia para compartir.',
      );
    }
  }

  Future<EmergencyActionResult> callEmergencyContact(
    ContactModel contact,
  ) async {
    final phone = _normalizePhone(contact.phone);
    if (phone.isEmpty) {
      return EmergencyActionResult(
        success: false,
        message: 'El contacto ${contact.name} no tiene un numero valido.',
      );
    }

    final callUri = Uri(scheme: 'tel', path: phone);

    try {
      final opened = await launchUrl(
        callUri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        return EmergencyActionResult(
          success: false,
          message: 'No se pudo iniciar la llamada a ${contact.name}.',
        );
      }

      return const EmergencyActionResult(success: true);
    } catch (_) {
      return EmergencyActionResult(
        success: false,
        message: 'Ocurrio un error al intentar llamar a ${contact.name}.',
      );
    }
  }

  String _buildEmergencyMessage(String? locationUrl) {
    if (locationUrl == null) {
      return 'Hola, necesito ayuda ahora.';
    }

    return 'Hola, necesito ayuda ahora. Mi ubicacion es: $locationUrl';
  }

  String _buildEvidenceShareMessage({
    required EmergencyCaptureStopResult stopResult,
    String? locationUrl,
  }) {
    final hasVideo =
        stopResult.videoPath != null &&
        stopResult.attachmentPaths.contains(stopResult.videoPath);
    final hasAudio =
        stopResult.audioPath != null &&
        stopResult.attachmentPaths.contains(stopResult.audioPath);

    if (hasVideo && hasAudio) {
      final baseMessage = _buildEmergencyMessage(locationUrl);
      return '$baseMessage Se preparo el video SOS para compartir. El audio adicional quedo guardado como respaldo.';
    }

    if (hasVideo) {
      final baseMessage = _buildEmergencyMessage(locationUrl);
      return '$baseMessage Se preparo el video SOS para compartir.';
    }

    if (hasAudio) {
      final baseMessage = _buildEmergencyMessage(locationUrl);
      return '$baseMessage Se preparo el audio SOS para compartir.';
    }

    return 'La evidencia se guardo y se abrio para compartir.';
  }

  Future<bool> _openSingleRecipientAlert({
    required String phone,
    required String message,
  }) async {
    if (await _openWhatsAppMessage(phone: phone, message: message)) {
      return true;
    }

    return _openSmsComposer(phones: [phone], message: message);
  }

  Future<bool> _shareAlertMessage({
    required List<String> phones,
    required String message,
  }) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: message,
          title: 'Alerta de emergencia',
          subject: 'Alerta de emergencia',
        ),
      );
      return true;
    } catch (_) {
      return _openSmsComposer(phones: phones, message: message);
    }
  }

  Future<bool> _openWhatsAppMessage({
    required String phone,
    required String message,
  }) async {
    final whatsappPhone = _normalizeWhatsAppPhone(phone);
    if (whatsappPhone.isEmpty) return false;

    final whatsappUri = Uri.parse(
      'whatsapp://send?${_encodeQueryParameters({'phone': whatsappPhone, 'text': message})}',
    );

    try {
      final opened = await launchUrl(
        whatsappUri,
        mode: LaunchMode.externalApplication,
      );
      if (opened) return true;
    } catch (_) {
      // Try the web fallback below.
    }

    final webFallbackUri = Uri.https('wa.me', '/$whatsappPhone', {
      'text': message,
    });

    try {
      return await launchUrl(
        webFallbackUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> _openSmsComposer({
    required List<String> phones,
    required String message,
  }) async {
    final recipients = phones
        .where((phone) => phone.isNotEmpty)
        .join(_smsRecipientSeparator);
    if (recipients.isEmpty) return false;

    final smsUri = Uri(
      scheme: 'sms',
      path: recipients,
      query: _encodeQueryParameters({'body': message}),
    );

    try {
      return await launchUrl(smsUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  String _normalizePhone(String phone) {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) return '';

    final hasLeadingPlus = trimmed.startsWith('+');
    var digits = trimmed.replaceAll(RegExp(r'\D'), '');

    if (digits.startsWith('00')) {
      digits = digits.substring(2);
      return digits.isEmpty ? '' : '+$digits';
    }

    if (hasLeadingPlus) {
      return digits.isEmpty ? '' : '+$digits';
    }

    if (digits.startsWith('591')) {
      return '+$digits';
    }

    if (digits.length == 8) {
      return '+591$digits';
    }

    return digits;
  }

  String _normalizeWhatsAppPhone(String phone) {
    final normalized = _normalizePhone(phone);
    if (normalized.isEmpty) return '';
    return normalized.replaceAll('+', '');
  }

  String get _smsRecipientSeparator =>
      defaultTargetPlatform == TargetPlatform.iOS ? ',' : ';';

  String _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map(
          (entry) =>
              '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}',
        )
        .join('&');
  }

  List<XFile> _buildEvidenceFilesForShare(
    EmergencyCaptureStopResult stopResult,
  ) {
    final files = <XFile>[];

    final videoPath = stopResult.videoPath;
    if (videoPath != null && stopResult.attachmentPaths.contains(videoPath)) {
      files.add(XFile(videoPath, mimeType: 'video/mp4'));
      return files;
    }

    final audioPath = stopResult.audioPath;
    if (audioPath != null && stopResult.attachmentPaths.contains(audioPath)) {
      files.add(XFile(audioPath, mimeType: 'audio/mp4'));
    }

    return files;
  }
}
