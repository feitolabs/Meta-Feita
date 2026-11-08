import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/models/credit_models.dart';
import '../../domain/models/goal_models.dart';
import '../../domain/models/simulation_models.dart';
import '../../domain/rules/backup_validator.dart';

class BackupService {
  static String buildBackupJson({
    required List<SavedSimulation> simulations,
    required List<SavedGoal> goals,
    required PreferenceModel preferences,
  }) {
    final payload = BackupPayload(
      app: 'Meta Feita',
      schemaVersion: BackupPayload.supportedSchemaVersion,
      exportedAt: DateTime.now().toUtc(),
      simulations: simulations,
      goals: goals,
      preferences: preferences,
    );
    return payload.toPrettyJson();
  }

  static Future<void> exportAndShare({
    required List<SavedSimulation> simulations,
    required List<SavedGoal> goals,
    required PreferenceModel preferences,
  }) async {
    final jsonContent = buildBackupJson(
      simulations: simulations,
      goals: goals,
      preferences: preferences,
    );
    final fileName =
        'meta-feita-backup-${DateTime.now().toIso8601String().substring(0, 10)}.json';

    if (kIsWeb) {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              utf8.encode(jsonContent),
              mimeType: 'application/json',
              name: fileName,
            ),
          ],
          subject: 'Backup Meta Feita',
        ),
      );
      return;
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(jsonContent, encoding: utf8);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json', name: fileName)],
        subject: 'Backup Meta Feita',
      ),
    );
  }

  static Future<BackupPayload?> pickAndValidateBackupFile() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Selecionar arquivo de backup (.json)',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    final rawContent = utf8.decode(bytes);
    return BackupValidator.parseAndValidate(rawContent);
  }
}
