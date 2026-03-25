import 'package:flutter/material.dart';
import 'package:helpcare/core/app_export.dart';

// ignore: must_be_immutable
class CustomIconButton extends StatelessWidget {
  CustomIconButton(
   
      {super.key, this.shape,
       required this.isDark,
      this.padding,
      this.variant,
      this.alignment,
      this.margin,
      this.height,
      this.width,
      this.child,
      this.onTap});

  IconButtonShape? shape;
  bool isDark;

  IconButtonPadding? padding;

  IconButtonVariant? variant;

  Alignment? alignment;

  EdgeInsetsGeometry? margin;

  double? height;

  double? width;

  Widget? child;

  VoidCallback? onTap;

  @override
    Widget build(BuildContext context) {
    return alignment != null
        ? Align(
            alignment: alignment ?? Alignment.center,
            child: _buildIconButtonWidget(),
          )
        : _buildIconButtonWidget();
  }

  Padding _buildIconButtonWidget() {
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: IconButton(
        constraints: BoxConstraints(
          minHeight: getSize(height ?? 0),
          minWidth: getSize(width ?? 0),
        ),
        padding: const EdgeInsets.all(0),
        icon: Container(
          alignment: Alignment.center,
          width: getSize(width ?? 0),
          height: getSize(height ?? 0),
          padding: _setPadding(),
          decoration: _buildDecoration(),
          child: child,
        ),
        onPressed: onTap,
      ),
    );
  }

  BoxDecoration _buildDecoration() {
    return BoxDecoration(
      color: _setColor(),
      borderRadius: _setBorderRadius(),
    );
  }

  EdgeInsetsGeometry _setPadding() {
    switch (padding) {
      case IconButtonPadding.PaddingAll14:
        return getPadding(
          all: 14,
        );
      case IconButtonPadding.PaddingAll20:
        return getPadding(
          all: 20,
        );
      default:
        return getPadding(
          all: 17,
        );
    }
  }

  Color _setColor() {
    switch (variant) {
      case IconButtonVariant.FillDeeporange50:
        return ColorConstant.deepOrange50;
      case IconButtonVariant.FillLightblue50:
        return ColorConstant.lightBlue50;
      case IconButtonVariant.FillYellow50:
        return ColorConstant.yellow50;
      case IconButtonVariant.FillDeeppurple50:
        return ColorConstant.deepPurple50;
      case IconButtonVariant.FillGreen50:
        return ColorConstant.green50;
      case IconButtonVariant.FillIndigo101:
        return isDark?ColorConstant.darkTextField: ColorConstant.indigo101;
      default:
        return isDark?ColorConstant.darkTextField: ColorConstant.whiteA700;
    }
  }

  BorderRadius _setBorderRadius() {
    switch (shape) {
      case IconButtonShape.CircleBorder30:
        return BorderRadius.circular(
          getHorizontalSize(
            30.00,
          ),
        );
      case IconButtonShape.CircleBorder24:
        return BorderRadius.circular(
          getHorizontalSize(
            24.00,
          ),
        );
      case IconButtonShape.CircleBorder35:
        return BorderRadius.circular(
          getHorizontalSize(
            35.00,
          ),
        );
      default:
        return BorderRadius.circular(
          getHorizontalSize(
            6.00,
          ),
        );
    }
  }
}

enum IconButtonShape {
  RoundedBorder6,
  CircleBorder30,
  CircleBorder24,
  CircleBorder35,
}
enum IconButtonPadding {
  PaddingAll17,
  PaddingAll14,
  PaddingAll20,
}
enum IconButtonVariant {
  FillWhiteA700,
  FillDeeporange50,
  FillLightblue50,
  FillYellow50,
  FillDeeppurple50,
  FillGreen50,
  FillIndigo101,
}
