import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:helpcare/core/app_export.dart';
import 'package:helpcare/presentation/home.dart';
import 'package:helpcare/presentation/sign_in_one_screen/sign_in_one_screen.dart';
import 'package:helpcare/widgets/custom_button.dart';
import 'package:helpcare/widgets/custom_text_form_field.dart';

import '../../models/image_tilte_model.dart';
import '../../widgets/spacing.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
   List<ImageTitleModel> dropdownItemList1 = [
    ImageTitleModel(img: ImageConstant.fb, title: "Sign In with Facebook"),
  ];

  Object? value1;
   bool obsecur = true;
  @override
    Widget build(BuildContext context) {
    bool isDark =Theme.of(context).brightness==Brightness.dark;
    return Scaffold(
        body: SafeArea(
          child: SizedBox(
            width: size.width,
            child: SingleChildScrollView(
              child: Container(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: size.width,
                      margin: getMargin(
                        left: 25,
                        top: 20,
                        right: 25,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          CommonImageView(
                            svgPath: ImageConstant.appLogo,
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
                              right: 22,
                              top: 15,
                              bottom: 17,
                            ),
                            child: Text(
                              "CGMS\nGlucose Care".toUpperCase(),
                              maxLines: null,
                              textAlign:   TextAlign.start,
                              style: TextStyle(
                                  
                                fontSize: getFontSize(
                                  24,
                                ),
                                fontFamily: 'Gilroy-Medium',
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.48,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: getPadding(
                        left: 25,
                        top: 30,
                        right: 25,
                      ),
                      child: Text(
                        "Gatting Started ",
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
                    Container(
                      height: getVerticalSize(
                        2.00,
                      ),
                      width: getHorizontalSize(
                        50.00,
                      ),
                      margin: getMargin(
                        left: 25,
                        top: 16,
                        right: 25,
                      ),
                      decoration: BoxDecoration(
                        color: isDark?Colors.white:Colors.black,
                          
                        borderRadius: BorderRadius.circular(
                          getHorizontalSize(
                            1.00,
                          ),
                        ),
                      ),
                    ),
                   Container(
                            margin: getMargin(top: 13),
                            width: getHorizontalSize(325),
                            height: getVerticalSize(56),
                            padding: EdgeInsets.only(
                                left: getHorizontalSize(12),
                                right: getHorizontalSize(12),
                                top: getVerticalSize(15),
                                bottom: getVerticalSize(0)),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? ColorConstant.darkTextField
                                  : ColorConstant.whiteA700,
                                   boxShadow: [
                                          BoxShadow(
                                            color: ColorConstant.gray100,
                                            spreadRadius: getHorizontalSize(
                                             5.00,
                                            ),
                                            blurRadius: getHorizontalSize(
                                              7.00,
                                            ),
                                            offset: const Offset(
                                              0,
                                              3,
                                            ),
                                          ),
                                        ],
                              borderRadius: BorderRadius.circular(
                                getHorizontalSize(
                                  8.00,
                                ),
                              ),
                              border: Border.all(
                                color: ColorConstant.deepPurple100,
                                width: getHorizontalSize(
                                  1.00,
                                ),
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton(
                                autofocus: true,
                                value: value1,
                                isExpanded: true,
                                icon: Container(
                                  child: Padding(
                                    padding: getPadding(bottom: 16),
                                    child: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: isDark
                                          ? Colors.white
                                          : ColorConstant.bluegray400,
                                    ),
                                  ),
                                ),
                                hint: Padding(
                                  padding: getPadding(top: 5),
                                  child: Text(
                                    'Sign in with...',
                                    textAlign: TextAlign.start,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : ColorConstant.bluegray300,
                                      fontSize: getFontSize(
                                        14,
                                      ),
                                      fontFamily: 'Gilroy-Medium',
                                      fontWeight: FontWeight.w500,
                                      height: 1.00,
                                    ),
                                  ),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    value1 = value;
                                  });
                                },
                                items: dropdownItemList1
                                    .map<DropdownMenuItem<ImageTitleModel>>(
                                        (ImageTitleModel value) {
                                  return DropdownMenuItem<ImageTitleModel>(
                                    value: value,
                                    child: Padding(
                                      padding: getPadding(left: 10, right: 10),
                                      child: Row(
                                        children: [
                                          Image.asset(value.img),
                                          HorizontalSpace(width: 14),
                                          Text(
                                            value.title,
                                            textAlign: TextAlign.start,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                                selectedItemBuilder: (BuildContext context) {
                                  return dropdownItemList1
                                      .map((ImageTitleModel value) {
                                    return Padding(
                                      padding: getPadding(bottom: 10),
                                      child: Padding(
                                        padding: getPadding(left: 10, right: 10),
                                        child: Row(
                                          children: [
                                            Image.asset(value.img),
                                            HorizontalSpace(width: 14),
                                            Text(
                                              value.title,
                                              textAlign: TextAlign.start,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList();
                                },
                              ),
                            ),
                          ),
                         
                  
                    Padding(
                      padding: getPadding(
                        left: 25,
                        top: 20,
                        right: 25,
                      ),
                      child: Text(
                        "OR",
                        overflow: TextOverflow.ellipsis,
                        textAlign:   TextAlign.start,
                        style: TextStyle(
                          color: ColorConstant.bluegray400,
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
                        left: 25,
                        top: 24,
                        right: 24,
                      ),
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
                    Container(
                      height: getVerticalSize(
                        56.00,
                      ),
                      width: getHorizontalSize(
                        325.00,
                      ),
                      margin: getMargin(
                        left: 25,
                        top: 22,
                        right: 25,
                      ),
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: getPadding(
                                left: 25,
                                top: 21,
                                right: 25,
                                bottom: 21,
                              ),
                              child: CommonImageView(
                                svgPath: ImageConstant.imgUser,
                                height: getVerticalSize(
                                  13.00,
                                ),
                                width: getHorizontalSize(
                                  11.00,
                                ),
                              ),
                            ),
                          ),
                          CustomTextFormField(
            isDark:isDark,
                            width: 325,
                            focusNode: FocusNode(),
                            hintText: "Enter your Name",
                            alignment: Alignment.centerLeft,
                            suffix: Container(
                              margin: getMargin(
                                left: 30,
                                top: 21,
                                right: 25,
                                bottom: 21,
                              ),
                              child: CommonImageView(
                                svgPath: ImageConstant.imgUser,
                              ),
                            ),
                            suffixConstraints: BoxConstraints(
                              minWidth: getHorizontalSize(
                                11.00,
                              ),
                              minHeight: getVerticalSize(
                                13.00,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    CustomTextFormField(
                     isDark:isDark,
                      width: 325,
                      focusNode: FocusNode(),
                      hintText: "Enter your Password",
                      margin: getMargin(
                        left: 25,
                        top: 22,
                        right: 25,
                      ),
                      variant: TextFormFieldVariant.OutlineDeeppurple101,
                      padding: TextFormFieldPadding.PaddingT19,
                      textInputAction: TextInputAction.done,
                      suffix: GestureDetector(
                              onTap: () {
                                setState(() {
                                  obsecur = !obsecur;
                                });
                              },
                              child: Container(
                                margin: getMargin(
                                  left: 20,
                                  top: 16,
                                  right: 20,
                                  bottom: 16,
                                ),
                                child: SvgPicture.asset(
                                   obsecur
                                      ? ImageConstant.visibilityOff
                                      : ImageConstant.visibilityOn,
                                      color: ColorConstant.bluegray300,
                                      width: getHorizontalSize(20),
                                      height: getVerticalSize(20),
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
                      isObscureText: true,
                    ),
                    CustomButton(
                      width: double.infinity,
                      text: "Sign up".toUpperCase(),
                      variant: ButtonVariant.FillLoginGreen,
                      margin: getMargin(
                        left: 25,
                        top: 40,
                        right: 25,
                      ),
                      onTap: (){
                        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) =>
    const Home()), (Route<dynamic> route) => false);
                      },
                    ),
                    Padding(
                      padding: getPadding(
                        left: 25,
                        top: 39,
                        right: 25,
                        bottom: 59,
                      ),
                      child: InkWell(
                        onTap: (){
                          Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (context)
 =>const SignInOneScreen()),
  );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Padding(
                              padding: getPadding(
                                top: 2,
                                bottom: 1,
                              ),
                              child: Text(
                                "Already have Account?",
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
                            HorizontalSpace(width: 7),
                            Padding(
                              padding: getPadding(
                                left: 0,
                              ),
                              child: Text(
                                "Sign In",
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
