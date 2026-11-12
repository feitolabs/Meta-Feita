import 'dart:convert';

import '../models/credit_models.dart';
import '../models/goal_models.dart';
import '../models/simulation_models.dart';

class BackupPayload {
  static const int supportedSchemaVersion = 1;
  static const int maxBytes = 5 * 1024 * 1024; // 5 MB

  final String app;
  final int schemaVersion;
  final DateTime exportedAt;
  final List<SavedSimulation> simulations;
  final List<SavedGoal> goals;
  final PreferenceModel preferences;

  const BackupPayload({
    required this.app,
    required this.schemaVersion,
    required this.exportedAt,
    required this.simulations,
    required this.goals,
    required this.preferences,
  });

  String toPrettyJson() {
    final map = {
      'app': app,
      'schemaVersion': schemaVersion,
      'exportedAt': exportedAt.toIso8601String(),
      'notice':
          'Créditos, transações de compra e tokens de pagamento não são incluídos nem restaurados por este backup.',
      'simulations': simulations.map((e) => e.toJson()).toList(),
      'goals': goals.map((e) => e.toJson()).toList(),
      'preferences': preferences.toJson(),
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }
}

class BackupValidationException implements Exception {
  final String message;
  const BackupValidationException(this.message);

  @override
  String toString() => message;
}

class BackupValidator {
  static const Set<String> _forbiddenKeys = {
    'token',
    'password',
    'secret',
    'creditBalance',
    'credits',
    'recoveryCode',
    'paymentToken',
    'purchaseToken',
  };

  static BackupPayload parseAndValidate(String rawJson) {
    if (utf8.encode(rawJson).length > BackupPayload.maxBytes) {
      throw const BackupValidationException(
        'O arquivo de backup excede o limite de 5 MB.',
      );
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(rawJson);
    } catch (_) {
      throw const BackupValidationException(
        'Arquivo inválido: o conteúdo não é um JSON válido.',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const BackupValidationException('Estrutura de backup inválida.');
    }

    for (final key in decoded.keys) {
      if (_forbiddenKeys.contains(key)) {
        throw BackupValidationException(
          'Arquivo rejeitado por conter campo proibido ($key). Créditos e credenciais não pertencem ao backup.',
        );
      }
    }

    final app = decoded['app'];
    if (app != 'Meta Feita') {
      throw const BackupValidationException(
        'Este arquivo não pertence ao aplicativo Meta Feita.',
      );
    }

    final version = decoded['schemaVersion'];
    if (version is! int ||
        version < 1 ||
        version > BackupPayload.supportedSchemaVersion) {
      throw const BackupValidationException(
        'Versão do arquivo de backup não suportada.',
      );
    }

    final exportedAtRaw = decoded['exportedAt'];
    final exportedAt = exportedAtRaw is String
        ? DateTime.tryParse(exportedAtRaw)
        : null;
    if (exportedAt == null) {
      throw const BackupValidationException(
        'Data de exportação ausente ou inválida no backup.',
      );
    }

    final rawSims = decoded['simulations'];
    final rawGoals = decoded['goals'];
    if (rawSims is! List || rawGoals is! List) {
      throw const BackupValidationException(
        'Listas de simulações ou metas ausentes no backup.',
      );
    }

    try {
      final sims = rawSims
          .map(
            (e) =>
                SavedSimulation.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
      final goals = rawGoals
          .map((e) => SavedGoal.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final prefsMap = decoded['preferences'] is Map
          ? Map<String, dynamic>.from(decoded['preferences'] as Map)
          : <String, dynamic>{};
      final prefs = PreferenceModel.fromJson(prefsMap);

      return BackupPayload(
        app: app as String,
        schemaVersion: version,
        exportedAt: exportedAt,
        simulations: sims,
        goals: goals,
        preferences: prefs,
      );
    } catch (e) {
      throw BackupValidationException(
        'Falha ao validar registros do backup: ${e.toString()}',
      );
    }
  }
}
