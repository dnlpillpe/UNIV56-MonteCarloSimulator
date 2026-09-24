import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/progress/progress.dart';
import '../domain/sim/model_spec.dart';

/// Persistencia local (sin backend): progreso, último modelo del simulador
/// y configuración opcional de IA. Local-first: la app funciona sin red y el
/// CI compila sin secretos.

class ProgressRepository {
  ProgressRepository(this._prefs);
  final SharedPreferences _prefs;
  static const _key = 'progress_v1';

  ProgressState load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return const ProgressState();
    try {
      return ProgressState.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return const ProgressState();
    }
  }

  Future<void> save(ProgressState s) => _prefs.setString(_key, jsonEncode(s.toJson()));

  Future<void> clear() => _prefs.remove(_key);
}

class ModelRepository {
  ModelRepository(this._prefs);
  final SharedPreferences _prefs;
  static const _key = 'sim_model_v1';

  ModelSpec? load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      return ModelSpec.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return null;
    }
  }

  Future<void> save(ModelSpec m) => _prefs.setString(_key, jsonEncode(m.toJson()));
}

enum AiProvider {
  none('Sin IA (solo motor)'),
  anthropic('Anthropic (Claude)'),
  openai('Compatible con OpenAI');

  const AiProvider(this.label);
  final String label;
}

class AiSettings {
  const AiSettings({
    this.provider = AiProvider.none,
    this.apiKey = '',
    this.model = '',
    this.baseUrl = '',
  });

  final AiProvider provider;
  final String apiKey;
  final String model;

  /// URL base para proveedores compatibles con OpenAI o un proxy propio.
  final String baseUrl;

  bool get enabled => provider != AiProvider.none && apiKey.trim().isNotEmpty;

  String get effectiveModel {
    if (model.trim().isNotEmpty) return model.trim();
    return switch (provider) {
      AiProvider.anthropic => 'claude-sonnet-4-5',
      AiProvider.openai => 'gpt-4o-mini',
      AiProvider.none => '',
    };
  }

  String get effectiveBaseUrl {
    if (baseUrl.trim().isNotEmpty) return baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    return switch (provider) {
      AiProvider.anthropic => 'https://api.anthropic.com',
      AiProvider.openai => 'https://api.openai.com/v1',
      AiProvider.none => '',
    };
  }

  AiSettings copyWith({AiProvider? provider, String? apiKey, String? model, String? baseUrl}) => AiSettings(
        provider: provider ?? this.provider,
        apiKey: apiKey ?? this.apiKey,
        model: model ?? this.model,
        baseUrl: baseUrl ?? this.baseUrl,
      );

  Map<String, Object?> toJson() => {
        'provider': provider.name,
        'apiKey': apiKey,
        'model': model,
        'baseUrl': baseUrl,
      };

  static AiSettings fromJson(Map<String, dynamic> j) => AiSettings(
        provider: AiProvider.values.firstWhere(
          (p) => p.name == j['provider'],
          orElse: () => AiProvider.none,
        ),
        apiKey: (j['apiKey'] as String?) ?? '',
        model: (j['model'] as String?) ?? '',
        baseUrl: (j['baseUrl'] as String?) ?? '',
      );
}

class SettingsRepository {
  SettingsRepository(this._prefs);
  final SharedPreferences _prefs;
  static const _key = 'ai_settings_v1';

  AiSettings load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return const AiSettings();
    try {
      return AiSettings.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return const AiSettings();
    }
  }

  Future<void> save(AiSettings s) => _prefs.setString(_key, jsonEncode(s.toJson()));
}
