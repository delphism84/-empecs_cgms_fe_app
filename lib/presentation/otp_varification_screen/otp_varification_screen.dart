 import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:helpcare/core/app_export.dart';
import 'package:helpcare/widgets/custom_button.dart';
import 'package:helpcare/widgets/custom_icon_button.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

class OtpVarificationScreen extends StatelessWidget {
  const OtpVarificationScreen({super.key});

  @override
    Widget build(BuildContext context) {
    bool isDark =Theme.of(context).brightness==Brightness.dark;
bool isRtl = context.locale==Constants.arLocal;
    return Scaffold(
        body: SizedBox(
          width: size.width,
          child: SingleChildScrollView(
            child: Container(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomIconButton(isDark:isDark,
                    height: 50,
                    width: 50,
                    margin: getMargin(
                      left: 24,
                      top: 41,
                      right: 24,
                    ),
                    alignment: Alignment.centerLeft,
                    onTap: () {
                      
                    },
                    child: CommonImageView(
                      isBackBtn: true,
                          isRtl: isRtl,
                         isDark: isDark,
                          svgPath: ImageConstant.imgArrowleft,
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Padding(
                      padding: getPadding(
                        left: 24,
                        top: 30,
                        right: 24,
                      ),
                      child: Text(
                        "Varification Code",
                        overflow: TextOverflow.ellipsis,
                        textAlign:   TextAlign.start,
                        style: TextStyle(
                            
                          fontSize: getFontSize(
                            20,
                          ),
                            fontFamily: 'Gilroy-Medium',
                                fontWeight: FontWeight.bold,
                         
                        ),
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
                      left: 24,
                      top: 18,
                      right: 24,
                    ),
                    decoration: BoxDecoration(
                      color: ColorConstant.bluegray400,
                      borderRadius: BorderRadius.circular(
                        getHorizontalSize(
                          1.00,
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: getHorizontalSize(
                        270.00,
                      ),
                      margin: getMargin(
                        left: 24,
                        top: 25,
                        right: 24,
                      ),
                      child: Text(
                        "We have sent the verification code to your given Number",
                        maxLines: null,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: ColorConstant.bluegray302,
                          fontSize: getFontSize(
                            14,
                          ),
                          fontFamily: 'Gilroy-Medium',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: getPadding(
                      left: 24,
                      top: 43,
                      right: 24,
                    ),
                    child: SizedBox(
                      width: getHorizontalSize(
                        280.00,
                      ),
                      height: getVerticalSize(
                        52.00,
                      ),
                      child: PinCodeTextField(
                        appContext: context,
                        length: 3,
                        obscureText: false,
                        obscuringCharacter: '*',
                        keyboardType: TextInputType.number,
                        autoDismissKeyboard: true,
                        enableActiveFill: true,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (value) {},
                        textStyle: TextStyle(
                            
                          fontSize: getFontSize(
                            20,
                          ),
                            fontFamily: 'Gilroy-Medium',
                                fontWeight: FontWeight.bold,
                         
                        ),
                        pinTheme: PinTheme(
                          fieldWidth: getHorizontalSize(
                            16.00,
                          ),
                          shape: PinCodeFieldShape.underline,
                          selectedFillColor: ColorConstant.deepPurple101,
                          activeFillColor: ColorConstant.deepPurple101,
                          inactiveFillColor: ColorConstant.deepPurple101,
                          inactiveColor: ColorConstant.fromHex("#1212121D"),
                          selectedColor: ColorConstant.fromHex("#1212121D"),
                          activeColor: ColorConstant.fromHex("#1212121D"),
                        ),
                      ),
                    ),
                  ),
                  CustomButton(
                    width: 279,
                    text: "verify".toUpperCase(),
                    margin: getMargin(
                      left: 24,
                      top: 40,
                      right: 24,
                    ),
                    alignment: Alignment.center,
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Padding(
                      padding: getPadding(
                        left: 24,
                        top: 31,
                        right: 24,
                        bottom: 353,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Padding(
                            padding: getPadding(
                              top: 2,
                            ),
                            child: Text(
                              " Didn't Receive Any Code ?",
                              overflow: TextOverflow.ellipsis,
                              textAlign:   TextAlign.start,
                              style: TextStyle(
                                color: ColorConstant.bluegray400,
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
                              bottom: 2,
                            ),
                            child: Text(
                              "Resend",
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
                  ),
                ],
              ),
            ),
          ),
        ),
      
    );
  }
}
