import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/localization/app_language_service.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/services/app_branding_service.dart';
import '../../../auth/presentation/models/contact_model.dart';
import '../../../auth/presentation/services/auth_service.dart';
import '../../../auth/presentation/services/contacts_service.dart';
import 'emergency_capture_service.dart';

class EmergencyActionResult {
  final bool success;
  final String? message;

  const EmergencyActionResult({required this.success, this.message});
}

class EmergencyAlertService {
  static const String _pendingAlertKey = 'pending_whatsapp_alert_v1';
  static const String _pendingWhatsAppAlertKey = _pendingAlertKey;
  static const String _pendingAlertChannelWhatsApp = 'whatsapp';
  static const String _pendingAlertChannelSms = 'sms';

  final AuthService _authService;
  final ContactsService _contactsService;
  final Connectivity _connectivity;
  final ApiClient _apiClient;

  EmergencyAlertService({
    AuthService? authService,
    ContactsService? contactsService,
    Connectivity? connectivity,
    ApiClient? apiClient,
  }) : _authService = authService ?? AuthService(),
       _contactsService = contactsService ?? ContactsService(),
       _connectivity = connectivity ?? Connectivity(),
       _apiClient = apiClient ?? ApiClient();

  String _t({
    required String es,
    required String en,
    required String ay,
    required String qu,
  }) {
    return AppLanguageService.instance.pick(es: es, en: en, ay: ay, qu: qu);
  }

