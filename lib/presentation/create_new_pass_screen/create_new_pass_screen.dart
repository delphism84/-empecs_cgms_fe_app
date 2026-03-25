 import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:helpcare/core/app_export.dart';
import 'package:helpcare/presentation/home.dart';
import 'package:helpcare/widgets/custom_button.dart';
import 'package:helpcare/widgets/custom_icon_button.dart';
import 'package:helpcare/widgets/custom_text_form_field.dart';

class CreateNewPassScreen extends StatefulWidget {
  const CreateNewPassScreen({super.key});

  @override
  State<CreateNewPassScreen> createState() => _CreateNewPassScreenState();
}

class _CreateNewPassScreenState extends State<CreateNewPassScreen> {
  bool obsecur1=true;
  bool obsecur2=true;
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
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    Align(
                      alignment: Alignment.center,
                      child: Padding(
                        padding: getPadding(
                          left: 24,
                          top: 22,
                          right: 24,
                        ),
                        child: CommonImageView(
                          svgPath: ImageConstant.imgIllustration190X327,
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
                          top: 51,
                          right: 24,
                        ),
                        child: Text(
                          "Create New Password",
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
                        top: 17,
                        right: 24,
                      ),
                      decoration: BoxDecoration(
                          
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
                          256.00,
                        ),
                        margin: getMargin(
                          left: 24,
                          top: 25,
                          right: 24,
                        ),
                        child: Text(
                          "At least 8 character with uppercase and lowercase letter",
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
                      hintText: "New Password",
                      margin: getMargin(
                        left: 24,
                        top: 40,
                        right: 24,
                      ),
                      variant: TextFormFieldVariant.OutlineDeeppurple101,
                      alignment: Alignment.center,
                      suffix:GestureDetector(
                              onTap: (){
                                setState(() {
                                  obsecur1=!obsecur1;
                                });
                              },
                              child: Container(
                                margin: getMargin(
                                   
                                  left: 30,
                                  top: 16,
                                  right: 26,
                                  bottom: 16,
                                ),
                                child: CommonImageView(
                                  svgPath:obsecur1? ImageConstant.visibilityOff:ImageConstant.visibilityOn,
                                ),
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
                      isObscureText: obsecur1,
                    ),
                    CustomTextFormField(
            isDark:isDark,
                      width: 325,
                      focusNode: FocusNode(),
                      hintText: "Confirm New Password",
                      margin: getMargin(
                        left: 24,
                        top: 22,
                        right: 24,
                      ),
                      variant: TextFormFieldVariant.OutlineDeeppurple101,
                      textInputAction: TextInputAction.done,
                      alignment: Alignment.center,
                      suffix: GestureDetector(
                              onTap: (){
                                setState(() {
                                  obsecur2=!obsecur2;
                                });
                              },
                              child: Container(
                                margin: getMargin(
                                   
                                  left: 30,
                                  top: 16,
                                  right: 26,
                                  bottom: 16,
                                ),
                                child: CommonImageView(
                                  svgPath:obsecur2? ImageConstant.visibilityOff:ImageConstant.visibilityOn,
                                ),
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
                      isObscureText: obsecur2,
                    ),
                    CustomButton(
                      width: 325,
                      text: "Reset Password".toUpperCase(),
                      margin: getMargin(
                        left: 24,
                        top: 40,
                        right: 24,
                        bottom: 20,
                      ),
                      alignment: Alignment.center,
                      onTap: (){
                        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) =>
    const Home()), (Route<dynamic> route) => false);
                      },
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
