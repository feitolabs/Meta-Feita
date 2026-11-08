import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/meta_feita_theme.dart';

class MfLabeledField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final String? prefixText;
  final String? suffixText;
  final String? hintText;
  final String? errorText;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  const MfLabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.prefixText,
    this.suffixText,
    this.hintText,
    this.errorText,
    this.keyboardType = const TextInputType.numberWithOptions(decimal: true),
    this.inputFormatters,
    this.onChanged,
  });

  @override
  State<MfLabeledField> createState() => _MfLabeledFieldState();
}

class _MfLabeledFieldState extends State<MfLabeledField> {
  final FocusNode _focusNode = FocusNode();
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) {
        setState(() => _hasFocus = _focusNode.hasFocus);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    final borderColor = hasError
        ? MfColors.erro
        : _hasFocus
            ? MfColors.azulRio
            : MfColors.borderStrong;
    final borderWidth = (_hasFocus || hasError) ? 1.8 : 1.1;

    return Semantics(
      textField: true,
      label: widget.label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label, style: MfText.rotulo),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: hasError ? MfColors.erroSurface : MfColors.areiaCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: borderWidth),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: Row(
              children: [
                if (widget.prefixText != null) ...[
                  Text(
                    widget.prefixText!,
                    style: MfText.corpo.copyWith(
                      color: MfColors.inkMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: TextField(
                    focusNode: _focusNode,
                    controller: widget.controller,
                    keyboardType: widget.keyboardType,
                    inputFormatters: widget.inputFormatters,
                    onChanged: widget.onChanged,
                    style: MfText.corpo.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: MfColors.petroleo,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: widget.hintText,
                      hintStyle: MfText.corpo.copyWith(
                        color: MfColors.inkMuted.withValues(alpha: 0.45),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (widget.suffixText != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    widget.suffixText!,
                    style: MfText.pequeno.copyWith(
                      color: MfColors.inkMuted,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (hasError) ...[
            const SizedBox(height: 6),
            Text(
              widget.errorText!,
              style: MfText.pequeno.copyWith(
                color: MfColors.erro,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class MoneyInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? suffixText;
  final String? hintText;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  const MoneyInput({
    super.key,
    required this.label,
    required this.controller,
    this.suffixText,
    this.hintText = '0,00',
    this.errorText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return MfLabeledField(
      label: label,
      controller: controller,
      prefixText: 'R\$',
      suffixText: suffixText,
      hintText: hintText,
      errorText: errorText,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      ],
      onChanged: onChanged,
    );
  }
}

class PercentageInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String suffixText;
  final String? hintText;
  final String? errorText;
  final bool allowNegative;
  final ValueChanged<String>? onChanged;

  const PercentageInput({
    super.key,
    required this.label,
    required this.controller,
    required this.suffixText,
    this.hintText = '0,0',
    this.errorText,
    this.allowNegative = true,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return MfLabeledField(
      label: label,
      controller: controller,
      suffixText: suffixText,
      hintText: hintText,
      errorText: errorText,
      keyboardType: TextInputType.numberWithOptions(
        decimal: true,
        signed: allowNegative,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          allowNegative ? RegExp(r'[0-9.,-]') : RegExp(r'[0-9.,]'),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

class IntegerInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? suffixText;
  final String? hintText;
  final String? errorText;
  final bool allowDecimal;
  final ValueChanged<String>? onChanged;

  const IntegerInput({
    super.key,
    required this.label,
    required this.controller,
    this.suffixText,
    this.hintText = '0',
    this.errorText,
    this.allowDecimal = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return MfLabeledField(
      label: label,
      controller: controller,
      suffixText: suffixText,
      hintText: hintText,
      errorText: errorText,
      keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          allowDecimal ? RegExp(r'[0-9.,]') : RegExp(r'[0-9]'),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

class SegmentedChoiceOption<T> {
  final T value;
  final String label;

  const SegmentedChoiceOption({required this.value, required this.label});
}

class SegmentedChoice<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<SegmentedChoiceOption<T>> options;
  final ValueChanged<T> onChanged;

  const SegmentedChoice({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: MfText.rotulo),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: MfColors.areiaCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: MfColors.borderStrong, width: 1.1),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: options.map((opt) {
              final selected = opt.value == value;
              return Expanded(
                child: Material(
                  color: selected ? MfColors.petroleo : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  child: InkWell(
                    onTap: () => onChanged(opt.value),
                    borderRadius: BorderRadius.circular(11),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 11,
                      ),
                      child: Text(
                        opt.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: MfText.bodyFamily,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w600,
                          fontSize: 14,
                          color: selected ? MfColors.areia : MfColors.petroleo,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class FrequencySelector<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<SegmentedChoiceOption<T>> options;
  final ValueChanged<T> onChanged;

  const FrequencySelector({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(label, style: MfText.rotulo),
          const SizedBox(height: 10),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final selected = opt.value == value;
            return Material(
              color: selected ? MfColors.petroleo : MfColors.areiaCard,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                onTap: () => onChanged(opt.value),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color:
                          selected ? MfColors.petroleo : MfColors.borderStrong,
                      width: 1.1,
                    ),
                  ),
                  child: Text(
                    opt.label,
                    style: TextStyle(
                      fontFamily: MfText.bodyFamily,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 14,
                      color: selected ? MfColors.areia : MfColors.petroleo,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

