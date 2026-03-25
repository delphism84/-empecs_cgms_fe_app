import 'package:dotted_border/dotted_border.dart';
 import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:helpcare/core/app_export.dart';
import 'package:helpcare/widgets/custom_icon_button.dart';
import 'package:helpcare/widgets/spacing.dart';

class EmergencyHelpCallScreen extends StatelessWidget {
  const EmergencyHelpCallScreen({super.key});

  @override
    Widget build(BuildContext context) {
    bool isDark =Theme.of(context).brightness==Brightness.dark;
bool isRtl = context.locale==Constants.arLocal;
    return Scaffold(
        body: SafeArea(
          child: Container(
            height: size.height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: const Alignment(
                  0.5,
                  -3.0616171314629196e-17,
                ),
                end: const Alignment(
                  0.5,
                  0.9999999999999999,
                ),
                colors: [
                  ColorConstant.indigoA700,
                  ColorConstant.indigo100,
                ],
              ),
            ),
            child: Container(
             
              child: Align(
                alignment: Alignment.topCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
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
                          top: 50,
                          right: 24,
                        ),
                        child: Text(
                          "Emergency Call",
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
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: Padding(
                        padding: getPadding(
                          left: 24,
                          top: 11,
                          right: 24,
                        ),
                        child: Text(
                          "Hospital......",
                          overflow: TextOverflow.ellipsis,
                          textAlign:   TextAlign.start,
                          style: TextStyle(
                            color: ColorConstant.whiteA700,
                            fontSize: getFontSize(
                              12,
                            ),
                            fontFamily: 'Gilroy-Medium',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        
                      
                        margin: getMargin(
                          left: 24,
                          top: 25,
                          right: 24,
                        ),
                         padding: getPadding(
                            left: 10,
                            top: 14,
                            right: 10,
                          ),
                        decoration: BoxDecoration(
                          color:isDark?ColorConstant.darkTextField: ColorConstant.whiteA700,
                         shape: BoxShape.circle
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(100),
                          child: CommonImageView(
                            imagePath:
                                ImageConstant.imgHospital1,
                            height: getSize(
                              86.00,
                            ),
                            width: getSize(
                              86.00,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        height: getVerticalSize(
                          210.00,
                        ),
                        width: getHorizontalSize(
                          306.00,
                        ),
                        margin: getMargin(
                          left: 24,
                          top: 42,
                          right: 24,
                        ),
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            Align(
                              alignment: Alignment.center,
                              child: Container(
                                margin: getMargin(
                                  all: 24,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment
                                              .spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        CustomIconButton(isDark:isDark,
                                          height: 70,
                                          width: 70,
                                          variant: IconButtonVariant
                                              .FillIndigo101,
                                          shape: IconButtonShape
                                              .CircleBorder35,
                                          padding: IconButtonPadding
                                              .PaddingAll20,
                                          child: CommonImageView(
                                            svgPath:
                                                ImageConstant.imgAlarm,
                                          ),
                                        ),
                                        
                                        CustomIconButton(isDark:isDark,
                                          height: 70,
                                          width: 70,
                                          variant: IconButtonVariant
                                              .FillIndigo101,
                                          shape: IconButtonShape
                                              .CircleBorder35,
                                          padding: IconButtonPadding
                                              .PaddingAll20,
                                          child: CommonImageView(
                                            svgPath:
                                                ImageConstant.element,
                                          ),
                                        ),
                                        
                                        CustomIconButton(isDark:isDark,
                                          height: 70,
                                          width: 70,
                                          variant: IconButtonVariant
                                              .FillIndigo101,
                                          shape: IconButtonShape
                                              .CircleBorder35,
                                          padding: IconButtonPadding
                                              .PaddingAll20,
                                          child: CommonImageView(
                                            svgPath:
                                                ImageConstant.imgVolume,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Padding(
                                      padding: getPadding(
                                        top: 22,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment
                                                .spaceBetween,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.max,
                                        children: [
                                          CustomIconButton(isDark:isDark,
                                            height: 70,
                                            width: 70,
                                            variant: IconButtonVariant
                                                .FillIndigo101,
                                            shape: IconButtonShape
                                                .CircleBorder35,
                                            padding: IconButtonPadding
                                                .PaddingAll20,
                                            child: CommonImageView(
                                              svgPath: ImageConstant
                                                  .imgBookmark,
                                            ),
                                          ),
                                          CustomIconButton(isDark:isDark,
                                            height: 70,
                                            width: 70,
                                            variant: IconButtonVariant
                                                .FillIndigo101,
                                            shape: IconButtonShape
                                                .CircleBorder35,
                                            padding: IconButtonPadding
                                                .PaddingAll20,
                                            child: CommonImageView(
                                              svgPath: ImageConstant
                                                  .imgVideoslash,
                                            ),
                                          ),
                                          CustomIconButton(isDark:isDark,
                                            height: 70,
                                            width: 70,
                                            variant: IconButtonVariant
                                                .FillIndigo101,
                                            shape: IconButtonShape
                                                .CircleBorder35,
                                            padding: IconButtonPadding
                                                .PaddingAll20,
                                            child: CommonImageView(
                                              svgPath: ImageConstant
                                                  .imgSearchWhiteA700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: DottedBorder(
                                options: RoundedRectDottedBorderOptions(
                                  radius: const Radius.circular(
                                    8,
                                  ),
                                  padding: EdgeInsets.only(
                                    left: getHorizontalSize(
                                      1.00,
                                    ),
                                    top: getVerticalSize(
                                      1.00,
                                    ),
                                    right: getHorizontalSize(
                                      1.00,
                                    ),
                                    bottom: getVerticalSize(
                                      1.00,
                                    ),
                                  ),
                                  strokeWidth: getHorizontalSize(
                                    1.00,
                                  ),
                                  color: ColorConstant.whiteA700,
                                  dashPattern: const [
                                    10,
                                    10,
                                  ],
                                ),
                                child: Container(
                                  height: getVerticalSize(
                                    210.00,
                                  ),
                                  width: getHorizontalSize(
                                    306.00,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      getHorizontalSize(
                                        8.00,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                     VerticalSpace(height: 70),
                    InkWell(
                      onTap: (){
                        Navigator.pop(context);
                      },
                      child: CommonImageView(
                                              svgPath:
                                                  ImageConstant.endCall,
                                            ),
                    ),
                                          VerticalSpace(height: 12),
                    Align(
                      alignment: Alignment.center,
                      child: Padding(
                        padding: getPadding(
                          left: 24,
                          top: 0,
                          right: 24,
                          bottom: 20,
                        ),
                        child: Text(
                          "End Call",
                          overflow: TextOverflow.ellipsis,
                          textAlign:   TextAlign.start,
                          style: TextStyle(
                            color: ColorConstant.whiteA700,
                            fontSize: getFontSize(
                              12,
                            ),
                            fontFamily: 'Gilroy-Medium',
                            fontWeight: FontWeight.w500,
                          ),
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
