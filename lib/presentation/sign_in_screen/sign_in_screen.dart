import 'package:flutter/material.dart';
import 'package:helpcare/core/app_export.dart';
import 'package:helpcare/widgets/custom_button.dart';
import 'package:helpcare/widgets/custom_switch.dart';
import 'package:helpcare/widgets/custom_text_form_field.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
    Widget build(BuildContext context) {
    bool isDark =Theme.of(context).brightness==Brightness.dark;
    return Scaffold(
        backgroundColor: ColorConstant.gray900,
        body: SizedBox(
          width: size.width,
          child: SingleChildScrollView(
            child: SizedBox(
              height: size.height,
              width: size.width,
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      margin: getMargin(
                        left: 25,
                        top: 40,
                        right: 25,
                        bottom: 40,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Container(
                            width: size.width,
                            margin: getMargin(
                              left: 38,
                              right: 38,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                CommonImageView(
                                  svgPath: ImageConstant.imgLightbulb,
                                  height: getVerticalSize(
                                    87.00,
                                  ),
                                  width: getHorizontalSize(
                                    74.00,
                                  ),
                                ),
                                Container(
                                  width: getHorizontalSize(
                                    128.00,
                                  ),
                                  margin: getMargin(
                                    left: 22,
                                    top: 15,
                                    bottom: 17,
                                  ),
                                  child: Text(
                                    "CGMS\nGlucose Care".toUpperCase(),
                                    maxLines: null,
                                    textAlign:   TextAlign.start,
                                    style: TextStyle(
                                      color: ColorConstant.whiteA700,
                                      fontSize: getFontSize(
                                        24,
                                      ),
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.48,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: getPadding(
                              left: 38,
                              top: 62,
                              right: 38,
                            ),
                            child: Text(
                              "Sign In with CGMS App",
                              overflow: TextOverflow.ellipsis,
                              textAlign:   TextAlign.start,
                              style: TextStyle(
                                color: ColorConstant.whiteA700,
                                fontSize: getFontSize(
                                  20,
                                ),
                                  fontFamily: 'Gilroy-Medium',
                                fontWeight: FontWeight.bold,
                              
                              ),
                            ),
                          ),
                          Container(
                            height: getVerticalSize(
                              2.00,
                            ),
                            width: getHorizontalSize(
                              50.00,
                            ),
                            margin: getMargin(
                              left: 38,
                              top: 16,
                              right: 38,
                            ),
                            decoration: BoxDecoration(
                              color: ColorConstant.bluegray200,
                              borderRadius: BorderRadius.circular(
                                getHorizontalSize(
                                  1.00,
                                ),
                              ),
                            ),
                          ),
                          CustomTextFormField(
    isDark:isDark,
                            width: 325,
                            focusNode: FocusNode(),
                            hintText: "Sign In with Facebook",
                            margin: getMargin(
                              top: 30,
                            ),
                            variant: TextFormFieldVariant.FillBluegray900,
                            padding: TextFormFieldPadding.PaddingT19,
                            fontStyle: TextFormFieldFontStyle.GilroyMedium14,
                            alignment: Alignment.centerLeft,
                            prefix: Container(
                              margin: getMargin(
                                left: 30,
                                top: 17,
                                right: 16,
                                bottom: 11,
                              ),
                              child: CommonImageView(
                                svgPath: ImageConstant.imgFacebook,
                              ),
                            ),
                            prefixConstraints: BoxConstraints(
                              minWidth: getSize(
                                25.00,
                              ),
                              minHeight: getSize(
                                25.00,
                              ),
                            ),
                            suffix: Container(
                              margin: getMargin(
                                left: 30,
                                top: 24,
                                right: 25,
                                bottom: 23,
                              ),
                              child: CommonImageView(
                                svgPath: ImageConstant.imgVectorWhiteA700,
                              ),
                            ),
                            suffixConstraints: BoxConstraints(
                              minWidth: getHorizontalSize(
                                13.00,
                              ),
                              minHeight: getVerticalSize(
                                5.00,
                              ),
                            ),
                          ),
                          Padding(
                            padding: getPadding(
                              left: 38,
                              top: 20,
                              right: 38,
                            ),
                            child: Text(
                              "OR",
                              overflow: TextOverflow.ellipsis,
                              textAlign:   TextAlign.start,
                              style: TextStyle(
                                color: ColorConstant.bluegray300,
                                fontSize: getFontSize(
                                  14,
                                ),
                                fontFamily: 'Gilroy-Medium',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          CustomTextFormField(
    isDark:isDark,
                            width: 325,
                            focusNode: FocusNode(),
                            hintText: "Enter your Email",
                            margin: getMargin(
                              top: 24,
                            ),
                            variant: TextFormFieldVariant.OutlineBluegray200,
                            padding: TextFormFieldPadding.PaddingT19,
                            fontStyle: TextFormFieldFontStyle.GilroyRegular14,
                            alignment: Alignment.centerLeft,
                            suffix: Container(
                              margin: getMargin(
                                left: 30,
                                top: 21,
                                right: 23,
                                bottom: 21,
                              ),
                              child: CommonImageView(
                                svgPath: ImageConstant.imgCheckmark,
                              ),
                            ),
                            suffixConstraints: BoxConstraints(
                              minWidth: getHorizontalSize(
                                15.00,
                              ),
                              minHeight: getVerticalSize(
                                12.00,
                              ),
                            ),
                          ),
                          CustomTextFormField(
    isDark:isDark,
                            width: 325,
                            focusNode: FocusNode(),
                            hintText: "Enter your Password",
                            margin: getMargin(
                              top: 22,
                            ),
                            variant: TextFormFieldVariant.OutlineBluegray200,
                            padding: TextFormFieldPadding.PaddingT19,
                            fontStyle: TextFormFieldFontStyle.GilroyRegular14,
                            textInputAction: TextInputAction.done,
                            alignment: Alignment.centerLeft,
                            suffix: Container(
                              margin: getMargin(
                                left: 30,
                                top: 21,
                                right: 23,
                                bottom: 21,
                              ),
                              child: CommonImageView(
                                svgPath: ImageConstant.imgEye,
                              ),
                            ),
                            suffixConstraints: BoxConstraints(
                              minWidth: getHorizontalSize(
                                14.00,
                              ),
                              minHeight: getVerticalSize(
                                12.00,
                              ),
                            ),
                            isObscureText: true,
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: getPadding(
                                top: 22,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CustomSwitch(
                                        value: true,
                                        onChanged: (value) {},
                                      ),
                                      Padding(
                                        padding: getPadding(
                                          left: 9,
                                          top: 3,
                                          bottom: 1,
                                        ),
                                        child: Text(
                                          "Remember Me",
                                          overflow: TextOverflow.ellipsis,
                                          textAlign:   TextAlign.start,
                                          style: TextStyle(
                                            color: ColorConstant.bluegray200,
                                            fontSize: getFontSize(
                                              14,
                                            ),
                                             fontFamily: 'Gilroy-Medium',
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Padding(
                                    padding: getPadding(
                                      top: 3,
                                      bottom: 1,
                                    ),
                                    child: Text(
                                      "Forget Password ?",
                                      overflow: TextOverflow.ellipsis,
                                      textAlign:   TextAlign.start,
                                      style: TextStyle(
                                        color: ColorConstant.bluegray200,
                                        fontSize: getFontSize(
                                          14,
                                        ),
                                       fontFamily: 'Gilroy-Medium',
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          CustomButton(
                            width: double.infinity,
                            text: "Sign In".toUpperCase(),
                            variant: ButtonVariant.FillLoginGreen,
                            margin: getMargin(
                              top: 39,
                            ),
                            alignment: Alignment.centerLeft,
                          ),
                          Padding(
                            padding: getPadding(
                              left: 38,
                              top: 39,
                              right: 38,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Padding(
                                  padding: getPadding(
                                    top: 1,
                                    bottom: 1,
                                  ),
                                  child: Text(
                                    "Dont’t have Account?",
                                    overflow: TextOverflow.ellipsis,
                                    textAlign:   TextAlign.start,
                                    style: TextStyle(
                                      color: ColorConstant.bluegray200,
                                      fontSize: getFontSize(
                                        14,
                                      ),
                                      fontFamily: 'Gilroy-Medium',
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: getPadding(
                                    left: 7,
                                  ),
                                  child: Text(
                                    "Sign Up",
                                    overflow: TextOverflow.ellipsis,
                                    textAlign:   TextAlign.start,
                                    style: TextStyle(
                                      color: ColorConstant.indigoA700,
                                      fontSize: getFontSize(
                                        14,
                                      ),
                                      fontFamily: 'Gilroy-Medium',
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      
    );
  }
}
