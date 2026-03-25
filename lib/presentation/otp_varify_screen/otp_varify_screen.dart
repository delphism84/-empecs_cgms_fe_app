 import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:helpcare/core/app_export.dart';
import 'package:helpcare/widgets/custom_button.dart';
import 'package:helpcare/widgets/custom_icon_button.dart';
import 'package:helpcare/widgets/custom_text_form_field.dart';

class OtpVarifyScreen extends StatelessWidget {
  const OtpVarifyScreen({super.key});

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
                        svgPath: ImageConstant.imgIllustration,
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
                        280.00,
                      ),
                      margin: getMargin(
                        left: 24,
                        top: 24,
                        right: 24,
                      ),
                      child: Text(
                        "We will send you one time password on your phone number",
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
                    hintText: "Enter your Phone Number",
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
                        top: 20,
                        right: 23,
                        bottom: 20,
                      ),
                      child: CommonImageView(
                        svgPath: ImageConstant.imgVectorBluegray400,
                      ),
                    ),
                    suffixConstraints: BoxConstraints(
                      minWidth: getHorizontalSize(
                        14.00,
                      ),
                      minHeight: getVerticalSize(
                        15.00,
                      ),
                    ),
                  ),
                  CustomButton(
                    width: 325,
                    text: "Get OTP".toUpperCase(),
                    margin: getMargin(
                      left: 24,
                      top: 40,
                      right: 24,
                      bottom: 20,
                    ),
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
