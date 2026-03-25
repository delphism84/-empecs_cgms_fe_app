 import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:helpcare/core/app_export.dart';
import 'package:helpcare/presentation/create_new_pass_screen/create_new_pass_screen.dart';
import 'package:helpcare/widgets/custom_button.dart';
import 'package:helpcare/widgets/custom_icon_button.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

class ForgetPassScreen extends StatelessWidget {
  const ForgetPassScreen({super.key});

  @override
    Widget build(BuildContext context) {
    bool isDark =Theme.of(context).brightness==Brightness.dark;
bool isRtl = context.locale==Constants.arLocal;
    return Scaffold(
        body: SafeArea(
          child: SizedBox(
            width: size.width,
            child: SingleChildScrollView(
              child: Container(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        CustomIconButton(isDark:isDark,
                          height: 50,
                          width: 50,
                          margin: getMargin(
                            left: 24,
                            top: 20,
                            right: 24,
                          ),
                          
                          onTap: () {
                            Navigator.pop(context);
                            
                          },
                          child: CommonImageView(
                            isBackBtn: true,
                                isRtl: isRtl,
                               isDark: isDark,
                                svgPath: ImageConstant.imgArrowleft,
                          ),
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: Padding(
                        padding: getPadding(
                          left: 24,
                          top: 22,
                          right: 24,
                        ),
                        child: CommonImageView(
                          svgPath: ImageConstant.imgIllustration1,
                          height: getVerticalSize(
                            190.00,
                          ),
                          width: getHorizontalSize(
                            327.00,
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: Padding(
                        padding: getPadding(
                          left: 24,
                          top: 62,
                          right: 24,
                        ),
                        child: Text(
                          "Varification",
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
                        color:isDark?ColorConstant.whiteA700: ColorConstant.bluegray400,
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
                          271.00,
                        ),
                        margin: getMargin(
                          left: 24,
                          top: 25,
                          right: 24,
                        ),
                        child: Text(
                          "Enter the verification code we just sent you on your email address",
                          maxLines: null,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: ColorConstant.bluegray302,
                            fontSize: getFontSize(
                              14,
                            ),
                             fontFamily: 'Gilroy-Medium',
                                fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: getPadding(
                        left: 24,
                        top: 42,
                        right: 24,
                      ),
                      child: SizedBox(
                        width: getHorizontalSize(
                          280.00,
                        ),
                        height: getVerticalSize(
                          53.00,
                        ),
                        child: PinCodeTextField(
                          appContext: context,
                          backgroundColor: Colors.transparent,
                          length: 4,
                          obscureText: false,
                          obscuringCharacter: '*',
                          
                          keyboardType: TextInputType.number,
                          autoDismissKeyboard: true,
                          
                          enableActiveFill: true,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (value) {},
                          pinTheme: PinTheme(
                            fieldWidth: getHorizontalSize(
                              52.00,
                            ),
                            fieldHeight: getVerticalSize(52),
                            borderRadius: BorderRadius.circular(8),
                            
                            
                            shape: PinCodeFieldShape.box,
                            selectedFillColor: isDark? ColorConstant.darkTextField:Colors.white,
                            activeFillColor:isDark? ColorConstant.darkTextField:Colors.white,
                            inactiveFillColor: isDark? ColorConstant.darkTextField:Colors.white,
                            inactiveColor: ColorConstant.deepPurple101,
                            selectedColor: ColorConstant.indigoA700,
                            activeColor: ColorConstant.deepPurple101,
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
                      onTap: (){
                        Navigator.push(
    context,
    MaterialPageRoute(builder: (context)
 =>const CreateNewPassScreen()),
  );
                      },
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: Padding(
                        padding: getPadding(
                          left: 24,
                          top: 31,
                          right: 24,
                          bottom: 109,
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
        ),
      
    );
  }
}
