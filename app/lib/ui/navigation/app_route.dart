import '../widgets/meta_feita_icon.dart';

enum AppRoute {
  painel,
  jurosCompostos,
  dividendos,
  reinvestimento,
  metas,
  comparador,
  inflacao,
  retirada,
  aposentadoria,
  historico,
  creditos,
  configuracoes,
  privacidade,
  termos,
}

extension AppRouteMeta on AppRoute {
  String get titlePt => switch (this) {
        AppRoute.painel => 'Painel',
        AppRoute.jurosCompostos => 'Juros compostos',
        AppRoute.dividendos => 'Dividendos',
        AppRoute.reinvestimento => 'Reinvestimento',
        AppRoute.metas => 'Metas',
        AppRoute.comparador => 'Comparador',
        AppRoute.inflacao => 'Inflação',
        AppRoute.retirada => 'Retiradas',
        AppRoute.aposentadoria => 'Aposentadoria',
        AppRoute.historico => 'Histórico',
        AppRoute.creditos => 'Créditos',
        AppRoute.configuracoes => 'Configurações',
        AppRoute.privacidade => 'Privacidade',
        AppRoute.termos => 'Termos de uso',
      };

  MfIcon get icon => switch (this) {
        AppRoute.painel => MfIcon.inicio,
        AppRoute.jurosCompostos => MfIcon.jurosCompostos,
        AppRoute.dividendos => MfIcon.dividendos,
        AppRoute.reinvestimento => MfIcon.reinvestimento,
        AppRoute.metas => MfIcon.metas,
        AppRoute.comparador => MfIcon.comparador,
        AppRoute.inflacao => MfIcon.inflacao,
        AppRoute.retirada => MfIcon.retirada,
        AppRoute.aposentadoria => MfIcon.aposentadoria,
        AppRoute.historico => MfIcon.historico,
        AppRoute.creditos => MfIcon.creditos,
        AppRoute.configuracoes => MfIcon.ajustes,
        AppRoute.privacidade => MfIcon.privacidade,
        AppRoute.termos => MfIcon.info,
      };

  bool get isPrimaryMobileTab =>
      this == AppRoute.painel ||
      this == AppRoute.metas ||
      this == AppRoute.historico ||
      this == AppRoute.creditos;
}

