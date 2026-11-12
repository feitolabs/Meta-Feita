import 'package:flutter/material.dart';

import '../theme/meta_feita_theme.dart';

/// Botão principal da tela. Regra de marca: Brasa aparece no máximo 1x por tela,
/// com texto Petróleo 19 px negrito.
class BrasaPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? leadingIcon;
  final bool fullWidth;
  final bool compactPill;
  final bool isLoading;

  const BrasaPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leadingIcon,
    this.fullWidth = true,
    this.compactPill = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final radius = compactPill ? 999.0 : 18.0;

    final button = Material(
      color: enabled ? MfColors.brasa : MfColors.disabledBg,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          constraints: BoxConstraints(minHeight: compactPill ? 44 : 56),
          padding: EdgeInsets.symmetric(
            horizontal: compactPill ? 18 : 24,
            vertical: compactPill ? 10 : 14,
          ),
          alignment: Alignment.center,
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: MfColors.petroleo,
                  ),
                )
              : Row(
                  mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (leadingIcon != null) ...[
                      leadingIcon!,
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: MfText.bodyFamily,
                          fontWeight: FontWeight.w700,
                          fontSize: compactPill ? 15 : 19,
                          color: enabled
                              ? MfColors.petroleo
                              : MfColors.disabledInk,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class PetroleoDarkButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? leadingIcon;
  final bool fullWidth;
  final bool compact;

  const PetroleoDarkButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leadingIcon,
    this.fullWidth = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final button = Material(
      color: enabled ? MfColors.petroleo : MfColors.disabledBg,
      borderRadius: BorderRadius.circular(compact ? 14 : 18),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(compact ? 14 : 18),
        child: Container(
          constraints: BoxConstraints(minHeight: compact ? 44 : 52),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 16 : 20,
            vertical: compact ? 10 : 13,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leadingIcon != null) ...[
                leadingIcon!,
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: MfText.bodyFamily,
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 14 : 16,
                    color: enabled ? MfColors.areia : MfColors.disabledInk,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class ContornoButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? leadingIcon;
  final bool fullWidth;
  final bool compact;
  final bool lightOnDark;

  const ContornoButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leadingIcon,
    this.fullWidth = true,
    this.compact = false,
    this.lightOnDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = lightOnDark
        ? MfColors.nevoaClaro
        : MfColors.borderStrong;
    final fgColor = lightOnDark ? MfColors.areia : MfColors.petroleo;

    final button = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(compact ? 14 : 18),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(compact ? 14 : 18),
        child: Container(
          constraints: BoxConstraints(minHeight: compact ? 44 : 52),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 14 : 18,
            vertical: compact ? 10 : 12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? 14 : 18),
            border: Border.all(color: borderColor, width: 1.4),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leadingIcon != null) ...[
                leadingIcon!,
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: MfText.bodyFamily,
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 14 : 16,
                    color: fgColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}
