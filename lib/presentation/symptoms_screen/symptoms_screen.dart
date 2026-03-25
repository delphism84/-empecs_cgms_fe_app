import 'package:animate_do/animate_do.dart';
import 'package:helpcare/data/covid_symptoms_list.dart';
import 'package:helpcare/presentation/apply_covid_test_screen/apply_covid_test_screen.dart';
import 'package:helpcare/presentation/notification_screen/notification_screen.dart';

import '../symptoms_screen/widgets/gridglobe_item_widget.dart';
 import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:helpcare/core/app_export.dart';
import 'package:helpcare/widgets/custom_button.dart';
import 'package:helpcare/widgets/custom_icon_button.dart';

class SymptomsScreen extends StatelessWidget {
  const SymptomsScreen({super.key});

  @override
    Widget build(BuildContext context) {
    bool isDark =Theme.of(context).brightness==Brightness.dark;
bool isRtl = context.locale==Constants.arLocal;
    return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
                Align(
                        alignment: Alignment.center,
                        child: Container(
                          width: size.width,
                          margin: getMargin(
                            left: 24,
                            right: 24,
                            top: 20,
                            bottom: 10
                          ),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
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
                              CustomIconButton(isDark:isDark,
                                height: 50,
                                width: 50,
                                onTap: (){
                                  Navigator.push(
    context,
    MaterialPageRoute(builder: (context)
 =>const NotificationScreen()),
  );
                                },
                                child: CommonImageView(
                                  isDark: isDark,
                                  svgPath: ImageConstant.imgNotification,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                     
              Expanded(
                child: SingleChildScrollView(
                  child: Align(
                    alignment: Alignment.center,
                    child: Container(
                      margin: getMargin(
                        left: 15,
                        top: 0,
                        right: 24,
                        bottom: 10,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                        
                         
                          Padding(
                            padding: getPadding(
                              left: 10,
                              top: 0,
                              right: 10,
                            ),
                            child: Text(
                              "CGMS Symptoms",
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
                          Padding(
                            padding: getPadding(
                              top: 10,
                            ),
                            child: FadeInDown(
                              child: GridView.builder(
                                shrinkWrap: true,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  mainAxisExtent: getVerticalSize(
                                    173.00,
                                  ),
                                  crossAxisCount: 2,
                                  mainAxisSpacing: getHorizontalSize(
                                    12.00,
                                  ),
                                  crossAxisSpacing: getHorizontalSize(
                                    12.00,
                                  ),
                                ),
                                physics: const BouncingScrollPhysics(),
                                itemCount: covidSymptomsList.length,
                                itemBuilder: (context, index) {
                                  return GridglobeItemWidget(index: index,);
                                },
                              ),
                            ),
                          ),
                          CustomButton(
                            width: 325,
                            text: "Apply for CGMS test".toUpperCase(),
                            margin: getMargin(
                              left: 9,
                              top: 20,
                              right: 2,
                            ),
                            onTap: (){
                              Navigator.push(
    context,
    MaterialPageRoute(builder: (context)
 =>const ApplyCovidTestScreen()),
  );
                            },
                            alignment: Alignment.center,
                          ),
                        ],
                      ),
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
