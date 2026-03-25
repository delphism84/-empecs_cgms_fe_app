import 'package:flutter/material.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart' as dtp;

class RoundedDropdown<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? hint;

  const RoundedDropdown({super.key, this.value, required this.items, required this.onChanged, this.hint});

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(hintText: hint),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          items: items,
          onChanged: onChanged,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class RoundedRadio<T> extends StatelessWidget {
  final T value;
  final T? groupValue;
  final ValueChanged<T?> onChanged;
  final String label;

  const RoundedRadio({super.key, required this.value, required this.groupValue, required this.onChanged, required this.label});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => onChanged(value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<T>(value: value, groupValue: groupValue, onChanged: onChanged, visualDensity: VisualDensity.compact),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}

class RoundedDatePickerField extends StatelessWidget {
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final String? hint;

  const RoundedDatePickerField({super.key, this.value, required this.onChanged, this.hint});

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: value == null ? '' : _fmt(value!));
    return GestureDetector(
      onTap: () {
        dtp.DatePicker.showDatePicker(
          context,
          theme: dtp.DatePickerTheme(containerHeight: 260, itemStyle: Theme.of(context).textTheme.bodyMedium!),
          onConfirm: (dt) => onChanged(dt),
          currentTime: value ?? DateTime.now(),
          locale: dtp.LocaleType.en,
        );
      },
      child: AbsorbPointer(
        child: TextFormField(
          controller: controller,
          decoration: InputDecoration(hintText: hint ?? 'Select date'),
        ),
      ),
    );
  }

  String _fmt(DateTime dt) => '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}


