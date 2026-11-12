import 'dart:convert';

import '../../domain/models/credit_models.dart';
import '../../domain/models/goal_models.dart';
import '../../domain/models/simulation_models.dart';
import 'local_storage_adapter.dart';

class LocalRepositories {
  static const String simulationsKey = 'meta_feita_simulations_v1';
  static const String goalsKey = 'meta_feita_goals_v1';
  static const String preferencesKey = 'meta_feita_preferences_v1';
  static const String creditCacheKey = 'meta_feita_credit_cache_v1';
  static const String catalogCacheKey = 'meta_feita_catalog_cache_v1';

  final LocalStorageAdapter storage;

  const LocalRepositories(this.storage);

  List<SavedSimulation> loadSimulations() {
    final raw = storage.getItem(simulationsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map(
            (e) =>
                SavedSimulation.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (_) {
      return [];
    }
  }

  void saveSimulations(List<SavedSimulation> items) {
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    storage.setItem(simulationsKey, encoded);
  }

  List<SavedGoal> loadGoals() {
    final raw = storage.getItem(goalsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => SavedGoal.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (_) {
      return [];
    }
  }

  void saveGoals(List<SavedGoal> items) {
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    storage.setItem(goalsKey, encoded);
  }

  PreferenceModel loadPreferences() {
    final raw = storage.getItem(preferencesKey);
    if (raw == null || raw.isEmpty) return const PreferenceModel();
    try {
      return PreferenceModel.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return const PreferenceModel();
    }
  }

  void savePreferences(PreferenceModel prefs) {
    storage.setItem(preferencesKey, jsonEncode(prefs.toJson()));
  }

  LocalCreditCache loadCreditCache() {
    final raw = storage.getItem(creditCacheKey);
    if (raw == null || raw.isEmpty) {
      return const LocalCreditCache(
        walletReference: '',
        cachedBalance: 0,
        lastValidatedAt: null,
        status: CreditBalanceStatus.uninitialized,
      );
    }
    try {
      return LocalCreditCache.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return const LocalCreditCache(
        walletReference: '',
        cachedBalance: 0,
        lastValidatedAt: null,
        status: CreditBalanceStatus.uninitialized,
      );
    }
  }

  void saveCreditCache(LocalCreditCache cache) {
    storage.setItem(creditCacheKey, jsonEncode(cache.toJson()));
  }

  CreditCatalog? loadCatalogCache() {
    final raw = storage.getItem(catalogCacheKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return CreditCatalog.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  void saveCatalogCache(CreditCatalog catalog) {
    storage.setItem(catalogCacheKey, jsonEncode(catalog.toJson()));
  }

  void clearFinancialData() {
    storage.removeItem(simulationsKey);
    storage.removeItem(goalsKey);
    storage.removeItem(preferencesKey);
  }
}
