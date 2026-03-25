import 'package:animate_do/animate_do.dart';
import 'package:helpcare/data/services_lits.dart';
import 'package:helpcare/presentation/doctors_list_screen/doctors_list_screen.dart';
import 'package:helpcare/presentation/emergency_help_call_screen/emergency_help_call_screen.dart';
import 'package:helpcare/presentation/notification_screen/notification_screen.dart';
import 'package:helpcare/presentation/search_screen/search_screen.dart';
import 'package:helpcare/widgets/spacing.dart';

import '../home_page_screen/widgets/gridcut_item_widget.dart';
import 'package:flutter/material.dart';
import 'package:helpcare/core/app_export.dart';
import 'package:helpcare/widgets/custom_button.dart';
import 'package:helpcare/widgets/custom_icon_button.dart';

class HomePageScreen extends StatelessWidget {
  const HomePageScreen({super.key});

  @override
    Widget build(BuildContext context) {
    bool isDark =Theme.of(context).brightness==Brightness.dark;
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
                    bottom: 14
                  ),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Padding(
                        padding: getPadding(
                          top: 4,
                          bottom: 5,
                        ),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CommonImageView(
                              svgPath: ImageConstant.appLogo,
                              height: getVerticalSize(
                                41.00,
                              ),
                              width: getHorizontalSize(
                                34.00,
                              ),
                            ),
                            Padding(
                              padding: getPadding(
                                left: 8,
                                right: 8,
                                top: 13,
                                bottom: 9,
                              ),
                              child: Text(
                                "CGMS".toUpperCase(),
                                overflow: TextOverflow.ellipsis,
                                textAlign:   TextAlign.start,
                                style: TextStyle(
                                  
                                  fontSize: getFontSize(
                                    18,
                                  ),
                                  fontFamily: 'Gilroy-Medium',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CustomIconButton(isDark:isDark,
                            height: 50,
                            width: 50,
                            onTap: (){
                              Navigator.push(
    context,
    MaterialPageRoute(builder: (context)
 =>const SearchScreen()),
  );
                            },
                            child: CommonImageView(
                              isDark: isDark,
                              svgPath: ImageConstant
                                  .imgSearchBluegray400,
                            ),
                          ),
                         HorizontalSpace(width: 16),
                         
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
                            margin: getMargin(
                              left: 0,
                            ),
                            child: CommonImageView(
                              isDark: isDark,
                              svgPath:
                                  ImageConstant.imgNotification,
                            ),
                          ),
                        ],
                      ),
                    
                    
                    ],
                  ),
                ),
              ),
              
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                  
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: double.infinity,
                        margin: getMargin(
                          left: 24,
                          top: 0,
                          right: 24,
                        ),
                        decoration: BoxDecoration(
                          color:isDark?ColorConstant.darkTextField: ColorConstant.indigo50,
                          borderRadius: BorderRadius.circular(
                            getHorizontalSize(
                              10.00,
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
                                left: 24,
                                top: 30,
                                right: 24,
                              ),
                              child: Text(
                                "Emergency",
                                overflow: TextOverflow.ellipsis,
                                textAlign:   TextAlign.start,
                                style: TextStyle(
                                  color: ColorConstant.deepOrangeA200,
                                  fontSize: getFontSize(
                                    12,
                                  ),
                                  fontFamily: 'Gilroy-Medium',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Padding(
                              padding: getPadding(
                                left: 20,
                                top: 10,
                                right: 20,
                              ),
                              child: Text(
                                "Do You Have Symptomps ?",
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.start,
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
                                left: 24,
                                top: 20,
                                right: 24,
                                bottom: 28,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.start,
                                crossAxisAlignment:
                                    CrossAxisAlignment.center,
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  CustomButton(
                                    width: 89,
                                    text: "Call Now",
                                    onTap: (){
                                      Navigator.push(
    context,
    MaterialPageRoute(builder: (context)
 =>const EmergencyHelpCallScreen()),
  );
                                    },
                                    variant: ButtonVariant.FillIndigoA700,
                                    shape: ButtonShape.RoundedBorder4,
                                    padding: ButtonPadding.PaddingAll12,
                                    fontStyle: ButtonFontStyle
                                        .GilroyMedium12WhiteA700,
                                  ),
                                  HorizontalSpace(width: 16),
                                  CustomButton(
                                    width: 100,
                                    text: "Find Doctor",
                                    margin: getMargin(
                                      left: 0,
                                    ),
                                     onTap: (){
                                      Navigator.push(
    context,
    MaterialPageRoute(builder: (context)
 =>const DoctorsListScreen()),
  );
                                    },
                                    variant: ButtonVariant.FillWhiteA700,
                                    shape: ButtonShape.RoundedBorder4,
                                    padding: ButtonPadding.PaddingAll12,
                                    fontStyle:
                                        ButtonFontStyle.GilroyMedium12,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: getPadding(
                        left: 25,
                        top: 15,
                        right: 25,
                      ),
                      child: Text(
                        "CGMS Services We Provide",
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
                        top: 10,
                        right: 25,
                        bottom: 0
                      ),
                      decoration: BoxDecoration(
                        color:isDark?Colors.white: Colors.black,
                          
                        borderRadius: BorderRadius.circular(
                          getHorizontalSize(
                            1.00,
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: Padding(
                        padding: getPadding(
                          left: 24,
                          top: 0,
                          right: 24,
                        ),
                        child: FadeInDown(
                          child: GridView.builder(
                            shrinkWrap: true,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              mainAxisExtent: getVerticalSize(
                                177.00,
                              ),
                              crossAxisCount: 2,
                              mainAxisSpacing: getHorizontalSize(
                                5.00,
                              ),
                              crossAxisSpacing: getHorizontalSize(
                                10.00,
                              ),
                            ),
                            physics: const BouncingScrollPhysics(),
                            itemCount: servicesList.length,
                            itemBuilder: (context, index) {
                              return GridcutItemWidget(index: index,);
                            },
                          ),
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
    );
  }
}
