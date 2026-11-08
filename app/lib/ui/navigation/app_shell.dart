import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/app_controller.dart';
import '../../domain/models/simulation_models.dart';
import '../screens/aposentadoria_screen.dart';
import '../screens/comparador_screen.dart';
import '../screens/configuracoes_screen.dart';
import '../screens/creditos_screen.dart';
import '../screens/dividendos_screen.dart';
import '../screens/historico_screen.dart';
import '../screens/inflacao_screen.dart';
import '../screens/juros_compostos_screen.dart';
import '../screens/legal_screens.dart';
import '../screens/metas_screen.dart';
import '../screens/painel_screen.dart';
import '../screens/reinvestimento_screen.dart';
import '../screens/retiradas_screen.dart';
import '../theme/meta_feita_theme.dart';
import '../widgets/meta_feita_buttons.dart';
import '../widgets/meta_feita_icon.dart';
import 'app_route.dart';

class AppShell extends StatefulWidget {
  final AppController controller;

  const AppShell({super.key, required this.controller});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const double _desktopBreakpoint = 840;

  AppRoute _currentRoute = AppRoute.painel;
  AppRoute _lastRootTab = AppRoute.painel;
  final Set<AppRoute> _visitedRoutes = {AppRoute.painel};
  final Map<AppRoute, SavedSimulation?> _openedSimulations = {};
  bool _recoveryPromptShowing = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
    if (widget.controller.pendingRecoveryCode != null) {
      _handleControllerChanged();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    final code = widget.controller.pendingRecoveryCode;
    if (code != null && !_recoveryPromptShowing) {
      _recoveryPromptShowing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showRecoveryCodeOnceDialog(code);
      });
    }
  }

  void _navigate(AppRoute route, {SavedSimulation? openSimulation}) {
    setState(() {
      _visitedRoutes.add(route);
      if (openSimulation != null) {
        _openedSimulations[route] = openSimulation;
      }
      if (route.isPrimaryMobileTab) {
        _lastRootTab = route;
      }
      _currentRoute = route;
    });
    widget.controller.trackScreen(route.name);
  }

  void _goBackToRootTab() {
    setState(() {
      _currentRoute = _lastRootTab;
    });
  }

  Future<void> _showRecoveryCodeOnceDialog(String code) async {
    final walletRef = widget.controller.creditCache.walletReference;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('Código de recuperação de créditos', style: MfText.tituloCartao),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sua carteira anônima foi criada. Guarde os dados abaixo: este código é exibido apenas uma vez e permite recuperar seus créditos em outro aparelho.',
              style: MfText.corpo,
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: MfColors.areiaSubtle,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: MfColors.border),
              ),
              child: SelectableText(
                'Carteira: $walletRef\nCódigo: $code',
                style: MfText.rotulo,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(
                ClipboardData(text: 'Carteira: $walletRef | Código: $code'),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Código copiado.')),
              );
            },
            child: const Text('Copiar'),
          ),
          PetroleoDarkButton(
            label: 'Já anotei',
            fullWidth: false,
            compact: true,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
    widget.controller.dismissPendingRecoveryCode();
    _recoveryPromptShowing = false;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= _desktopBreakpoint;
            return PopScope(
              canPop: _currentRoute == _lastRootTab &&
                  _currentRoute == AppRoute.painel,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop) {
                  if (!_currentRoute.isPrimaryMobileTab) {
                    _goBackToRootTab();
                  } else if (_currentRoute != AppRoute.painel) {
                    _navigate(AppRoute.painel);
                  }
                }
              },
              child: isDesktop ? _buildDesktopShell() : _buildMobileShell(),
            );
          },
        );
      },
    );
  }

  Widget _buildDesktopShell() {
    return Scaffold(
      backgroundColor: MfColors.areia,
      body: Column(
        children: [
          _DesktopTopBar(
            controller: widget.controller,
            onTapCredits: () => _navigate(AppRoute.creditos),
            onTapLogo: () => _navigate(AppRoute.painel),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DesktopSidebar(
                  currentRoute: _currentRoute,
                  onSelect: (r) => _navigate(r),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: _buildRouteStack(isDesktop: true),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileShell() {
    final showBottomBar = _currentRoute.isPrimaryMobileTab;
    return Scaffold(
      backgroundColor: MfColors.areia,
      body: SafeArea(
        bottom: !showBottomBar,
        child: _buildRouteStack(isDesktop: false),
      ),
      bottomNavigationBar: showBottomBar
          ? _MobileBottomBar(
              currentRoute: _currentRoute,
              onSelect: (r) => _navigate(r),
            )
          : null,
    );
  }

  Widget _buildRouteStack({required bool isDesktop}) {
    final routes = AppRoute.values;
    final currentIndex = routes.indexOf(_currentRoute);

    return IndexedStack(
      index: currentIndex,
      children: [
        for (final route in routes)
          _visitedRoutes.contains(route)
              ? _buildRouteWidget(route, isDesktop: isDesktop)
              : const SizedBox.shrink(),
      ],
    );
  }

  Widget _buildRouteWidget(AppRoute route, {required bool isDesktop}) {
    final back = isDesktop ? null : _goBackToRootTab;
    return switch (route) {
      AppRoute.painel => PainelScreen(
          controller: widget.controller,
          onNavigate: _navigate,
          isDesktop: isDesktop,
        ),
      AppRoute.jurosCompostos => JurosCompostosScreen(
          controller: widget.controller,
          initialSimulation: _openedSimulations[AppRoute.jurosCompostos],
          onBack: back,
        ),
      AppRoute.dividendos => DividendosScreen(
          controller: widget.controller,
          initialSimulation: _openedSimulations[AppRoute.dividendos],
          onBack: back,
        ),
      AppRoute.reinvestimento => ReinvestimentoScreen(
          controller: widget.controller,
          initialSimulation: _openedSimulations[AppRoute.reinvestimento],
          onBack: back,
        ),
      AppRoute.metas => MetasScreen(controller: widget.controller),
      AppRoute.comparador => ComparadorScreen(
          controller: widget.controller,
          onBack: back,
        ),
      AppRoute.inflacao => InflacaoScreen(
          controller: widget.controller,
          onBack: back,
        ),
      AppRoute.retirada => RetiradasScreen(
          controller: widget.controller,
          onBack: back,
        ),
      AppRoute.aposentadoria => AposentadoriaScreen(
          controller: widget.controller,
          onBack: back,
        ),
      AppRoute.historico => HistoricoScreen(
          controller: widget.controller,
          onNavigate: _navigate,
          onBack: null,
        ),
      AppRoute.creditos => CreditosScreen(
          controller: widget.controller,
          onBack: null,
        ),
      AppRoute.configuracoes => ConfiguracoesScreen(
          controller: widget.controller,
          onNavigate: (r) => _navigate(r),
          onBack: back,
        ),
      AppRoute.privacidade => PrivacidadeScreen(onBack: () {
          setState(() {
            _currentRoute = isDesktop ? AppRoute.painel : AppRoute.configuracoes;
          });
        }),
      AppRoute.termos => TermosScreen(onBack: () {
          setState(() {
            _currentRoute = isDesktop ? AppRoute.painel : AppRoute.configuracoes;
          });
        }),
    };
  }
}

class _DesktopTopBar extends StatelessWidget {
  final AppController controller;
  final VoidCallback onTapCredits;
  final VoidCallback onTapLogo;

  const _DesktopTopBar({
    required this.controller,
    required this.onTapCredits,
    required this.onTapLogo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: MfColors.areiaCard,
        border: Border(bottom: BorderSide(color: MfColors.border)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onTapLogo,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                children: [
                  const MetaFeitaLogo(size: 30),
                  const SizedBox(width: 10),
                  Text('Meta Feita', style: MfText.tituloCartao),
                ],
              ),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: MfColors.areia,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: MfColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: controller.isOnline
                        ? MfColors.azulRio
                        : MfColors.petroleo,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  controller.isOnline ? 'Conectado' : 'Funciona offline',
                  style: MfText.pequeno.copyWith(
                    color: MfColors.petroleo,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: onTapCredits,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: MfColors.areia,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: MfColors.borderStrong),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MetaFeitaIcon(MfIcon.creditos, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '${controller.creditBalance} crédito${controller.creditBalance == 1 ? '' : 's'}',
                    style: MfText.rotulo.copyWith(fontSize: 13.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  final AppRoute currentRoute;
  final ValueChanged<AppRoute> onSelect;

  const _DesktopSidebar({
    required this.currentRoute,
    required this.onSelect,
  });

  static const List<AppRoute> _topItems = [
    AppRoute.painel,
    AppRoute.jurosCompostos,
    AppRoute.dividendos,
    AppRoute.reinvestimento,
    AppRoute.metas,
    AppRoute.comparador,
    AppRoute.inflacao,
    AppRoute.retirada,
    AppRoute.aposentadoria,
  ];

  static const List<AppRoute> _bottomItems = [
    AppRoute.historico,
    AppRoute.creditos,
    AppRoute.configuracoes,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 244,
      decoration: const BoxDecoration(
        color: MfColors.areiaCard,
        border: Border(right: BorderSide(color: MfColors.border)),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        children: [
          for (final route in _topItems)
            _SidebarNavTile(
              route: route,
              selected: currentRoute == route,
              onTap: () => onSelect(route),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Divider(height: 1, color: MfColors.border),
          ),
          for (final route in _bottomItems)
            _SidebarNavTile(
              route: route,
              selected: currentRoute == route ||
                  (route == AppRoute.configuracoes &&
                      (currentRoute == AppRoute.privacidade ||
                          currentRoute == AppRoute.termos)),
              onTap: () => onSelect(route),
            ),
        ],
      ),
    );
  }
}

class _SidebarNavTile extends StatelessWidget {
  final AppRoute route;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarNavTile({
    required this.route,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? MfColors.petroleo : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                MetaFeitaIcon(
                  route.icon,
                  size: 19,
                  color: selected ? MfColors.areia : MfColors.petroleo,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    route.titlePt,
                    style: MfText.rotulo.copyWith(
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? MfColors.areia : MfColors.petroleo,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileBottomBar extends StatelessWidget {
  final AppRoute currentRoute;
  final ValueChanged<AppRoute> onSelect;

  const _MobileBottomBar({
    required this.currentRoute,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    const items = [
      (route: AppRoute.painel, label: 'Início', icon: MfIcon.inicio),
      (route: AppRoute.metas, label: 'Metas', icon: MfIcon.metas),
      (route: AppRoute.historico, label: 'Histórico', icon: MfIcon.historico),
      (route: AppRoute.creditos, label: 'Créditos', icon: MfIcon.creditos),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: MfColors.areiaCard,
        border: Border(top: BorderSide(color: MfColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: items.map((item) {
              final selected = currentRoute == item.route;
              return Expanded(
                child: InkWell(
                  onTap: () => onSelect(item.route),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 56,
                        height: 30,
                        decoration: BoxDecoration(
                          color: selected
                              ? MfColors.petroleo
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        alignment: Alignment.center,
                        child: MetaFeitaIcon(
                          item.icon,
                          size: 20,
                          color:
                              selected ? MfColors.areia : MfColors.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: MfText.pequeno.copyWith(
                          fontSize: 12,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected
                              ? MfColors.petroleo
                              : MfColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
