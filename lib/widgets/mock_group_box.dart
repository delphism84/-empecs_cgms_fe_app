import 'package:flutter/material.dart';
import 'package:helpcare/core/app_export.dart';

class MockGroupBox extends StatelessWidget {
  const MockGroupBox({super.key, required this.title, required this.items});
  final String title;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? ColorConstant.darkTextField : ColorConstant.whiteA700,
        borderRadius: BorderRadius.circular(getHorizontalSize(10)),
        border: Border.all(color: ColorConstant.indigo51, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.build_circle_outlined, size: 18),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: getFontSize(14),
                  fontFamily: 'Gilroy-Medium',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items,
        ],
      ),
    );
  }
}

class MockLine extends StatelessWidget {
  const MockLine(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 16, color: Colors.indigoAccent),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: TextStyle(fontSize: getFontSize(12), fontFamily: 'Gilroy-Medium', color: ColorConstant.bluegray400))),
        ],
      ),
    );
  }
}


