import 'package:flutter/material.dart';
import 'package:helpcare/core/app_export.dart';

// ignore: must_be_immutable
class CustomTextFormField extends StatelessWidget {
  CustomTextFormField 
  (
    
      {super.key, this.shape,
      this.padding,
      this.variant,
      required this.isDark,
      this.fontStyle,
      this.alignment,
      this.width,
      this.margin,
      this.controller,
      this.focusNode,
      this.isObscureText = false,
      this.textInputAction = TextInputAction.next,
      this.hintText,
      this.prefix,
      this.prefixConstraints,
      this.suffix,
      this.suffixConstraints,
      this.validator});

  TextFormFieldShape? shape;

  TextFormFieldPadding? padding;
  bool isDark;

  TextFormFieldVariant? variant;

  TextFormFieldFontStyle? fontStyle;

  Alignment? alignment;

  double? width;

  EdgeInsetsGeometry? margin;

  TextEditingController? controller;

  FocusNode? focusNode;

  bool? isObscureText;

  TextInputAction? textInputAction;

  String? hintText;

  Widget? prefix;

  BoxConstraints? prefixConstraints;

  Widget? suffix;

  BoxConstraints? suffixConstraints;

  FormFieldValidator<String>? validator;

  @override
    Widget build(BuildContext context) {
    return alignment != null
        ? Align(
            alignment: alignment ?? Alignment.center,
            child: _buildTextFormFieldWidget(),
          )
        : _buildTextFormFieldWidget();
  }

