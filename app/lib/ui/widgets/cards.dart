import 'package:flutter/material.dart';

import '../theme/meta_feita_theme.dart';
import 'meta_feita_icon.dart';

class LightCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final VoidCallback? onTap;

  const LightCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.backgroundColor,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: borderColor ?? MfColors.border, width: 1.1),
    );
    final paddedChild = Padding(padding: padding, child: child);

    return Material(
      color: backgroundColor ?? MfColors.areiaCard,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? paddedChild
          : InkWell(onTap: onTap, customBorder: shape, child: paddedChild),
    );
  }
}

class DarkHighlightCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const DarkHighlightCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: MfColors.petroleo,
        borderRadius: BorderRadius.circular(22),
      ),
      padding: padding,
      child: child,
    );
  }
}

class MfProgressBar extends StatelessWidget {
  final double progress; // 0.0 .. 1.0
  final bool darkSurface;
  final double height;

  const MfProgressBar({
    super.key,
    required this.progress,
    this.darkSurface = false,
    this.height = 10,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    final trackColor = darkSurface
        ? Colors.white.withValues(alpha: 0.14)
        : MfColors.border;
    final fillColor = darkSurface ? MfColors.azulRioClaro : MfColors.azulRio;

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: height,
        width: double.infinity,
        color: trackColor,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: clamped,
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: fillColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AssumptionDisclosure extends StatelessWidget {
  final String title;
  final Map<String, String> assumptions;
  final bool initiallyExpanded;

  const AssumptionDisclosure({
    super.key,
    this.title = 'Premissas usadas',
    required this.assumptions,
    this.initiallyExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    return LightCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 10),
          title: Text(title, style: MfText.tituloCartao),
          iconColor: MfColors.petroleo,
          collapsedIconColor: MfColors.petroleo,
          children: assumptions.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(
                      entry.key,
                      style: MfText.pequeno.copyWith(fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 7,
                    child: Text(
                      entry.value,
                      textAlign: TextAlign.right,
                      style: MfText.rotulo.copyWith(fontSize: 14),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class ProjectionDisclaimer extends StatelessWidget {
  final String? extraNotice;

  const ProjectionDisclaimer({super.key, this.extraNotice});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: MetaFeitaIcon(
              MfIcon.info,
              size: 16,
              color: MfColors.inkMuted,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              extraNotice ??
                  'Resultados são simulações matemáticas com as premissas que você informa. Não são recomendação de investimento nem garantia de rentabilidade.',
              style: MfText.pequeno,
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyStateCard extends StatelessWidget {
  final MfIcon icon;
  final String title;
  final String description;
  final Widget? action;

  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return LightCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: MfColors.nevoaSoft.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: MetaFeitaIcon(icon, size: 26, color: MfColors.petroleo),
          ),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: MfText.tituloCartao),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: MfText.pequeno.copyWith(fontSize: 14),
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

void showFormulaExplanationSheet(
  BuildContext context, {
  required String title,
  required String formula,
  required List<String> rules,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: MfColors.areiaCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(title, style: MfText.subtitulo)),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const MetaFeitaIcon(MfIcon.fechar),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: MfColors.petroleo,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    formula,
                    style: MfText.rotulo.copyWith(
                      color: MfColors.nevoaClaro,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                for (final rule in rules) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 3),
                          child: MetaFeitaIcon(
                            MfIcon.confirmar,
                            size: 16,
                            color: MfColors.petroleo,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            rule,
                            style: MfText.corpo.copyWith(fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}
