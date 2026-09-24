import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/analyst/hybrid_analyst.dart';
import 'repositories.dart';

/// Clientes HTTP mínimos (sin dependencias) para la IA opcional.
///
/// La clave la escribe el propio usuario en Ajustes y se guarda solo en el
/// dispositivo. Nada de esto se usa en CI ni en las pruebas.

TextGenerator? generatorFor(AiSettings s) {
  if (!s.enabled) return null;
  return switch (s.provider) {
    AiProvider.anthropic => AnthropicGenerator(s),
    AiProvider.openai => OpenAiCompatibleGenerator(s),
    AiProvider.none => null,
  };
}

Future<Map<String, dynamic>> _postJson(Uri uri, Map<String, String> headers, Object body) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
  try {
    final req = await client.postUrl(uri);
    headers.forEach(req.headers.set);
    req.headers.contentType = ContentType.json;
    req.add(utf8.encode(jsonEncode(body)));
    final res = await req.close().timeout(const Duration(seconds: 40));
    final text = await res.transform(utf8.decoder).join();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HttpException('HTTP ${res.statusCode}');
    }
    return Map<String, dynamic>.from(jsonDecode(text) as Map);
  } finally {
    client.close(force: true);
  }
}

class AnthropicGenerator implements TextGenerator {
  AnthropicGenerator(this.settings);
  final AiSettings settings;

  @override
  String get label => 'Claude (${settings.effectiveModel})';

  @override
  Future<String> complete({required String system, required String user}) async {
    final json = await _postJson(
      Uri.parse('${settings.effectiveBaseUrl}/v1/messages'),
      {
        'x-api-key': settings.apiKey.trim(),
        'anthropic-version': '2023-06-01',
      },
      {
        'model': settings.effectiveModel,
        'max_tokens': 600,
        'system': system,
        'messages': [
          {'role': 'user', 'content': user},
        ],
      },
    );
    final content = json['content'];
    if (content is List) {
      return content
          .whereType<Map>()
          .where((b) => b['type'] == 'text')
          .map((b) => b['text'].toString())
          .join('\n');
    }
    return '';
  }
}

class OpenAiCompatibleGenerator implements TextGenerator {
  OpenAiCompatibleGenerator(this.settings);
  final AiSettings settings;

  @override
  String get label => 'IA (${settings.effectiveModel})';

  @override
  Future<String> complete({required String system, required String user}) async {
    final json = await _postJson(
      Uri.parse('${settings.effectiveBaseUrl}/chat/completions'),
      {'Authorization': 'Bearer ${settings.apiKey.trim()}'},
      {
        'model': settings.effectiveModel,
        'max_tokens': 600,
        'temperature': 0.3,
        'messages': [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': user},
        ],
      },
    );
    final choices = json['choices'];
    if (choices is List && choices.isNotEmpty) {
      final msg = (choices.first as Map)['message'];
      if (msg is Map) return (msg['content'] ?? '').toString();
    }
    return '';
  }
}
