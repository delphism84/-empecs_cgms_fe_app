import 'package:flutter/material.dart';

class AppHeading extends StatelessWidget {
  final String text;
  final AppHeadingLevel level;
  final EdgeInsetsGeometry? margin;
  const AppHeading(this.text, {super.key, this.level = AppHeadingLevel.h2, this.margin});

  @override
  Widget build(BuildContext context) {
    final TextStyle style = switch (level) {
      AppHeadingLevel.h1 => Theme.of(context).textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w700),
      AppHeadingLevel.h2 => Theme.of(context).textTheme.bodyMedium!.copyWith(fontSize: Theme.of(context).textTheme.bodyMedium!.fontSize! + 3, fontWeight: FontWeight.w700),
      AppHeadingLevel.h3 => Theme.of(context).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w700),
    };
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 6),
      child: Text(text, style: style),
    );
  }
}

enum AppHeadingLevel { h1, h2, h3 }


