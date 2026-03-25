import 'package:flutter/material.dart';
import 'package:helpcare/widgets/rounded_controls.dart';

class AppDropdown<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? hint;
  const AppDropdown({super.key, this.value, required this.items, required this.onChanged, this.hint});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Center(
        child: RoundedDropdown<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          hint: hint,
        ),
      ),
    );
  }
}