  Future<EmergencyActionResult> sendLocationAlert({
    String? locationUrl,
    DateTime? alertTriggeredAt,
  }) async {
    final contacts = await _loadEmergencyContacts();
    if (contacts == null) {
      return EmergencyActionResult(
        success: false,
        message: _t(
          es: 'No hay una sesion activa.',
          en: 'There is no active session.',
          ay: 'Janiw sesion activa utjkiti.',
          qu: 'Sesion activaqa mana kanchu.',
        ),
      );
    }

    if (contacts.phones.isEmpty) {
      return EmergencyActionResult(
        success: false,
        message: _t(
          es: 'No tienes contactos de emergencia con numero configurado.',
          en: 'You do not have emergency contacts with a configured number.',
          ay: 'Janiw numero wakicht\'ata emergencia contactonakamax utjkiti.',
          qu: 'Numero wakichisqayuq emergencia contactosniyki mana kanchu.',
        ),
      );
    }

    final triggeredAt = alertTriggeredAt ?? DateTime.now();
    final message = _buildEmergencyMessage(
      locationUrl,
      alertTriggeredAt: triggeredAt,
    );
    final hasInternet = await _hasInternetLikeConnection();

    if (contacts.phones.length > 1) {
      final smsOpened = await _openSmsComposer(
        phones: contacts.phones,
        message: message,
      );
      if (smsOpened) {
        await _clearPendingAlert();
        return EmergencyActionResult(
          success: true,
          message: _t(
            es: 'Se preparo un SMS de emergencia con fecha, hora y ubicacion para ${contacts.phones.length} contactos.',
            en: 'An emergency SMS with date, time and location was prepared for ${contacts.phones.length} contacts.',
            ay: 'Uru, hora ukat ubicacionamp emergencia SMS ukax ${contacts.phones.length} contacto ukataki wakicht\'atawa.',
            qu: 'P\'unchaw, hora, ubicacionwan emergencia SMSqa ${contacts.phones.length} contactospaq wakichisqa kashan.',
          ),
        );
      }

      if (hasInternet) {
        final shared = await _shareAlertMessage(message: message);
        if (shared) {
          await _clearPendingAlert();
          return EmergencyActionResult(
            success: true,
            message: _t(
              es: 'No se pudo abrir el SMS grupal. Se preparo la alerta para compartirla con ${contacts.phones.length} contactos.',
              en: 'The group SMS could not be opened. The alert was prepared to share with ${contacts.phones.length} contacts.',
              ay: 'Taqi contactoanakar SMS apayañax janiw jist\'arañjamakiti. Alerta wakicht\'atawa ${contacts.phones.length} contacto ukamp apnaqañataki.',
              qu: 'SMS grupal kichariyta mana atikurqanchu. Alertaqa wakichisqa kashan ${contacts.phones.length} contactoswan rakinapaq.',
            ),
          );
        }
      }

      await _savePendingAlert(
        _PendingAlert(
          phones: contacts.phones,
          recipientLabel: contacts.recipientLabel,
          message: message,
          alertTriggeredAtIso: triggeredAt.toIso8601String(),
          preferredChannel: _pendingAlertChannelSms,
        ),
      );

      return EmergencyActionResult(
        success: true,
        message: _t(
          es: 'No se pudo abrir el SMS grupal. La alerta quedo guardada y se intentara nuevamente para ${contacts.recipientLabel}.',
          en: 'The group SMS could not be opened. The alert was saved and will be retried for ${contacts.recipientLabel}.',
          ay: 'Taqi contactoanakar SMS apayañax janiw jist\'arañjamakiti. Alerta imatawa ukat ${contacts.recipientLabel} ukataki mayamp yant\'ataniwa.',
          qu: 'SMS grupal kichariyta mana atikurqanchu. Alertaqa waqaychasqa kashan hinaspa ${contacts.recipientLabel}paq yapamanta yachasqa kanqa.',
        ),
      );
    }

    if (hasInternet) {
      final opened = await _openWhatsAppMessage(
        phone: contacts.primaryPhone,
        message: message,
      );

      if (opened) {
        await _clearPendingWhatsAppAlert();
        final suffix = contacts.phones.length == 1
            ? _t(
                es: ' para ${contacts.primaryContactName}.',
                en: ' for ${contacts.primaryContactName}.',
                ay: ' ${contacts.primaryContactName} ukatakisa.',
                qu: ' ${contacts.primaryContactName}paq.',
              )
            : _t(
                es: ' para compartirla con ${contacts.phones.length} contactos.',
                en: ' to share it with ${contacts.phones.length} contacts.',
                ay: ' ${contacts.phones.length} contactompi apnaqañataki.',
                qu: ' ${contacts.phones.length} contactoswan rakinapaq.',
              );
        return EmergencyActionResult(
          success: true,
          message:
              _t(
                es: 'Se preparo la alerta con fecha, hora y ubicacion',
                en: 'The alert was prepared with date, time and location',
                ay: 'Uru, hora ukat ubicacionamp alerta wakicht\'atawa',
                qu: 'P\'unchaw, hora, ubicacionwan alerta wakichisqa kashan',
              ) +
              suffix,
        );
      }
    }

    final smsOpened = await _openSmsComposer(
      phones: contacts.phones,
      message: message,
    );
    if (smsOpened) {
      await _clearPendingWhatsAppAlert();
      final prefix = hasInternet
          ? _t(
              es: 'No se pudo abrir WhatsApp,',
              en: 'WhatsApp could not be opened,',
              ay: 'Janiw WhatsApp jist\'arañjamakiti,',
              qu: 'WhatsApp mana kichariyta atikurqanchu,',
            )
          : _t(
              es: 'No habia internet,',
              en: 'There was no internet,',
              ay: 'Janiw internet utjkataynati,',
              qu: 'Internet mana karqanchu,',
            );
      final suffix = contacts.phones.length == 1
          ? _t(
              es: ' para ${contacts.primaryContactName}.',
              en: ' for ${contacts.primaryContactName}.',
              ay: ' ${contacts.primaryContactName} ukatakisa.',
              qu: ' ${contacts.primaryContactName}paq.',
            )
          : _t(
              es: ' para ${contacts.phones.length} contactos.',
              en: ' for ${contacts.phones.length} contacts.',
              ay: ' ${contacts.phones.length} contacto ukataki.',
              qu: ' ${contacts.phones.length} contactospaq.',
            );
      return EmergencyActionResult(
        success: true,
        message:
            '$prefix ${_t(es: 'se preparo un SMS de emergencia', en: 'an emergency SMS was prepared', ay: 'maya emergencia SMS wakicht\'atawa', qu: 'huk emergencia SMS wakichisqa kashan')}$suffix',
      );
    }

    await _savePendingWhatsAppAlert(
      _PendingWhatsAppAlert(
        phone: contacts.primaryPhone,
        contactName: contacts.primaryContactName,
        message: message,
        alertTriggeredAtIso: triggeredAt.toIso8601String(),
      ),
    );

    return EmergencyActionResult(
      success: true,
      message: _t(
        es: 'No habia internet ni SMS disponible. La alerta quedo guardada y se intentara abrir WhatsApp para ${contacts.primaryContactName} cuando vuelva la conexion.',
        en: 'There was no internet or SMS available. The alert was saved and WhatsApp will be retried for ${contacts.primaryContactName} when the connection returns.',
        ay: 'Janiw internet ni SMS utjkataynati. Alerta imatawa ukat conexion kutt\'anxasax ${contacts.primaryContactName} ukatak WhatsApp jist\'arañ yant\'ataniwa.',
        qu: 'Mana internet nitaq SMS karqanchu. Alerta waqaychasqa kashan, hinaspa conexion kutimuptin ${contacts.primaryContactName}paq WhatsApp kichariyta yapamanta yachasqa kanqa.',
      ),
    );
  }

  Future<EmergencyActionResult> sendTextAlert({
    DateTime? alertTriggeredAt,
  }) {
    return sendLocationAlert(alertTriggeredAt: alertTriggeredAt);
  }

  Future<EmergencyActionResult?> retryPendingWhatsAppAlert() async {
    final pendingAlert = await _loadPendingWhatsAppAlert();
    if (pendingAlert == null) {
      return null;
    }

    final hasInternet = await _hasInternetLikeConnection();
    if (!hasInternet) {
      return null;
    }

    final opened = await _openWhatsAppMessage(
      phone: pendingAlert.phone,
      message: pendingAlert.message,
    );
    if (!opened) {
      return null;
    }

    await _clearPendingWhatsAppAlert();
    return EmergencyActionResult(
      success: true,
      message: _t(
        es: 'Se reanudo la alerta pendiente por WhatsApp para ${pendingAlert.contactName}.',
        en: 'The pending WhatsApp alert for ${pendingAlert.contactName} resumed.',
        ay: '${pendingAlert.contactName} ukatak WhatsApp suyt\'ata alertax mayamp qalltatawa.',
        qu: '${pendingAlert.contactName}paq suyasqa WhatsApp alerta yapamanta qallarirqan.',
      ),
    );
  }

  Future<EmergencyActionResult?> retryPendingAlert() async {
    final pendingAlert = await _loadPendingAlert();
    if (pendingAlert == null) {
      return null;
    }

    final opened = pendingAlert.preferredChannel == _pendingAlertChannelSms
        ? await _openSmsComposer(
            phones: pendingAlert.phones,
            message: pendingAlert.message,
          )
        : await _retryPendingWhatsAppAlertForRecipient(pendingAlert);
    if (!opened) {
      return null;
    }

    await _clearPendingAlert();
    return EmergencyActionResult(
      success: true,
      message: _t(
        es: 'Se reanudo la alerta pendiente para ${pendingAlert.recipientLabel}.',
        en: 'The pending alert for ${pendingAlert.recipientLabel} resumed.',
        ay: '${pendingAlert.recipientLabel} ukatak suyt\'ata alertax mayamp qalltatawa.',
        qu: '${pendingAlert.recipientLabel}paq suyasqa alerta yapamanta qallarirqan.',
      ),
    );
  }

  Future<EmergencyActionResult> shareEvidence({
    required EmergencyCaptureStopResult stopResult,
    String? locationUrl,
    DateTime? alertTriggeredAt,
  }) async {
    final attachmentPaths = _buildEvidenceAttachmentPaths(stopResult);
    if (attachmentPaths.isEmpty) {
      return EmergencyActionResult(
        success: false,
        message: _t(
          es: 'La alerta se detuvo, pero no se genero audio o video para enviar.',
          en: 'The alert stopped, but no audio or video was generated to send.',
          ay: 'Alertax sayt\'atawa, ukampis janiw audio ni video apayañatak luraskiti.',
          qu: 'Alertaqa sayarqan, ichaqa mana audio nitaq video apachanapaq ruwasqachu.',
        ),
      );
    }

    final triggeredAt = alertTriggeredAt ?? DateTime.now();
    final contacts = await _loadEmergencyContacts();
    final emailRecipients = contacts?.emails ?? const <String>[];

    if (emailRecipients.isNotEmpty) {
      final emailResult = await _prepareEvidenceEmail(
        stopResult: stopResult,
        locationUrl: locationUrl,
        alertTriggeredAt: triggeredAt,
        attachmentPaths: attachmentPaths,
        recipients: emailRecipients,
      );
      if (emailResult.success) {
        return emailResult;
      }
    }

    final filesToShare = _buildEvidenceFilesForShare(attachmentPaths);
    if (filesToShare.isEmpty) {
      return EmergencyActionResult(
        success: false,
        message: _t(
          es: 'No se encontro un archivo compatible para compartir la evidencia.',
          en: 'No compatible file was found to share the evidence.',
          ay: 'Janiw evidencia apnaqañatakix compatible archivo jikxataskiti.',
          qu: 'Evidenciata rakinapaq alli archivoqa mana tarikurqanchu.',
        ),
      );
    }

    try {
      final shareMessage = _buildEmergencyMessage(
        locationUrl,
        alertTriggeredAt: triggeredAt,
      );
      final result = await SharePlus.instance.share(
        ShareParams(
          text: shareMessage,
          title: _t(
            es: 'Evidencia de emergencia',
            en: 'Emergency evidence',
            ay: 'Emergencia evidencia',
            qu: 'Emergencia evidencia',
          ),
          subject: _t(
            es: 'Evidencia de emergencia',
            en: 'Emergency evidence',
            ay: 'Emergencia evidencia',
            qu: 'Emergencia evidencia',
          ),
          files: filesToShare,
        ),
      );

      if (result.status == ShareResultStatus.unavailable) {
        return EmergencyActionResult(
          success: false,
          message: emailRecipients.isEmpty
              ? _t(
                  es: 'No se pudo abrir el menu para compartir la evidencia.',
                  en: 'The share menu could not be opened for the evidence.',
                  ay: 'Janiw evidencia apnaqañatakix menu jist\'arañjamakiti.',
                  qu: 'Evidenciata rakinapaq menuqa mana kichariyta atikurqanchu.',
                )
              : _t(
                  es: 'No se pudo abrir el correo ni el menu para compartir la evidencia.',
                  en: 'Neither email nor the share menu could be opened for the evidence.',
                  ay: 'Janiw correo ni evidencia apnaqañatak menu jist\'arañjamakiti.',
                  qu: 'Correo nisqapas ni evidenciata rakinapaq menu nisqapas mana kichariyta atikurqanchu.',
                ),
        );
      }

      if (result.status == ShareResultStatus.dismissed) {
        return EmergencyActionResult(
          success: false,
          message: emailRecipients.isEmpty
              ? _t(
                  es: 'Se cancelo el envio de la evidencia.',
                  en: 'The evidence delivery was canceled.',
                  ay: 'Evidencia apayañax sayt\'ayatawa.',
                  qu: 'Evidencia apachiyqa sayachisqa karqan.',
                )
              : _t(
                  es: 'No se pudo abrir el correo y se cancelo el envio de la evidencia.',
                  en: 'Email could not be opened and the evidence delivery was canceled.',
                  ay: 'Janiw correo jist\'arañjamakiti ukat evidencia apayañax sayt\'ayatawa.',
                  qu: 'Correoqa mana kichariyta atikurqanchu, hinaspa evidencia apachiyqa sayachisqa karqan.',
                ),
        );
      }

      return EmergencyActionResult(
        success: true,
        message: _buildFallbackShareMessage(
          stopResult: stopResult,
          locationUrl: locationUrl,
          alertTriggeredAt: triggeredAt,
          hadEmailRecipients: emailRecipients.isNotEmpty,
        ),
      );
    } catch (_) {
      return EmergencyActionResult(
        success: false,
        message: emailRecipients.isEmpty
            ? _t(
                es: 'No se pudo preparar la evidencia para compartirla.',
                en: 'The evidence could not be prepared for sharing.',
                ay: 'Janiw evidencia apnaqañatakix wakicht\'añjamakiti.',
                qu: 'Evidenciata rakinapaq mana wakichiyta atikurqanchu.',
              )
            : _t(
                es: 'No se pudo preparar la evidencia para correo ni para compartirla.',
                en: 'The evidence could not be prepared for email or sharing.',
                ay: 'Janiw evidenciax correo ni apnaqañatakis wakicht\'añjamakiti.',
                qu: 'Evidenciaqa correo ni rakinapaqpas mana wakichiyta atikurqanchu.',
              ),
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
        message: _t(
          es: 'El contacto ${contact.name} no tiene un numero valido.',
          en: 'The contact ${contact.name} does not have a valid number.',
          ay: '${contact.name} contacto ukax janiw numero valido niyki.',
          qu: '${contact.name} contactoqa numero validoyuq mana kanchu.',
        ),
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
          message: _t(
            es: 'No se pudo iniciar la llamada a ${contact.name}.',
            en: 'The call to ${contact.name} could not be started.',
            ay: 'Janiw ${contact.name} ukar jawst\'aw qalltayañjamakiti.',
            qu: '${contact.name}man waqyayninta mana qallariyta atikurqanchu.',
          ),
        );
      }

      return const EmergencyActionResult(success: true);
    } catch (_) {
      return EmergencyActionResult(
        success: false,
        message: _t(
          es: 'Ocurrio un error al intentar llamar a ${contact.name}.',
          en: 'An error happened while trying to call ${contact.name}.',
          ay: '${contact.name} ukar jawst\'añ yant\'kasax pantjasiw utji.',
          qu: '${contact.name}man waqyayninta yachaspaymi pantay karqan.',
        ),
      );
    }
  }

  Future<_EmergencyContactsSnapshot?> _loadEmergencyContacts() async {
    final user = await _authService.getSession();
    if (user == null) {
      return null;
    }

    final contacts = await _contactsService.getContacts(user.id);
    final enabledContacts = contacts
        .where((contact) => contact.canReceiveAlerts)
        .toList();

    final contactNamesByPhone = <String, String>{};
    final emails = <String>[];
    for (final contact in enabledContacts) {
      final normalizedPhone = _normalizePhone(contact.phone);
      if (normalizedPhone.isNotEmpty) {
        contactNamesByPhone.putIfAbsent(normalizedPhone, () => contact.name);
      }

      final normalizedEmail = _normalizeEmail(contact.email);
      if (normalizedEmail != null && !emails.contains(normalizedEmail)) {
        emails.add(normalizedEmail);
      }
    }

    final phones = contactNamesByPhone.keys.toList();
    final primaryPhone = phones.isNotEmpty ? phones.first : '';
    final primaryContactName = primaryPhone.isEmpty
        ? _t(
            es: 'tu contacto prioritario',
            en: 'your priority contact',
            ay: 'nayriri contactomama',
            qu: 'aswan umalliq contactoyki',
          )
        : (contactNamesByPhone[primaryPhone] ??
              _t(
                es: 'tu contacto prioritario',
                en: 'your priority contact',
                ay: 'nayriri contactomama',
                qu: 'aswan umalliq contactoyki',
              ));
    final recipientLabel = phones.length == 1
        ? primaryContactName
        : _describeRecipients(phones);

    return _EmergencyContactsSnapshot(
      phones: phones,
      emails: emails,
      primaryPhone: primaryPhone,
      primaryContactName: primaryContactName,
      recipientLabel: recipientLabel,
    );
  }

  String _buildEmergencyMessage(
    String? locationUrl, {
    required DateTime alertTriggeredAt,
  }) {
    final appName = AppBrandingService.instance.displayName;
    final lines = <String>[
      _t(es: 'ALERTA SOS', en: 'SOS ALERT', ay: 'SOS ALERTA', qu: 'SOS ALERTA'),
      _t(
        es: 'Necesito ayuda ahora.',
        en: 'I need help right now.',
        ay: 'Jichhax yanapa muntwa.',
        qu: 'Kunan pachapi yanapayta munani.',
      ),
      _t(
        es: 'Fecha y hora: ${_formatAlertTimestamp(alertTriggeredAt)}',
        en: 'Date and time: ${_formatAlertTimestamp(alertTriggeredAt)}',
        ay: 'Uru ukat hora: ${_formatAlertTimestamp(alertTriggeredAt)}',
        qu: 'P\'unchawwan horawan: ${_formatAlertTimestamp(alertTriggeredAt)}',
      ),
    ];

    if (locationUrl != null && locationUrl.trim().isNotEmpty) {
      lines.add(
        _t(
          es: 'Ubicacion: $locationUrl',
          en: 'Location: $locationUrl',
          ay: 'Ubicacion: $locationUrl',
          qu: 'Ubicacion: $locationUrl',
        ),
      );
    }

    lines.add(
      _t(
        es: 'Enviado desde $appName.',
        en: 'Sent from $appName.',
        ay: '$appName ukat apayatawa.',
        qu: '$appName manta apachisqa.',
      ),
    );
    return lines.join('\n');
  }

  String _buildEvidenceShareMessage({
    required EmergencyCaptureStopResult stopResult,
    required DateTime alertTriggeredAt,
    String? locationUrl,
  }) {
    final hasVideo =
        stopResult.videoPath != null &&
        stopResult.attachmentPaths.contains(stopResult.videoPath);
    final hasAudio =
        stopResult.audioPath != null &&
        stopResult.attachmentPaths.contains(stopResult.audioPath);

    if (hasVideo && hasAudio) {
      final baseMessage = _buildEmergencyMessage(
        locationUrl,
        alertTriggeredAt: alertTriggeredAt,
      );
      return '$baseMessage ${_t(es: 'Se prepararon el video SOS y el audio de respaldo.', en: 'The SOS video and backup audio were prepared.', ay: 'SOS video ukat yanapt\'iri audio wakicht\'atawa.', qu: 'SOS videowan yanapakuq audiowan wakichisqa karqan.')}';
    }

    if (hasVideo) {
      final baseMessage = _buildEmergencyMessage(
        locationUrl,
        alertTriggeredAt: alertTriggeredAt,
      );
      return '$baseMessage ${_t(es: 'Se preparo el video SOS.', en: 'The SOS video was prepared.', ay: 'SOS videox wakicht\'atawa.', qu: 'SOS videoqa wakichisqa karqan.')}';
    }

    if (hasAudio) {
      final baseMessage = _buildEmergencyMessage(
        locationUrl,
        alertTriggeredAt: alertTriggeredAt,
      );
      return '$baseMessage ${_t(es: 'Se preparo el audio SOS.', en: 'The SOS audio was prepared.', ay: 'SOS audiox wakicht\'atawa.', qu: 'SOS audioqa wakichisqa karqan.')}';
    }

    return _t(
      es: 'La evidencia se guardo correctamente.',
      en: 'The evidence was saved correctly.',
      ay: 'Evidenciax wali sum imatawa.',
      qu: 'Evidenciaqa allinta waqaychasqa karqan.',
    );
  }

  String _buildEvidenceEmailBody({
    required EmergencyCaptureStopResult stopResult,
    required DateTime alertTriggeredAt,
    String? locationUrl,
  }) {
    final hasVideo =
        stopResult.videoPath != null &&
        stopResult.attachmentPaths.contains(stopResult.videoPath);
    final hasAudio =
        stopResult.audioPath != null &&
        stopResult.attachmentPaths.contains(stopResult.audioPath);

    final lines = <String>[
      _buildEmergencyMessage(locationUrl, alertTriggeredAt: alertTriggeredAt),
      '',
      _t(
        es: 'Se adjuntan las evidencias registradas durante la alerta SOS.',
        en: 'The evidence recorded during the SOS alert is attached.',
        ay: 'SOS alerta pachan qillqt\'ata evidencianakax apkatawa.',
        qu: 'SOS alerta pachapi qillqasqa evidenciakuna yapasqa kashan.',
      ),
    ];

    if (hasVideo) {
      lines.add(
        _t(
          es: 'Incluye video capturado durante la emergencia.',
          en: 'It includes video captured during the emergency.',
          ay: 'Emergencia pachan katuqata videompiwa.',
          qu: 'Emergencia pachapi hapisqa videoyuqmi.',
        ),
      );
    }

    if (hasAudio) {
      lines.add(
        _t(
          es: 'Incluye audio de respaldo capturado durante la emergencia.',
          en: 'It includes backup audio captured during the emergency.',
          ay: 'Emergencia pachan katuqata yanapt\'iri audiompiwa.',
          qu: 'Emergencia pachapi hapisqa yanapakuq audiowanm.',
        ),
      );
    }

    return lines.join('\n');
  }

  String _buildEvidenceEmailPreparedMessage({
    required EmergencyCaptureStopResult stopResult,
    required DateTime alertTriggeredAt,
    required List<String> recipients,
    String? locationUrl,
  }) {
    final baseMessage = _buildEvidenceShareMessage(
      stopResult: stopResult,
      alertTriggeredAt: alertTriggeredAt,
      locationUrl: locationUrl,
    );
    return '$baseMessage ${_t(es: 'Se preparo un correo para ${_describeRecipients(recipients)}.', en: 'An email was prepared for ${_describeRecipients(recipients)}.', ay: '${_describeRecipients(recipients)} ukatak correo wakicht\'atawa.', qu: '${_describeRecipients(recipients)}paq correo wakichisqa kashan.')}';
  }

  String _buildFallbackShareMessage({
    required EmergencyCaptureStopResult stopResult,
    required DateTime alertTriggeredAt,
    required bool hadEmailRecipients,
    String? locationUrl,
  }) {
    final baseMessage = _buildEvidenceShareMessage(
      stopResult: stopResult,
      alertTriggeredAt: alertTriggeredAt,
      locationUrl: locationUrl,
    );
    if (hadEmailRecipients) {
      return '$baseMessage ${_t(es: 'No se pudo abrir el correo, pero se abrio el menu para compartir la evidencia.', en: 'Email could not be opened, but the share menu for the evidence was opened.', ay: 'Janiw correo jist\'arañjamakiti, ukampis evidencia apnaqañatakix menu jist\'aratawa.', qu: 'Correoqa mana kichariyta atikurqanchu, ichaqa evidenciata rakinapaq menuqa kicharisqa karqan.')}';
    }

    return '$baseMessage ${_t(es: 'Se abrio el menu para compartir la evidencia.', en: 'The share menu for the evidence was opened.', ay: 'Evidencia apnaqañatakix menu jist\'aratawa.', qu: 'Evidenciata rakinapaq menuqa kicharisqa karqan.')}';
  }

  Future<EmergencyActionResult> _prepareEvidenceEmail({
    required EmergencyCaptureStopResult stopResult,
    required List<String> attachmentPaths,
    required List<String> recipients,
    required DateTime alertTriggeredAt,
    String? locationUrl,
  }) async {
    final email = Email(
      recipients: recipients,
      subject:
          '${_t(es: 'Evidencia de emergencia SOS', en: 'SOS emergency evidence', ay: 'SOS emergencia evidencia', qu: 'SOS emergencia evidencia')} - ${_formatAlertTimestampForSubject(alertTriggeredAt)}',
      body: _buildEvidenceEmailBody(
        stopResult: stopResult,
        alertTriggeredAt: alertTriggeredAt,
        locationUrl: locationUrl,
      ),
      attachmentPaths: attachmentPaths,
      isHTML: false,
    );

    try {
      await FlutterEmailSender.send(email);
      return EmergencyActionResult(
        success: true,
        message: _buildEvidenceEmailPreparedMessage(
          stopResult: stopResult,
          alertTriggeredAt: alertTriggeredAt,
          recipients: recipients,
          locationUrl: locationUrl,
        ),
      );
    } catch (_) {
      return EmergencyActionResult(
        success: false,
        message: _t(
          es: 'No se pudo abrir una app de correo.',
          en: 'An email app could not be opened.',
          ay: 'Janiw correo app jist\'arañjamakiti.',
          qu: 'Correo appqa mana kichariyta atikurqanchu.',
        ),
      );
    }
  }

  Future<EmergencyActionResult> sendEvidenceEmailViaBackend({
    required List<String> evidenceIds,
    required DateTime alertTriggeredAt,
    String? locationUrl,
    bool hasVideo = false,
    bool hasAudio = false,
  }) async {
    final user = await _authService.getSession();
    if (user == null) {
      return EmergencyActionResult(
        success: false,
        message: _t(
          es: 'No hay una sesion activa para enviar el correo.',
          en: 'There is no active session to send the email.',
          ay: 'Janiw correo apayañatakix sesion activa utjkiti.',
          qu: 'Correo apachanapaq sesion activaqa mana kanchu.',
        ),
      );
    }

    final contacts = await _loadEmergencyContacts();
    final emailRecipients = contacts?.emails ?? const <String>[];

    if (emailRecipients.isEmpty) {
      return EmergencyActionResult(
        success: false,
        message: _t(
          es: 'No hay contactos de emergencia con correo configurado.',
          en: 'No emergency contacts have an email configured.',
          ay: 'Janiw correo wakicht\'ata emergencia contactonakamax utjkiti.',
          qu: 'Correo wakichisqayuq emergencia contactosniyki mana kanchu.',
        ),
      );
    }

    try {
      await _apiClient.postJson(
        '/emergency/send-email',
        accessToken: user.accessToken,
        body: {
          'recipients': emailRecipients,
          'subject':
              '${_t(
                es: 'Evidencia de emergencia SOS',
                en: 'SOS emergency evidence',
                ay: 'SOS emergencia evidencia',
                qu: 'SOS emergencia evidencia',
              )} - ${_formatAlertTimestampForSubject(alertTriggeredAt)}',
          'body': {
            'alert_message': _buildEmergencyMessage(
              locationUrl,
              alertTriggeredAt: alertTriggeredAt,
            ),
            'location_url': locationUrl,
            'alert_triggered_at': alertTriggeredAt.toIso8601String(),
            'has_video': hasVideo,
            'has_audio': hasAudio,
          },
          'evidence_ids': evidenceIds,
        },
      );

      return EmergencyActionResult(
        success: true,
        message: _t(
          es:
              'Se envio el correo de emergencia a ${_describeRecipients(emailRecipients)}.',
          en:
              'The emergency email was sent to ${_describeRecipients(emailRecipients)}.',
          ay:
              '${_describeRecipients(emailRecipients)} ukatak emergencia correo apayatawa.',
          qu:
              '${_describeRecipients(emailRecipients)}paq emergencia correoqa apachisqa karqan.',
        ),
      );
    } on ApiException catch (e) {
      debugPrint('[EmergencyAlertService] Email via backend failed: ${e.message} (status: ${e.statusCode})');
      return EmergencyActionResult(
        success: false,
        message: '${_t(
          es: 'No se pudo enviar el correo de emergencia.',
          en: 'The emergency email could not be sent.',
          ay: 'Janiw emergencia correo apayañjamakiti.',
          qu: 'Emergencia correoqa mana apachikurqanchu.',
        )} ${e.message}',
      );
    } catch (e) {
      debugPrint('[EmergencyAlertService] Email via backend unexpected error: $e');
      return EmergencyActionResult(
        success: false,
        message: _t(
          es: 'No se pudo conectar con el servidor para enviar el correo.',
          en: 'Could not connect to the server to send the email.',
          ay: 'Janiw correo apayañatakix servidorampi mayachasiyjamakiti.',
          qu: 'Correo apachanapaq servidorwan mana tinkanakuyta atikurqanchu.',
        ),
      );
    }
  }

  Future<bool> _shareAlertMessage({required String message}) async {
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          text: message,
          title: _t(
            es: 'Alerta de emergencia',
            en: 'Emergency alert',
            ay: 'Emergencia alerta',
            qu: 'Emergencia alerta',
          ),
          subject: _t(
            es: 'Alerta de emergencia',
            en: 'Emergency alert',
            ay: 'Emergencia alerta',
            qu: 'Emergencia alerta',
          ),
        ),
      );
      return result.status != ShareResultStatus.unavailable &&
          result.status != ShareResultStatus.dismissed;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _openWhatsAppMessage({
    required String phone,
    required String message,
  }) async {
    final whatsappPhone = _normalizeWhatsAppPhone(phone);
    if (whatsappPhone.isEmpty) {
      return false;
    }

    final whatsappUri = Uri.parse(
      'whatsapp://send?${_encodeQueryParameters({'phone': whatsappPhone, 'text': message})}',
    );

    try {
      final opened = await launchUrl(
        whatsappUri,
        mode: LaunchMode.externalApplication,
      );
      if (opened) {
        return true;
      }
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
    if (recipients.isEmpty) {
      return false;
    }

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

  Future<bool> _hasInternetLikeConnection() async {
    final Object result = await _connectivity.checkConnectivity();
    if (result is List<ConnectivityResult>) {
      return _hasAnyActiveConnection(result);
    }
    if (result is ConnectivityResult) {
      return result != ConnectivityResult.none;
    }
    return false;
  }

  bool _hasAnyActiveConnection(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }

  Future<bool> _retryPendingWhatsAppAlertForRecipient(
    _PendingAlert pendingAlert,
  ) async {
    final phone = pendingAlert.primaryPhone;
    if (phone.isEmpty) {
      return false;
    }

    final hasInternet = await _hasInternetLikeConnection();
    if (!hasInternet) {
      return false;
    }

    return _openWhatsAppMessage(phone: phone, message: pendingAlert.message);
  }

  Future<void> _savePendingAlert(_PendingAlert alert) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingAlertKey, jsonEncode(alert.toJson()));
  }

  Future<_PendingAlert?> _loadPendingAlert() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingAlertKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return _PendingAlert.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearPendingAlert() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingAlertKey);
  }

  Future<void> _savePendingWhatsAppAlert(_PendingWhatsAppAlert alert) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingWhatsAppAlertKey, jsonEncode(alert.toJson()));
  }

  Future<_PendingWhatsAppAlert?> _loadPendingWhatsAppAlert() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingWhatsAppAlertKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return _PendingWhatsAppAlert.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearPendingWhatsAppAlert() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingWhatsAppAlertKey);
  }

  String _normalizePhone(String phone) {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) {
      return '';
    }

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
    if (normalized.isEmpty) {
      return '';
    }
    return normalized.replaceAll('+', '');
  }

  String? _normalizeEmail(String? email) {
    final trimmed = (email ?? '').trim().toLowerCase();
    if (trimmed.isEmpty) {
      return null;
    }

    final isValid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(trimmed);
    return isValid ? trimmed : null;
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

  List<String> _buildEvidenceAttachmentPaths(
    EmergencyCaptureStopResult stopResult,
  ) {
    final files = <String>[];

    final videoPath = stopResult.videoPath;
    if (videoPath != null && stopResult.attachmentPaths.contains(videoPath)) {
      files.add(videoPath);
    }

    final audioPath = stopResult.audioPath;
    if (audioPath != null && stopResult.attachmentPaths.contains(audioPath)) {
      files.add(audioPath);
    }

    return files;
  }

  List<XFile> _buildEvidenceFilesForShare(List<String> attachmentPaths) {
    final files = <XFile>[];

    for (final path in attachmentPaths) {
      final normalizedPath = path.toLowerCase();
      if (normalizedPath.endsWith('.mp4')) {
        files.add(XFile(path, mimeType: 'video/mp4'));
        continue;
      }

      if (normalizedPath.endsWith('.m4a') || normalizedPath.endsWith('.aac')) {
        files.add(XFile(path, mimeType: 'audio/mp4'));
      }
    }

    return files;
  }

  String _formatAlertTimestamp(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString().padLeft(4, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  String _formatAlertTimestampForSubject(DateTime value) {
    final local = value.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  String _describeRecipients(List<String> recipients) {
    if (recipients.length == 1) {
      return recipients.first;
    }

    return _t(
      es: '${recipients.length} contactos de emergencia',
      en: '${recipients.length} emergency contacts',
      ay: '${recipients.length} emergencia contactos',
      qu: '${recipients.length} emergencia contactos',
    );
  }
}

class _EmergencyContactsSnapshot {
  final List<String> phones;
  final List<String> emails;
  final String primaryPhone;
  final String primaryContactName;
  final String recipientLabel;

  const _EmergencyContactsSnapshot({
    required this.phones,
    required this.emails,
    required this.primaryPhone,
    required this.primaryContactName,
    required this.recipientLabel,
  });
}

class _PendingAlert {
  final List<String> phones;
  final String recipientLabel;
  final String message;
  final String alertTriggeredAtIso;
  final String preferredChannel;

  const _PendingAlert({
    required this.phones,
    required this.recipientLabel,
    required this.message,
    required this.alertTriggeredAtIso,
    required this.preferredChannel,
  });

  String get primaryPhone => phones.isNotEmpty ? phones.first : '';

  Map<String, dynamic> toJson() => {
    'phones': phones,
    'recipientLabel': recipientLabel,
    'message': message,
    'alertTriggeredAtIso': alertTriggeredAtIso,
    'preferredChannel': preferredChannel,
  };

  factory _PendingAlert.fromJson(Map<String, dynamic> json) {
    final phonesFromJson =
        (json['phones'] as List<dynamic>?)
            ?.map(_readString)
            .where((phone) => phone.trim().isNotEmpty)
            .toList() ??
        <String>[];
    final legacyPhone = _readString(json['phone']);
    final phones = phonesFromJson.isNotEmpty
        ? phonesFromJson
        : (legacyPhone.trim().isEmpty ? <String>[] : <String>[legacyPhone]);
    final recipientLabelFallback = _readString(
      json['contactName'],
      fallback: AppLanguageService.instance.pick(
        es: phones.length > 1
            ? '${phones.length} contactos de emergencia'
            : 'tu contacto prioritario',
        en: phones.length > 1
            ? '${phones.length} emergency contacts'
            : 'your priority contact',
        ay: phones.length > 1
            ? '${phones.length} emergencia contactos'
            : 'nayriri contactomama',
        qu: phones.length > 1
            ? '${phones.length} emergencia contactos'
            : 'aswan umalliq contactoyki',
      ),
    );

    return _PendingAlert(
      phones: phones,
      recipientLabel: _readString(
        json['recipientLabel'],
        fallback: recipientLabelFallback,
      ),
      message: _readString(json['message']),
      alertTriggeredAtIso: _readString(json['alertTriggeredAtIso']),
      preferredChannel: _readString(
        json['preferredChannel'],
        fallback: phones.length > 1
            ? EmergencyAlertService._pendingAlertChannelSms
            : EmergencyAlertService._pendingAlertChannelWhatsApp,
      ),
    );
  }
}

class _PendingWhatsAppAlert {
  final String phone;
  final String contactName;
  final String message;
  final String alertTriggeredAtIso;

  const _PendingWhatsAppAlert({
    required this.phone,
    required this.contactName,
    required this.message,
    required this.alertTriggeredAtIso,
  });

  Map<String, dynamic> toJson() => {
    'phone': phone,
    'contactName': contactName,
    'message': message,
    'alertTriggeredAtIso': alertTriggeredAtIso,
  };

  factory _PendingWhatsAppAlert.fromJson(Map<String, dynamic> json) {
    return _PendingWhatsAppAlert(
      phone: _readString(json['phone']),
      contactName: _readString(
        json['contactName'],
        fallback: AppLanguageService.instance.pick(
          es: 'tu contacto prioritario',
          en: 'your priority contact',
          ay: 'nayriri contactomama',
          qu: 'aswan umalliq contactoyki',
        ),
      ),
      message: _readString(json['message']),
      alertTriggeredAtIso: _readString(json['alertTriggeredAtIso']),
    );
  }
}

String _readString(dynamic value, {String fallback = ''}) {
  if (value is String) {
    return value;
  }
  if (value == null) {
    return fallback;
  }
  return value.toString();
}
