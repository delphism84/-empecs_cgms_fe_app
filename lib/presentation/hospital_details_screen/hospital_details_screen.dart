import 'package:helpcare/presentation/emergency_help_call_screen/emergency_help_call_screen.dart';

import '../hospital_details_screen/widgets/listcabinroom_item_widget.dart';
 import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:helpcare/core/app_export.dart';
import 'package:helpcare/widgets/custom_button.dart';
import 'package:helpcare/widgets/custom_icon_button.dart';

class HospitalDetailsScreen extends StatelessWidget {
  const HospitalDetailsScreen({super.key});

  @override
    Widget build(BuildContext context) {
    bool isDark =Theme.of(context).brightness==Brightness.dark;
bool isRtl = context.locale==Constants.arLocal;
    return Scaffold(
        body: SafeArea(
          child: SizedBox(
            width: size.width,
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                        top: 13,
                                        bottom: 0,
                                      ),
                                      child: Text(
                                        "Hospitals Details",
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
                                    CustomIconButton(isDark:isDark,
                                      height: 50,
                                      width: 50,
                                      child: CommonImageView(
                                        isDark: isDark,
                                        svgPath: ImageConstant.imgCar,
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
                          left: 23,
                          top: 0,
                          right: 24,
                          bottom: 28,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                           
                            Container(
                              height: getVerticalSize(
                                253.00,
                              ),
                              width: getHorizontalSize(
                                328.00,
                              ),
                              margin: getMargin(
                                top: 0,
                              ),
                              child: Stack(
                                alignment: Alignment.topCenter,
                                children: [
                                  Align(
                                    alignment: Alignment.bottomLeft,
                                    child: Padding(
                                      padding: getPadding(
                                        top: 10,
                                        right: 10,
                                      ),
                                      child: Text(
                                        "Al Haramain Hospital",
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
                                    alignment: Alignment.topCenter,
                                    child: Container(
                                      height: getVerticalSize(
                                        242.00,
                                      ),
                                      width: getHorizontalSize(
                                        327.00,
                                      ),
                                      margin: getMargin(
                                        left: 1,
                                        bottom: 10,
                                      ),
                                      child: Stack(
                                        alignment: Alignment.bottomRight,
                                        children: [
                                          Align(
                                            alignment: Alignment.topLeft,
                                            child: Padding(
                                              padding: getPadding(
                                                bottom: 10,
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                  getHorizontalSize(
                                                    6.00,
                                                  ),
                                                ),
                                                child: CommonImageView(
                                                  imagePath: ImageConstant.imgImg,
                                                  height: getVerticalSize(
                                                    202.00,
                                                  ),
                                                  width: getHorizontalSize(
                                                    327.00,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Align(
                                            alignment: Alignment.bottomRight,
                                            child: Container(
                                              width: getHorizontalSize(
                                                80.00,
                                              ),
                                              margin: getMargin(
                                                left: 17,
                                                top: 10,
                                                right: 17,
                                              ),
                                              decoration: BoxDecoration(
                                                color:isDark?ColorConstant.darkTextField: ColorConstant.indigo50,
                                               shape: BoxShape.circle,
                                                border: Border.all(
                                                  color:isDark?ColorConstant.indigo50: ColorConstant.whiteA700,
                                                  width: getHorizontalSize(
                                                    2.00,
                                                  ),
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: ColorConstant
                                                        .deepPurple90014,
                                                    spreadRadius:
                                                        getHorizontalSize(
                                                      0.00,
                                                    ),
                                                    blurRadius: getHorizontalSize(
                                                      10.00,
                                                    ),
                                                    offset: const Offset(
                                                      0,
                                                      4,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.start,
                                                children: [
                                                  Container(
                                                    width: getHorizontalSize(
                                                      48.00,
                                                    ),
                                                    margin: getMargin(
                                                      left: 16,
                                                      top: 25,
                                                      right: 16,
                                                      bottom: 25,
                                                    ),
                                                    child: Text(
                                                      "24 Hours\nOpen",
                                                      maxLines: null,
                                                      textAlign: TextAlign.center,
                                                      style: TextStyle(
                                                        color: ColorConstant
                                                            .indigoA700,
                                                        fontSize: getFontSize(
                                                          12,
                                                        ),
                                                        fontFamily:
                                                            'Gilroy-SemiBold',
                                                        fontWeight:
                                                            FontWeight.w400,
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
                                ],
                              ),
                            ),
                            Padding(
                              padding: getPadding(
                                left: 1,
                                top: 13,
                                right: 10,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Padding(
                                    padding: getPadding(
                                      left: 1,
                                      top: 4,
                                      bottom: 4,
                                    ),
                                    child: CommonImageView(
                                      svgPath: ImageConstant.imgLocation,
                                      height: getVerticalSize(
                                        10.00,
                                      ),
                                      width: getHorizontalSize(
                                        8.00,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: getPadding(
                                      left: 6,
                                      top: 4,
                                    ),
                                    child: Text(
                                      "Subhanigat, Sylhet",
                                      overflow: TextOverflow.ellipsis,
                                      textAlign:   TextAlign.start,
                                      style: TextStyle(
                                        color: ColorConstant.bluegray400,
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
                                      left: 14,
                                      top: 2,
                                      bottom: 3,
                                    ),
                                    child: Text(
                                      "|",
                                      overflow: TextOverflow.ellipsis,
                                      textAlign:   TextAlign.start,
                                      style: TextStyle(
                                        color: ColorConstant.bluegray400,
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
                                      left: 15,
                                      top: 3,
                                      bottom: 5,
                                    ),
                                    child: CommonImageView(
                                      svgPath: ImageConstant.imgVector,
                                      height: getVerticalSize(
                                        9.00,
                                      ),
                                      width: getHorizontalSize(
                                        10.00,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: getPadding(
                                      left: 6,
                                      top: 2,
                                      bottom: 3,
                                    ),
                                    child: Text(
                                      "5.0",
                                      overflow: TextOverflow.ellipsis,
                                      textAlign:   TextAlign.start,
                                      style: TextStyle(
                                        color: ColorConstant.bluegray400,
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
                                      left: 6,
                                      top: 1,
                                      bottom: 3,
                                    ),
                                    child: Text(
                                      "(140)",
                                      overflow: TextOverflow.ellipsis,
                                      textAlign:   TextAlign.start,
                                      style: TextStyle(
                                        color: ColorConstant.bluegray400,
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
                            Align(
                              alignment: Alignment.center,
                              child: Container(
                                width: double.infinity,
                                margin: getMargin(
                                  left: 1,
                                  top: 22,
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
                                        left: 20,
                                        top: 25,
                                        right: 20,
                                      ),
                                      child: Text(
                                        "Seat Availability",
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
                                    Align(
                                      alignment: Alignment.center,
                                      child: Container(
                                        width: double.infinity,
                                        margin: getMargin(
                                          left: 20,
                                          top: 17,
                                          right: 20,
                                          bottom: 20,
                                        ),
                                        decoration: BoxDecoration(
                                          color:isDark?ColorConstant.darkChoice: ColorConstant.indigo50,
                                          borderRadius: BorderRadius.circular(
                                            getHorizontalSize(
                                              6.00,
                                            ),
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Padding(
                                              padding: getPadding(
                                                left: 26,
                                                top: 23,
                                                right: 26,
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.end,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Padding(
                                                    padding: getPadding(
                                                      top: 1,
                                                    ),
                                                    child: Text(
                                                      "Total",
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      textAlign:   TextAlign.start,
                                                      style: TextStyle(
                                                        color: ColorConstant
                                                            .indigoA700,
                                                        fontSize: getFontSize(
                                                          12,
                                                        ),
                                                        fontFamily:
                                                            'Gilroy-Medium',
                                                        fontWeight:
                                                            FontWeight.w400,
                                                      ),
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding: getPadding(
                                                      left: 21,
                                                      bottom: 1,
                                                    ),
                                                    child: Text(
                                                      "Available",
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      textAlign:   TextAlign.start,
                                                      style: TextStyle(
                                                        color: ColorConstant
                                                            .indigoA700,
                                                        fontSize: getFontSize(
                                                          12,
                                                        ),
                                                        fontFamily:
                                                            'Gilroy-Medium',
                                                        fontWeight:
                                                            FontWeight.w400,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              height: getVerticalSize(
                                                1.00,
                                              ),
                                              width: getHorizontalSize(
                                                243.00,
                                              ),
                                              margin: getMargin(
                                                left: 21,
                                                top: 12,
                                                right: 21,
                                              ),
                                              decoration: BoxDecoration(
                                                color:isDark?ColorConstant.darkLine: ColorConstant.indigo51,
                                              ),
                                            ),
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: Padding(
                                                padding: getPadding(
                                                  left: 21,
                                                  top: 12,
                                                  right: 44,
                                                  bottom: 23,
                                                ),
                                                child: ListView.separated(
                                                  physics:
                                                      const BouncingScrollPhysics(),
                                                  shrinkWrap: true,
                                                  separatorBuilder:
                                                      (context, index) {
                                                    return Container(
                                                      height: getVerticalSize(
                                                        1.00,
                                                      ),
                                                      width: getHorizontalSize(
                                                        243.00,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color:isDark?ColorConstant.darkLine: ColorConstant
                                                            .indigo51,
                                                      ),
                                                    );
                                                  },
                                                  itemCount: 4,
                                                  itemBuilder: (context, index) {
                                                    return const ListcabinroomItemWidget();
                                                  },
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
                            Align(
                              alignment: Alignment.center,
                              child: Padding(
                                padding: getPadding(
                                  left: 1,
                                  top: 22,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    CustomButton(
                                      width: 156,
                                      text: "call now".toUpperCase(),
                                      onTap: (){
                                        Navigator.push(
    context,
    MaterialPageRoute(builder: (context)
 =>const EmergencyHelpCallScreen()),
  );
                                      },
                                    ),
                                    CustomButton(
                                      width: 156,
                                      text: "Get Direction".toUpperCase(),
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
              ],
            ),
          ),
        ),
      
    );
  }
}
