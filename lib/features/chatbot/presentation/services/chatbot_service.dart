import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/constants/app_constants.dart';

class ChatbotTurn {
  final String role;
  final String content;

  const ChatbotTurn({required this.role, required this.content});
}

class ChatbotException implements Exception {
  final String message;

  const ChatbotException(this.message);

  @override
  String toString() => 'ChatbotException: $message';
}

class ChatbotService {
  static const String _systemPrompt = '''
Eres una asistente de apoyo para una app de seguridad personal en Bolivia.
Responde siempre en espanol claro, empatico y practico.
Prioriza orientacion breve y accionable sobre seguridad, apoyo emocional, denuncias y rutas de ayuda.
Si la persona describe peligro inmediato, sugiere usar la alerta SOS de la app, buscar un lugar seguro y contactar emergencias o alguien de confianza.
No inventes direcciones, telefonos, instituciones ni datos no confirmados.
No digas que eres terapeuta, abogada o policia.
Mantén las respuestas en menos de 140 palabras salvo que la usuaria pida mas detalle.
''';

  final http.Client _client;

  ChatbotService({http.Client? client}) : _client = client ?? http.Client();

  bool get isConfigured => AppConstants.groqApiKey.trim().isNotEmpty;

  Future<String> generateReply(List<ChatbotTurn> conversation) async {
    final apiKey = AppConstants.groqApiKey.trim();
    if (apiKey.isEmpty) {
      throw const ChatbotException(
        'Falta configurar GROQ_API_KEY. Usa flutter_groq.cmd run o agrega el dart-define en tu configuración de ejecución.',
      );
    }

    final payload = {
      'model': AppConstants.groqChatModel,
      'temperature': 0.4,
      'top_p': 1,
      'stream': false,
      'max_completion_tokens': 300,
      'messages': [
        const {'role': 'system', 'content': _systemPrompt},
        ...conversation
            .where((turn) => turn.content.trim().isNotEmpty)
            .take(12)
            .map((turn) => {'role': turn.role, 'content': turn.content.trim()}),
      ],
    };

    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('${AppConstants.groqApiBaseUrl}/chat/completions'),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw const ChatbotException('No se pudo conectar con Groq.');
    }

    final responseMap = _decodeMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ChatbotException(
        _extractError(responseMap) ??
            'Groq devolvió un error ${response.statusCode}.',
      );
    }

    final choices = responseMap['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const ChatbotException(
        'Groq no devolvió una respuesta utilizable.',
      );
    }

    final firstChoice = choices.first;
    if (firstChoice is! Map) {
      throw const ChatbotException(
        'Groq devolvió una respuesta con formato inesperado.',
      );
    }

    final message = firstChoice['message'];
    if (message is! Map) {
      throw const ChatbotException('Groq no devolvió el mensaje esperado.');
    }

    final content = message['content'];
    final parsedContent = _normalizeContent(content);
    if (parsedContent.isEmpty) {
      throw const ChatbotException('Groq respondió vacío.');
    }

    return parsedContent;
  }

  Map<String, dynamic> _decodeMap(String body) {
    if (body.trim().isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {
      return <String, dynamic>{};
    }

    return <String, dynamic>{};
  }

  String? _extractError(Map<String, dynamic> responseMap) {
    final error = responseMap['error'];
    if (error is Map<String, dynamic>) {
      final message = error['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }

    final message = responseMap['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message;
    }

    return null;
  }

  String _normalizeContent(dynamic content) {
    if (content is String) {
      return content.trim();
    }

    if (content is List) {
      final buffer = StringBuffer();
      for (final item in content) {
        if (item is Map && item['type'] == 'text') {
          final text = item['text'];
          if (text is String && text.trim().isNotEmpty) {
            if (buffer.isNotEmpty) {
              buffer.writeln();
            }
            buffer.write(text.trim());
          }
        }
      }
      return buffer.toString().trim();
    }

    return '';
  }
}
