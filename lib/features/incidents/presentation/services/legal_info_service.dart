import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/localization/app_language_service.dart';
import '../../../auth/presentation/services/auth_service.dart';

class LegalLaw {
  final String ley;
  final List<String> articulos;
  final String descripcionBreve;
  final String porQueAplica;

  const LegalLaw({
    required this.ley,
    required this.articulos,
    required this.descripcionBreve,
    required this.porQueAplica,
  });
}

class LegalInfoResult {
  final bool success;
  final List<LegalLaw> leyes;
  final double? bestScore;
  final bool usedRagContext;
  final String? errorMessage;

  const LegalInfoResult({
    required this.success,
    required this.leyes,
    this.bestScore,
    this.usedRagContext = false,
    this.errorMessage,
  });
}

class LegalInfoService {
  static const String _ragApiBaseUrl = String.fromEnvironment(
    'RAG_API_BASE_URL',
    defaultValue: 'http://144.22.43.169:8000',
  );

  final http.Client _client;
  final AuthService _authService;

  LegalInfoService({http.Client? client, AuthService? authService})
    : _client = client ?? http.Client(),
      _authService = authService ?? AuthService();

  Future<LegalInfoResult> fetchApplicableLaws({
    required String evidencia,
    int maxLeyes = 3,
  }) async {
    final trimmed = evidencia.trim();
    if (trimmed.isEmpty) {
      return LegalInfoResult(
        success: false,
        leyes: const [],
        errorMessage: _t(
          es: 'El incidente no tiene descripcion para analizar.',
          en: 'The incident has no description to analyze.',
          ay: 'Incidentex janiw analizañatakix descripcion utjkiti.',
          qu: 'Incidenteqa mana analizanapaq descripcionniyjchu.',
        ),
      );
    }

    final user = await _authService.getSession();
    final token = user?.accessToken ?? '';

    final uri = _buildUri('/rag/evidence/laws');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: headers,
            body: jsonEncode({'evidencia': trimmed, 'max_leyes': maxLeyes}),
          )
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      return LegalInfoResult(
        success: false,
        leyes: const [],
        errorMessage: _t(
          es: 'No se pudo conectar con el servicio legal.',
          en: 'Could not connect to the legal service.',
          ay: 'Janiw legal serviciow mantañjamakiti.',
          qu: 'Legal servicioman mana conectayta atikurqanchu.',
        ),
      );
    }

    final map = _decodeMap(response.bodyBytes);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return LegalInfoResult(
        success: false,
        leyes: const [],
        errorMessage:
            _extractError(map) ??
            _t(
              es: 'Error del servidor legal (${response.statusCode}).',
              en: 'Legal server error (${response.statusCode}).',
              ay: 'Legal servidor pantjawi (${response.statusCode}).',
              qu: 'Legal servidor pantay (${response.statusCode}).',
            ),
      );
    }

    if (map['success'] == false) {
      return LegalInfoResult(
        success: false,
        leyes: const [],
        errorMessage:
            _extractError(map) ??
            _t(
              es: 'El servicio legal no pudo procesar la consulta.',
              en: 'The legal service could not process the query.',
              ay: 'Legal serviciox janiw jiskt\'am lurkiti.',
              qu: 'Legal servicioqa tapuyniykita mana procesayta atikurqanchu.',
            ),
      );
    }

    final data = map['data'];
    final dataMap = data is Map<String, dynamic>
        ? data
        : (data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{});

    final rawLeyes = dataMap['leyes'];
    final leyes = <LegalLaw>[];
    if (rawLeyes is List) {
      for (final item in rawLeyes) {
        if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          final rawArticulos = m['articulos'];
          final articulos = rawArticulos is List
              ? rawArticulos.map((e) => e.toString()).toList()
              : <String>[];
          leyes.add(
            LegalLaw(
              ley: m['ley']?.toString() ?? '',
              articulos: articulos,
              descripcionBreve: m['descripcion_breve']?.toString() ?? '',
              porQueAplica: m['por_que_aplica']?.toString() ?? '',
            ),
          );
        }
      }
    }

    final bestScore = (dataMap['best_score'] as num?)?.toDouble();
    final usedRag = dataMap['used_rag_context'] == true;

    return LegalInfoResult(
      success: true,
      leyes: leyes,
      bestScore: bestScore,
      usedRagContext: usedRag,
    );
  }

  Uri _buildUri(String path) {
    final baseUri = Uri.parse(_ragApiBaseUrl);
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final basePath = baseUri.path.endsWith('/')
        ? baseUri.path.substring(0, baseUri.path.length - 1)
        : baseUri.path;
    return baseUri.replace(path: '$basePath$normalizedPath');
  }

  Map<String, dynamic> _decodeMap(List<int> bodyBytes) {
    if (bodyBytes.isEmpty) return {};
    final body = utf8.decode(bodyBytes, allowMalformed: true);
    if (body.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return {};
  }

  String? _extractError(Map<String, dynamic> map) {
    final message = map['message'];
    if (message is String && message.trim().isNotEmpty) return message.trim();
    final detail = map['detail'];
    if (detail is String && detail.trim().isNotEmpty) return detail.trim();
    return null;
  }

  String _t({
    required String es,
    required String en,
    required String ay,
    required String qu,
  }) {
    return AppLanguageService.instance.pick(es: es, en: en, ay: ay, qu: qu);
  }
}
