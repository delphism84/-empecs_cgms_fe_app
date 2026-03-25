
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:helpcare/core/app_export.dart';
import 'package:helpcare/widgets/custom_button.dart';
import 'package:helpcare/widgets/custom_icon_button.dart';
import 'package:helpcare/widgets/spacing.dart';

class PatientUpdateScreen extends StatelessWidget {
  const PatientUpdateScreen({super.key});

  @override
    Widget build(BuildContext context) {
    bool isDark =Theme.of(context).brightness==Brightness.dark;
bool isRtl = context.locale==Constants.arLocal;
    return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
 Container(
                      width: size.width,
                      margin: getMargin(
                        right: 20,
                        left: 20,
                        top: 20,
                        bottom: 0
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          CustomIconButton(isDark:isDark,
                            height: 50,
                            width: 50,
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
                          Padding(
                            padding: getPadding(
                              left: 0,
                              top: 14,
                              bottom: 15,
                            ),
                            child: Text(
                              "Patient Update",
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
                        HorizontalSpace(width: 50)
                        
                        ],
                      ),
                    ),
                   
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    margin: getMargin(
                      left: 24,
                      top: 10,
                      right: 24,
                      bottom: 10,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                       
                        Container(
                          width: double.infinity,
                          margin: getMargin(
                            top: 0,
                          ),
                          decoration: BoxDecoration(
                            color:isDark?ColorConstant.darkTextField: ColorConstant.whiteA700,
                            borderRadius: BorderRadius.circular(
                              getHorizontalSize(
                                6.00,
                              ),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Padding(
                                padding: getPadding(
                                  left: 22,
                                  top: 14,
                                  right: 22,
                                ),
                                child: Text(
                                  "Patient Name :  Micheal Smith",
                                  overflow: TextOverflow.ellipsis,
                                  textAlign:   TextAlign.start,
                                  style: TextStyle(
                                      
                                    fontSize: getFontSize(
                                      16,
                                    ),
                                    fontFamily: 'Gilroy-Medium',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: getPadding(
                                  left: 22,
                                  top: 17,
                                  right: 22,
                                ),
                                child: Text(
                                  "ID No: Y440028578",
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
                              Container(
                                height: getVerticalSize(
                                  1.00,
                                ),
                                width: getHorizontalSize(
                                  282.00,
                                ),
                                margin: getMargin(
                                  left: 22,
                                  top: 21,
                                  right: 22,
                                ),
                                decoration: BoxDecoration(
                                  color: ColorConstant.gray100,
                                ),
                              ),
                              Align(
                                alignment: Alignment.center,
                                child: Padding(
                                  padding: getPadding(
                                    left: 22,
                                    top: 20,
                                    right: 22,
                                    bottom: 22,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Padding(
                                        padding: getPadding(
                                          top: 12,
                                          bottom: 11,
                                        ),
                                        child: Text(
                                          "CGMS Test Result:",
                                          overflow: TextOverflow.ellipsis,
                                          textAlign:   TextAlign.start,
                                          style: TextStyle(
                                              
                                            fontSize: getFontSize(
                                              14,
                                            ),
                                            fontFamily: 'Gilroy-Medium',
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      CustomButton(
                                        width: 101,
                                        text: "Negative",
                                        variant: ButtonVariant.FillGreen50,
                                        shape: ButtonShape.RoundedBorder4,
                                        padding: ButtonPadding.PaddingAll12,
                                        fontStyle:
                                            ButtonFontStyle.GilroyRegular14,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: getPadding(
                            top: 16,
                            right: 10,
                            bottom: 16
                          ),
                          child: Text(
                            "Medical Provided Report",
                            overflow: TextOverflow.ellipsis,
                            textAlign:   TextAlign.start,
                            style: TextStyle(
                                
                              fontSize: getFontSize(
                                18,
                              ),
                              fontFamily: 'Gilroy-Medium',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.center,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.white,
                              width: 2
                              )
                            ),
                            child: ClipRRect(
                              
                              borderRadius: BorderRadius.circular(
                                getHorizontalSize(
                                  6.00,
                                ),
                              ),
                              child: CommonImageView(
                                imagePath:
                                    ImageConstant.imgTopviewmedica,
                                height: getVerticalSize(
                                  260.00,
                                ),
                                width: getHorizontalSize(
                                  327.00,
                                ),
                              ),
                            ),
                          ),
                        ),
                        CustomButton(
                          width: 325,
                          text: "dOWNLOAD REPORT".toUpperCase(),
                          margin: getMargin(
                            top: 24,
                            right: 2,
                          ),
                          alignment: Alignment.center,
                        ),
                        CustomButton(
                          width: 327,
                          text: "Apply new test".toUpperCase(),
                          margin: getMargin(
                            top: 22,
                          ),
                          variant: ButtonVariant.FillIndigo50,
                          fontStyle: ButtonFontStyle.GilroyMedium16IndigoA700,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      
    );
  }
}
