import 'package:flutter/material.dart';
import 'package:flutter_switch/flutter_switch.dart';
import 'package:helpcare/core/app_export.dart';

// ignore: must_be_immutable
class CustomSwitch extends StatefulWidget {
  CustomSwitch({super.key, this.alignment, this.padding, this.value, this.onChanged});

  Alignment? alignment;

  EdgeInsetsGeometry? padding;

  bool? value;

  Function(bool)? onChanged;

  @override
  State<CustomSwitch> createState() => _CustomSwitchState();
}

class _CustomSwitchState extends State<CustomSwitch> {
  @override
    Widget build(BuildContext context) {
    return widget.alignment != null
        ? Align(
            alignment: widget.alignment ?? Alignment.center,
            child: _buildSwitchWidget(),
          )
        : _buildSwitchWidget();
  }

  Padding _buildSwitchWidget() {
    return Padding(
      padding: widget.padding ?? EdgeInsets.zero,
      child: FlutterSwitch(
        value: widget.value ?? false,
        height: getHorizontalSize(19),
        width: getHorizontalSize(32.3),
        toggleSize: 15.2,
        borderRadius: getHorizontalSize(
          9.50,
        ),
        activeColor: ColorConstant.indigoA700,
        activeToggleColor: ColorConstant.whiteA700,
        inactiveColor: ColorConstant.indigo50,
        inactiveToggleColor: ColorConstant.whiteA700,
        onToggle: (value) {
        },
      ),
    );
  }
}
