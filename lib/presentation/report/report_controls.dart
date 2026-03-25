import 'package:flutter/material.dart';
import 'package:helpcare/core/app_export.dart';

class ReportRowSwitch extends StatelessWidget {
  const ReportRowSwitch({super.key, required this.icon, required this.label, required this.value, required this.onChanged});
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? ColorConstant.darkTextField : Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
        Switch(value: value, onChanged: onChanged),
      ]),
    );
  }
}

class ReportRowDropdown<T> extends StatelessWidget {
  const ReportRowDropdown({super.key, required this.icon, required this.label, required this.value, required this.items, required this.onChanged});
  final IconData icon;
  final String label;
  final T value;
  final List<T> items;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? ColorConstant.darkTextField : Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
        DropdownButton<T>(
          value: value,
          items: items.map((e) => DropdownMenuItem<T>(value: e, child: Text('$e'))).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ]),
    );
  }
}

class ReportSliderField extends StatelessWidget {
  const ReportSliderField({super.key, required this.icon, required this.label, required this.value, required this.min, required this.max, this.divisions, this.unit, required this.onChanged});
  final IconData icon;
  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String? unit;
  final ValueChanged<double> onChanged;
  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? ColorConstant.darkTextField : Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(unit == null ? value.toStringAsFixed(0) : '${value.toStringAsFixed(0)} ${unit!}', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ),
        ]),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: ColorConstant.green500,
            inactiveTrackColor: ColorConstant.indigo51,
            thumbColor: ColorConstant.green500,
            overlayColor: ColorConstant.green500.withOpacity(0.1),
            trackHeight: 4,
          ),
          child: Slider(value: value, min: min, max: max, divisions: divisions, onChanged: onChanged),
        ),
      ]),
    );
  }
}

class ReportTimeTile extends StatelessWidget {
  const ReportTimeTile({super.key, required this.title, required this.value, required this.onChanged});
  final String title;
  final TimeOfDay value;
  final ValueChanged<TimeOfDay> onChanged;
  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? ColorConstant.darkTextField : Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          final picked = await showTimePicker(context: context, initialTime: value);
          if (picked != null) onChanged(picked);
        },
        child: Row(children: [
          const Icon(Icons.schedule),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
          Text(value.format(context)),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right),
        ]),
      ),
    );
  }
}


