import 'package:flutter/material.dart';
import 'package:helpcare/core/app_export.dart';
import 'package:helpcare/presentation/widgets/app_switch.dart';

class AppSwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const AppSwitchRow({super.key, required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? ColorConstant.darkTextField : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColorConstant.indigo51, width: 1),
        boxShadow: [
          BoxShadow(
            color: ColorConstant.indigo50,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        AppSwitch(value: value, onChanged: onChanged),
      ]),
    );
  }
}

class AppCombo<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final String Function(T) labelFor;
  final ValueChanged<T> onChanged;
  const AppCombo({super.key, required this.label, required this.value, required this.items, required this.labelFor, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? ColorConstant.darkTextField : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColorConstant.indigo51, width: 1),
        boxShadow: [
          BoxShadow(
            color: ColorConstant.indigo50,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        SizedBox(
          height: 36,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isDense: true,
              borderRadius: BorderRadius.circular(10),
              items: items.map((e) => DropdownMenuItem<T>(value: e, child: Text(labelFor(e)))).toList(),
              onChanged: (v) { if (v != null) onChanged(v); },
            ),
          ),
        ),
      ]),
    );
  }
}

class AppSliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String Function(double v)? valueLabel;
  final ValueChanged<double> onChanged;
  const AppSliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    this.valueLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color valueColor = isDark ? Colors.white70 : Colors.black54;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? ColorConstant.darkTextField : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColorConstant.indigo51, width: 1),
        boxShadow: [
          BoxShadow(
            color: ColorConstant.indigo50,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
            Text(
              valueLabel?.call(value) ?? value.toStringAsFixed(0),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: valueColor),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: valueLabel?.call(value) ?? value.toStringAsFixed(0),
            onChanged: onChanged,
          ),
        ),
      ]),
    );
  }
}


