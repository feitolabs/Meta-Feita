import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/meta_feita_theme.dart';

enum MfIcon {
  adicionar('adicionar'),
  ajustes('ajustes'),
  alerta('alerta'),
  anuncio('anuncio'),
  aposentadoria('aposentadoria'),
  avancar('avancar'),
  buscar('buscar'),
  calculadora('calculadora'),
  calendario('calendario'),
  comparador('comparador'),
  compartilhar('compartilhar'),
  confirmar('confirmar'),
  creditos('creditos'),
  dividendos('dividendos'),
  editar('editar'),
  excluir('excluir'),
  exportar('exportar'),
  fechar('fechar'),
  historico('historico'),
  inflacao('inflacao'),
  info('info'),
  inicio('inicio'),
  jurosCompostos('juros-compostos'),
  mais('mais'),
  metas('metas'),
  online('online'),
  privacidade('privacidade'),
  reinvestimento('reinvestimento'),
  restaurar('restaurar'),
  retirada('retirada'),
  visualizar('visualizar'),
  voltar('voltar');

  final String assetFile;
  const MfIcon(this.assetFile);
}

class MetaFeitaIcon extends StatelessWidget {
  final MfIcon icon;
  final double size;
  final Color color;

  const MetaFeitaIcon(
    this.icon, {
    super.key,
    this.size = 22,
    this.color = MfColors.petroleo,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/interface/${icon.assetFile}.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}

enum MetaFeitaLogoVariant {
  principalPetroleo('meta-feita-principal-petroleo'),
  claroAreia('meta-feita-claro-areia'),
  campanhaBrasa('meta-feita-campanha-brasa'),
  secundarioAzulRio('meta-feita-secundario-azul-rio'),
  circular('meta-feita-circular');

  final String fileName;
  const MetaFeitaLogoVariant(this.fileName);
}

class MetaFeitaLogo extends StatelessWidget {
  final MetaFeitaLogoVariant variant;
  final double size;

  const MetaFeitaLogo({
    super.key,
    this.variant = MetaFeitaLogoVariant.principalPetroleo,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/app/${variant.fileName}.svg',
      width: size,
      height: size,
    );
  }
}

