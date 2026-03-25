 import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:helpcare/core/app_export.dart';
import 'package:helpcare/widgets/custom_icon_button.dart';
import 'package:helpcare/widgets/custom_text_form_field.dart';
import 'package:helpcare/widgets/spacing.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

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
                            top: 20
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              CustomIconButton(isDark:isDark,
                                height: 50,
                                width: 50,
                                onTap: (){
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
                                  top: 13,
                                  bottom: 17,
                                ),
                                child: Text(
                                  "Search",
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
                       
              Container(
                margin: getMargin(
                  left: 20,
                  right: 20

                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                   
                   
                    CustomTextFormField(
                     isDark:isDark,
                      width: 327,
                      focusNode: FocusNode(),
                      hintText: "Search here",
                      margin: getMargin(
                        top: 24,
                      ),
                      variant: TextFormFieldVariant.OutlineDeeppurple101,
                      textInputAction: TextInputAction.done,
                      suffix: Container(
                        padding: getPadding(
                          left: 15,
                          top: 11,
                          right: 14,
                          bottom: 11,
                        ),
                        margin: getMargin(
                          left: 10,
                          top: 10,
                          right: 10,
                          bottom: 10,
                        ),
                        decoration: BoxDecoration(
                          color: ColorConstant.indigoA700,
                          borderRadius: BorderRadius.circular(
                            getHorizontalSize(
                              4.00,
                            ),
                          ),
                        ),
                        child: CommonImageView(
                          svgPath: ImageConstant.imgSearch,
                        ),
                      ),
                      suffixConstraints: BoxConstraints(
                        minWidth: getHorizontalSize(
                          13.00,
                        ),
                        minHeight: getVerticalSize(
                          13.00,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Padding(
                          padding: getPadding(
                            top: 32,
                            right:20 ,
                            left: 20
                          ),
                          child: Text(
                            "Suggested Keywords",
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
                      ],
                    ),
                    Padding(
                      padding: getPadding(
                        top: 19,
                        right: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Container(
                            padding: getPadding(
                              left: 21,
                              top: 16,
                              right: 21,
                              bottom: 17,
                            ),
                            decoration: BoxDecoration(
                              color: ColorConstant.indigo50,
                              borderRadius: BorderRadius.circular(
                                getHorizontalSize(
                                  4.00,
                                ),
                              ),
                            ),
                            child: Text(
                              "Doctors",
                              overflow: TextOverflow.ellipsis,
                              textAlign:   TextAlign.start,
                              style: TextStyle(
                                color: ColorConstant.indigoA700,
                                fontSize: getFontSize(
                                  12,
                                ),
                                fontFamily: 'Gilroy-Medium',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          HorizontalSpace(width: 14),
                          Container(
                            margin: getMargin(
                              left: 0,
                            ),
                            padding: getPadding(
                              left: 21,
                              top: 18,
                              right: 20,
                              bottom: 14,
                            ),
                            decoration: BoxDecoration(
                              color: ColorConstant.indigo50,
                              borderRadius: BorderRadius.circular(
                                getHorizontalSize(
                                  4.00,
                                ),
                              ),
                            ),
                            child: Text(
                              "Hospitals",
                              overflow: TextOverflow.ellipsis,
                              textAlign:   TextAlign.start,
                              style: TextStyle(
                                color: ColorConstant.indigoA700,
                                fontSize: getFontSize(
                                  12,
                                ),
                                fontFamily: 'Gilroy-Medium',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                         HorizontalSpace(width: 14),
                          Container(
                            margin: getMargin(
                              left: 0,
                            ),
                            padding: getPadding(
                              left: 19,
                              top: 16,
                              right: 18,
                              bottom: 17,
                            ),
                            decoration: BoxDecoration(
                              color: ColorConstant.indigo50,
                              borderRadius: BorderRadius.circular(
                                getHorizontalSize(
                                  4.00,
                                ),
                              ),
                            ),
                            child: Text(
                              "CGMS Test",
                              overflow: TextOverflow.ellipsis,
                              textAlign:   TextAlign.start,
                              style: TextStyle(
                                color: ColorConstant.indigoA700,
                                fontSize: getFontSize(
                                  12,
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
            ],
          ),
        ),
      
    );
  }
}
