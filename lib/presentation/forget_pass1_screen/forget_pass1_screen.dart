 import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:helpcare/core/app_export.dart';
import 'package:helpcare/presentation/forget_pass_screen/forget_pass_screen.dart';
import 'package:helpcare/widgets/custom_button.dart';
import 'package:helpcare/widgets/custom_icon_button.dart';
import 'package:helpcare/widgets/custom_text_form_field.dart';

class ForgetPass1Screen extends StatelessWidget {
  const ForgetPass1Screen({super.key});

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
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  CustomIconButton(isDark:isDark,
                    height: 50,
                    width: 50,
                    margin: getMargin(
                      left: 24,
                      top: 41,
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
                  Align(
                    alignment: Alignment.center,
                    child: Padding(
                      padding: getPadding(
                        left: 24,
                        top: 22,
                        right: 24,
                      ),
                      child: CommonImageView(
                        svgPath: ImageConstant.imgIllustration2,
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
                        top: 65,
                        right: 24,
                      ),
                      child: Text(
                        "Password Recovery",
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
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      height: getVerticalSize(
                        2.00,
                      ),
                      width: getHorizontalSize(
                        50.00,
                      ),
                      margin: getMargin(
                        left: 24,
                        top: 15,
                        right: 24,
                      ),
                      decoration: BoxDecoration(
                        color:isDark?Colors.white: ColorConstant.bluegray400,
                        borderRadius: BorderRadius.circular(
                          getHorizontalSize(
                            1.00,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: getHorizontalSize(
                        244.00,
                      ),
                      margin: getMargin(
                        left: 24,
                        top: 24,
                        right: 24,
                      ),
                      child: Text(
                        "Please enter your email to recieve your password reset instructions",
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
                  CustomTextFormField(
    isDark:isDark,
                    width: 325,
                    focusNode: FocusNode(),
                    hintText: "Enter your Email",
                    margin: getMargin(
                      left: 24,
                      top: 41,
                      right: 24,
                    ),
                    textInputAction: TextInputAction.done,
                    alignment: Alignment.center,
                    suffix: Container(
                      margin: getMargin(
                        left: 30,
                        top: 21,
                        right: 23,
                        bottom: 21,
                      ),
                      child: CommonImageView(
                        svgPath: ImageConstant.imgCheckmark12X15,
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
                  CustomButton(
                    width: 325,
                    text: "Send now".toUpperCase(),
                    margin: getMargin(
                      left: 24,
                      top: 40,
                      right: 24,
                      bottom: 20,
                    ),
                    onTap: (){
                      Navigator.push(
    context,
    MaterialPageRoute(builder: (context)
 =>const ForgetPassScreen()),
  );
                    },
                    alignment: Alignment.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      
    );
  }
}
