import '../covid_prevention_screen/widgets/listglobe_item_widget.dart';
 import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:helpcare/core/app_export.dart';
import 'package:helpcare/widgets/custom_button.dart';
import 'package:helpcare/widgets/custom_icon_button.dart';

class CovidPreventionScreen extends StatelessWidget {
  const CovidPreventionScreen({super.key});

  @override
    Widget build(BuildContext context) {
    bool isDark =Theme.of(context).brightness==Brightness.dark;
bool isRtl = context.locale==Constants.arLocal;
    return Scaffold(
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
                        left: 24,
                        top: 40,
                        right: 24,
                        bottom: 24,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Container(
                            width: size.width,
                            margin: getMargin(
                              right: 10,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                CustomIconButton(isDark:isDark,
                                  height: 50,
                                  width: 50,
                                  onTap: () {
                                    
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
                                    left: 20,
                                    top: 12,
                                    bottom: 17,
                                  ),
                                  child: Text(
                                    "CGMS Prevention",
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
                              ],
                            ),
                          ),
                          Padding(
                            padding: getPadding(
                              top: 20,
                            ),
                            child: CommonImageView(
                              svgPath: ImageConstant.imgIllustration202X327,
                              height: getVerticalSize(
                                202.00,
                              ),
                              width: getHorizontalSize(
                                327.00,
                              ),
                            ),
                          ),
                          Padding(
                            padding: getPadding(
                              top: 24,
                              right: 10,
                            ),
                            child: Text(
                              "Prevention Tips",
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
                              top: 13,
                              right: 10,
                            ),
                            decoration: BoxDecoration(
                                
                              borderRadius: BorderRadius.circular(
                                getHorizontalSize(
                                  1.00,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: getPadding(
                              top: 13,
                            ),
                            child: ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              shrinkWrap: true,
                              itemCount: 3,
                              itemBuilder: (context, index) {
                                return const ListglobeItemWidget();
                              },
                            ),
                          ),
                          CustomButton(
                            width: 325,
                            text: "Continuous".toUpperCase(),
                            margin: getMargin(
                              left: 1,
                              top: 22,
                              right: 1,
                            ),
                            alignment: Alignment.center,
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
