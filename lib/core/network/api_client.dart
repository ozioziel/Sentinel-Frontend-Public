import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../navigation/app_navigator.dart';
import '../routes/app_routes.dart';
import 'api_exception.dart';

class ApiClient {
  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, dynamic>> getJson(
    String path, {
    String? accessToken,
    Map<String, dynamic>? queryParameters,
  }) {
    final request = http.Request('GET', _buildUri(path, queryParameters))
      ..headers.addAll(_buildHeaders(accessToken: accessToken));
    return _sendRequest(request);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, dynamic> body,
    String? accessToken,
  }) {
    final request = http.Request('POST', _buildUri(path))
      ..headers.addAll(_buildHeaders(accessToken: accessToken))
      ..body = jsonEncode(body);
    return _sendRequest(request);
  }

  Future<Map<String, dynamic>> putJson(
    String path, {
    required Map<String, dynamic> body,
    String? accessToken,
  }) {
    final request = http.Request('PUT', _buildUri(path))
      ..headers.addAll(_buildHeaders(accessToken: accessToken))
      ..body = jsonEncode(body);
    return _sendRequest(request);
  }

  Future<Map<String, dynamic>> deleteJson(String path, {String? accessToken}) {
    final request = http.Request('DELETE', _buildUri(path))
      ..headers.addAll(_buildHeaders(accessToken: accessToken));
    return _sendRequest(request);
  }

  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required String fileField,
    required String filePath,
    required Map<String, String> fields,
    required MediaType contentType,
    String? accessToken,
  }) async {
    final request = http.MultipartRequest('POST', _buildUri(path))
      ..headers.addAll(_buildHeaders(accessToken: accessToken, isJson: false))
      ..fields.addAll(fields)
      ..files.add(
        await http.MultipartFile.fromPath(
          fileField,
          filePath,
          contentType: contentType,
        ),
      );

    return _sendRequest(request);
  }

  Future<Map<String, dynamic>> _sendRequest(http.BaseRequest request) async {
    late final http.StreamedResponse streamedResponse;

    try {
      streamedResponse = await _client
          .send(request)
          .timeout(const Duration(seconds: 25));
    } catch (_) {
      _throwLogged(const ApiException(message: 'No se pudo conectar con el servidor.'));
    }

    final response = await http.Response.fromStream(streamedResponse);
    final parsedBody = _decodeBody(response.body);
    final responseMap = _normalizeResponse(parsedBody);

    if (response.statusCode == 401) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('sentinel_session');
      AppNavigator.navigatorKey.currentState?.pushNamedAndRemoveUntil(
        AppRoutes.login,
        (route) => false,
      );
      _throwLogged(const ApiException(
        message: 'La sesion ha expirado. Por favor inicia sesion nuevamente.',
        statusCode: 401,
      ));
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwLogged(ApiException(
        message: _extractMessage(responseMap, fallback: 'Error del servidor.'),
        statusCode: response.statusCode,
        details: responseMap['details'],
      ));
    }

    if (responseMap['success'] == false) {
      _throwLogged(ApiException(
        message: _extractMessage(responseMap, fallback: 'Operacion fallida.'),
        statusCode: response.statusCode,
        details: responseMap['details'],
      ));
    }

    return responseMap;
  }

  Uri _buildUri(String path, [Map<String, dynamic>? queryParameters]) {
    final baseUri = Uri.parse(AppConstants.backendBaseUrl);
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final basePath = baseUri.path.endsWith('/')
        ? baseUri.path.substring(0, baseUri.path.length - 1)
        : baseUri.path;
    final resolvedPath = '$basePath$normalizedPath';
    final normalizedQuery = queryParameters?.map(
      (key, value) => MapEntry(key, value?.toString() ?? ''),
    );

    return baseUri.replace(
      path: resolvedPath.isEmpty ? '/' : resolvedPath,
      queryParameters: (normalizedQuery?.isEmpty ?? true)
          ? null
          : normalizedQuery,
    );
  }

  Map<String, String> _buildHeaders({String? accessToken, bool isJson = true}) {
    final headers = <String, String>{'Accept': 'application/json'};

    if (isJson) {
      headers['Content-Type'] = 'application/json';
    }

    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    return headers;
  }

  dynamic _decodeBody(String body) {
    if (body.trim().isEmpty) {
      return <String, dynamic>{};
    }

    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  Map<String, dynamic> _normalizeResponse(dynamic body) {
    if (body is Map<String, dynamic>) {
      return body;
    }

    if (body is Map) {
      return body.map((key, value) => MapEntry(key.toString(), value));
    }

    return {'success': true, 'data': body};
  }

  String _extractMessage(
    Map<String, dynamic> response, {
    required String fallback,
  }) {
    final message = response['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message;
    }

    return fallback;
  }

  Never _throwLogged(ApiException e) {
    debugPrint('[ApiClient] ${e.toString()}');
    throw e;
  }
}
