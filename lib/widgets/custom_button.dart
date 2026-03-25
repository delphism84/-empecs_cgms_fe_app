import 'package:flutter/material.dart';
import 'package:helpcare/core/app_export.dart';

// ignore: must_be_immutable
class CustomButton extends StatelessWidget {
  CustomButton(
      {super.key, this.shape,
      this.padding,
      this.variant,
      this.fontStyle,
      this.alignment,
      this.onTap,
      this.width,
      this.margin,
      this.text});

  ButtonShape? shape;

  ButtonPadding? padding;

  ButtonVariant? variant;

  ButtonFontStyle? fontStyle;

  Alignment? alignment;

  VoidCallback? onTap;

  double? width;

  EdgeInsetsGeometry? margin;

  String? text;

  @override
    Widget build(BuildContext context) {
    return alignment != null
        ? Align(
            alignment: alignment ?? Alignment.center,
            child: _buildButtonWidget(),
          )
        : _buildButtonWidget();
  }

  GestureDetector _buildButtonWidget() {
    return GestureDetector(
      onTap: onTap,
      child: Container(
         decoration: _buildDecoration(),
    margin: margin,
      padding: _setPadding(),
        width: width != null ? getHorizontalSize(width!) : null,
         child: Text(
          text ?? "",
          textAlign: TextAlign.center,
          style: _setFontStyle(),
        ),
      ),
    );
  }

  BoxDecoration _buildDecoration() {
    return BoxDecoration(
      color: _setColor(),
      borderRadius: _setBorderRadius(),
      border: _setBorder(),
      boxShadow: _setBoxShadow(),
    );
  }

  EdgeInsetsGeometry _setPadding() {
    switch (padding) {
      case ButtonPadding.PaddingAll14:
        return getPadding(
          all: 14,
        );
      case ButtonPadding.PaddingAll12:
        return getPadding(
          all: 12,
        );
      default:
        return getPadding(
          all: 20,
        );
    }
  }

  Color _setColor() {
    switch (variant) {
      case ButtonVariant.FillIndigo50:
        return ColorConstant.indigo50;
      case ButtonVariant.FillIndigoA700:
        return ColorConstant.indigoA700;
      case ButtonVariant.FillWhiteA700:
        return ColorConstant.whiteA700;
      case ButtonVariant.FillGreen50:
        return ColorConstant.green50;
      case ButtonVariant.FillLoginGreen:
        return ColorConstant.loginGreen;
      case ButtonVariant.FillLoginGreenFlat:
        return ColorConstant.loginGreen;
      case ButtonVariant.OutlinePrimaryWhite:
        return ColorConstant.whiteA700;
      default:
        return ColorConstant.baseColor;
    }
  }

  BoxBorder? _setBorder() {
    switch (variant) {
      case ButtonVariant.OutlinePrimaryWhite:
        return Border.all(color: ColorConstant.baseColor, width: 1);
      default:
        return null;
    }
  }

  BorderRadius _setBorderRadius() {
    switch (shape) {
      case ButtonShape.RoundedBorder4:
        return BorderRadius.circular(
          getHorizontalSize(
            4.00,
          ),
        );
      case ButtonShape.Square:
        return BorderRadius.circular(0);
      default:
        return BorderRadius.circular(
          getHorizontalSize(
            8.00,
          ),
        );
    }
  }

  List<BoxShadow>? _setBoxShadow() {
    switch (variant) {
      case ButtonVariant.FillIndigo50:
      
      case ButtonVariant.FillIndigoA700:
        // return  [
        //                                   BoxShadow(
        //                                     color: ColorConstant.indigo50,
        //                                     spreadRadius: getHorizontalSize(
        //                                      15.00,
        //                                     ),
        //                                     blurRadius: getHorizontalSize(
        //                                       8.00,
        //                                     ),
        //                                     offset: Offset(
        //                                       0,
        //                                       5,
        //                                     ),
        //                                   ),
        //                                 ];
      
      case ButtonVariant.FillWhiteA700:
      case ButtonVariant.FillGreen50:
      case ButtonVariant.FillLoginGreenFlat:
        return null;
      default:
        return [
          BoxShadow(
            color: ColorConstant.indigo50,
            spreadRadius: getHorizontalSize(0.00),
            blurRadius: getHorizontalSize(2.00),
            offset: const Offset(0, 1),
          ),
        ];
    }
  }

  TextStyle _setFontStyle() {
    switch (fontStyle) {
      case ButtonFontStyle.GilroyMedium12:
        return TextStyle(
          color: ColorConstant.baseColor,
          fontSize: getFontSize(
            12,
          ),
          fontFamily: 'Gilroy-Medium',
          fontWeight: FontWeight.w500,
        );
      case ButtonFontStyle.GilroyMedium12WhiteA700:
        return TextStyle(
          color: ColorConstant.whiteA700,
          fontSize: getFontSize(
            12,
          ),
          fontFamily: 'Gilroy-Medium',
          fontWeight: FontWeight.w500,
        );
      case ButtonFontStyle.GilroyRegular14:
        return TextStyle(
          color: ColorConstant.green500,
          fontSize: getFontSize(
            14,
          ),
        fontFamily: 'Gilroy-Medium',
          fontWeight: FontWeight.w400,
        );
      case ButtonFontStyle.GilroyMedium16IndigoA700:
        return TextStyle(
          color: ColorConstant.indigoA700,
          fontSize: getFontSize(
            16,
          ),
          fontFamily: 'Gilroy-Medium',
          fontWeight: FontWeight.w500,
        );
      case ButtonFontStyle.GilroyMedium16LoginGreen:
        return TextStyle(
          color: ColorConstant.loginGreen,
          fontSize: getFontSize(
            16,
          ),
          fontFamily: 'Gilroy-Medium',
          fontWeight: FontWeight.w500,
        );
      case ButtonFontStyle.GilroyMedium16Primary:
        return TextStyle(
          color: ColorConstant.baseColor,
          fontSize: getFontSize(
            16,
          ),
          fontFamily: 'Gilroy-Medium',
          fontWeight: FontWeight.w500,
        );
      default:
        return TextStyle(
          color: ColorConstant.whiteA700,
          fontSize: getFontSize(
            16,
          ),
          fontFamily: 'Gilroy-Medium',
          fontWeight: FontWeight.w500,
        );
    }
  }
}

enum ButtonShape {
  Square,
  RoundedBorder8,
  RoundedBorder4,
}
enum ButtonPadding {
  PaddingAll20,
  PaddingAll12,
  PaddingAll14,
}
enum ButtonVariant {
  OutlineDeeppurple9002b,
  FillIndigo50,
  FillIndigoA700,
  FillWhiteA700,
  FillGreen50,
  FillLoginGreen,
  FillLoginGreenFlat,
  OutlinePrimaryWhite,
}
enum ButtonFontStyle {
  GilroyMedium16,
  GilroyMedium12,
  GilroyMedium12WhiteA700,
  GilroyRegular14,
  GilroyMedium16IndigoA700,
  GilroyMedium16LoginGreen,
  GilroyMedium16Primary,
}