  Container _buildTextFormFieldWidget() {
    return Container(
      width: getHorizontalSize(width ?? 0),
      margin: margin,
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        style: TextStyle(
         
          fontSize: getFontSize(
            14,
          ),
          fontFamily: 'Gilroy-Medium',
          fontWeight: FontWeight.w500,
        ),
        obscureText: isObscureText!,
        textInputAction: textInputAction,
        decoration: _buildDecoration(),
        validator: validator,
      ),
    );
  }

  InputDecoration _buildDecoration() {
    return InputDecoration(
      hintText: hintText ?? "",
      hintStyle: _setFontStyle(),
      border: _setBorderStyle(),
      enabledBorder: _setBorderStyle(),
      focusedBorder: OutlineInputBorder(
          borderRadius: _setOutlineBorderRadius(),
          borderSide: BorderSide(
            color: ColorConstant.indigoA700,
            width: 1,
          ),
        ),
      disabledBorder: _setBorderStyle(),
      prefixIcon: prefix,
      prefixIconConstraints: prefixConstraints,
      suffixIcon: suffix,
      suffixIconConstraints: suffixConstraints,
      fillColor: _setFillColor(),
      filled: _setFilled(),
      isDense: true,
      contentPadding: _setPadding(),
    );
  }

  TextStyle _setFontStyle() {
    switch (fontStyle) {
      case TextFormFieldFontStyle.GilroyMedium14:
        return TextStyle(
          color: ColorConstant.whiteA700,
          fontSize: getFontSize(
            14,
          ),
          fontFamily: 'Gilroy-Medium',
          fontWeight: FontWeight.w500,
        );
      case TextFormFieldFontStyle.GilroyRegular14:
        return TextStyle(
          color: ColorConstant.bluegray300,
          fontSize: getFontSize(
            14,
          ),
         fontFamily: 'Gilroy-Medium',
          fontWeight: FontWeight.w400,
        );
      case TextFormFieldFontStyle.GilroyMedium14Gray901:
        return TextStyle(
         
          fontSize: getFontSize(
            14,
          ),
          fontFamily: 'Gilroy-Medium',
          fontWeight: FontWeight.w500,
        );
      case TextFormFieldFontStyle.GilroyRegular12:
        return TextStyle(
          color: ColorConstant.indigoA700,
          fontSize: getFontSize(
            12,
          ),
          fontFamily: 'Gilroy-Medium',
          fontWeight: FontWeight.w400,
        );
      case TextFormFieldFontStyle.GilroyMedium14Bluegray400:
        return TextStyle(
          color: ColorConstant.bluegray400,
          fontSize: getFontSize(
            14,
          ),
          fontFamily: 'Gilroy-Medium',
          fontWeight: FontWeight.w500,
        );
      default:
        return TextStyle(
          color: ColorConstant.bluegray301,
          fontSize: getFontSize(
            14,
          ),
          fontFamily: 'Gilroy-Medium',
          fontWeight: FontWeight.w400,
        );
    }
  }

  BorderRadius _setOutlineBorderRadius() {
    switch (shape) {
      case TextFormFieldShape.RoundedBorder4:
        return BorderRadius.circular(
          getHorizontalSize(
            4.00,
          ),
        );
      default:
        return BorderRadius.circular(
          getHorizontalSize(
            8.00,
          ),
        );
    }
  }

  OutlineInputBorder _setBorderStyle() {
    switch (variant) {
      case TextFormFieldVariant.FillBluegray900:
        return OutlineInputBorder(
          borderRadius: _setOutlineBorderRadius(),
          borderSide: BorderSide.none,
        );
      case TextFormFieldVariant.OutlineBluegray200:
        return OutlineInputBorder(
          borderRadius: _setOutlineBorderRadius(),
          borderSide: BorderSide(
            color: ColorConstant.bluegray200,
            width: 1,
          ),
        );
      case TextFormFieldVariant.OutlineDeeppurple101:
        return OutlineInputBorder(
          borderRadius: _setOutlineBorderRadius(),
          borderSide: BorderSide(
            color: ColorConstant.deepPurple101,
            width: 1,
          ),
        );
      case TextFormFieldVariant.OutlineDeeppurple90011:
        return OutlineInputBorder(
          borderRadius: _setOutlineBorderRadius(),
          borderSide: BorderSide.none,
        );
      case TextFormFieldVariant.FillIndigo50:
        return OutlineInputBorder(
          borderRadius: _setOutlineBorderRadius(),
          borderSide: BorderSide.none,
        );
      default:
        return OutlineInputBorder(
          borderRadius: _setOutlineBorderRadius(),
          borderSide: BorderSide(
            color: ColorConstant.deepPurple100,
            width: 1,
          ),
        );
    }
  }

  Color _setFillColor() {
    switch (variant) {
      case TextFormFieldVariant.FillBluegray900:
        return isDark?ColorConstant.darkTextField: ColorConstant.bluegray900;
      case TextFormFieldVariant.OutlineBluegray200:
        return isDark?ColorConstant.darkTextField: ColorConstant.bluegray900;
      case TextFormFieldVariant.OutlineDeeppurple101:
        return isDark?ColorConstant.darkTextField: ColorConstant.whiteA700;
      case TextFormFieldVariant.OutlineDeeppurple90011:
        return isDark?ColorConstant.darkTextField: ColorConstant.whiteA700;
      case TextFormFieldVariant.FillIndigo50:
        return isDark?ColorConstant.darkTextField: ColorConstant.indigo50;
      default:
        return isDark?ColorConstant.darkTextField: ColorConstant.whiteA700;
    }
  }

  bool _setFilled() {
    switch (variant) {
      case TextFormFieldVariant.FillBluegray900:
        return true;
      case TextFormFieldVariant.OutlineBluegray200:
        return true;
      case TextFormFieldVariant.OutlineDeeppurple101:
        return true;
      case TextFormFieldVariant.OutlineDeeppurple90011:
        return true;
      case TextFormFieldVariant.FillIndigo50:
        return true;
      default:
        return true;
    }
  }

  EdgeInsetsGeometry _setPadding() {
    switch (padding) {
      case TextFormFieldPadding.PaddingT19:
        return getPadding(
          left: 18,
          top: 19,
          right: 18,
          bottom: 18,
        );
      case TextFormFieldPadding.PaddingT13:
        return getPadding(
          left: 9,
          top: 13,
          right: 9,
          bottom: 9,
        );
      case TextFormFieldPadding.PaddingT18:
        return getPadding(
          left: 15,
          top: 18,
          right: 15,
          bottom: 15,
        );
      default:
        return getPadding(
          all: 21,
        );
    }
  }
}

enum TextFormFieldShape {
  RoundedBorder8,
  RoundedBorder4,
}
enum TextFormFieldPadding {
  PaddingAll21,
  PaddingT19,
  PaddingT13,
  PaddingT18,
}
enum TextFormFieldVariant {
  OutlineDeeppurple100,
  FillBluegray900,
  OutlineBluegray200,
  OutlineDeeppurple101,
  OutlineDeeppurple90011,
  FillIndigo50,
}
enum TextFormFieldFontStyle {
  GilroyRegular14Bluegray301,
  GilroyMedium14,
  GilroyRegular14,
  GilroyMedium14Gray901,
  GilroyRegular12,
  GilroyMedium14Bluegray400,
}
