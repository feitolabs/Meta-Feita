import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'application/app_controller.dart';
import 'infrastructure/monetization/monetization_api_client.dart';
import 'infrastructure/storage/local_storage_adapter.dart';
import 'ui/navigation/app_shell.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/theme/meta_feita_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController(
    storage: FlutterLocalStorageAdapter(),
    apiClient: HttpMonetizationApiClient(),
  );
  runApp(MetaFeitaApp(controller: controller));
}

class MetaFeitaApp extends StatelessWidget {
  final AppController? controller;
  final bool showSplash;
  final Duration splashDuration;
  final bool autoSyncCredits;

  const MetaFeitaApp({
    super.key,
    this.controller,
    this.showSplash = true,
    this.splashDuration = const Duration(milliseconds: 900),
    this.autoSyncCredits = true,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meta Feita',
      debugShowCheckedModeBanner: false,
      theme: MetaFeitaTheme.build(),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: _AppBootstrapGate(
        controller: controller,
        showSplash: showSplash,
        splashDuration: splashDuration,
        autoSyncCredits: autoSyncCredits,
      ),
    );
  }
}

class _AppBootstrapGate extends StatefulWidget {
  final AppController? controller;
  final bool showSplash;
  final Duration splashDuration;
  final bool autoSyncCredits;

  const _AppBootstrapGate({
    required this.controller,
    required this.showSplash,
    required this.splashDuration,
    required this.autoSyncCredits,
  });

  @override
  State<_AppBootstrapGate> createState() => _AppBootstrapGateState();
}

class _AppBootstrapGateState extends State<_AppBootstrapGate> {
  late final AppController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ??
        AppController(
          storage: FlutterLocalStorageAdapter(),
          apiClient: HttpMonetizationApiClient(),
        );
    _boot();
  }

  Future<void> _boot() async {
    await _controller.loadLocalState();
    if (widget.autoSyncCredits) {
      unawaited(_controller.syncCreditsAndCatalog());
    }

    if (widget.showSplash) {
      await Future<void>.delayed(widget.splashDuration);
    }

    if (mounted) {
      setState(() => _ready = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const SplashScreen();
    }
    return AppShell(controller: _controller);
  }
}
