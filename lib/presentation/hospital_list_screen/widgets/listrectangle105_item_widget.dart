import 'package:flutter/material.dart';
import 'package:helpcare/core/app_export.dart';
import 'package:helpcare/presentation/hospital_details_screen/hospital_details_screen.dart';
import 'package:helpcare/widgets/spacing.dart';

import '../../../data/hospital_list.dart';

// ignore: must_be_immutable
class Listrectangle105ItemWidget extends StatelessWidget {
  int index;
  Listrectangle105ItemWidget({super.key, 
    required this.index
  });

  @override
    Widget build(BuildContext context) {
    bool isDark =Theme.of(context).brightness==Brightness.dark;
    return InkWell(
      onTap: (){
        Navigator.push(
    context,
    MaterialPageRoute(builder: (context)
 =>const HospitalDetailsScreen()),
  );
      },
      child: Container(
        margin: getMargin(
          top: 10.5,
          bottom: 10.5,
        ),
        decoration: BoxDecoration(
          color:isDark?ColorConstant.darkTextField: ColorConstant.whiteA700,
          borderRadius: BorderRadius.circular(
            getHorizontalSize(
              6.00,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            Padding(
              padding: getPadding(
                left: 16,
                right: 16,
                top: 16,
                bottom: 16,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  getHorizontalSize(
                    6.00,
                  ),
                ),
                child: CommonImageView(
                  imagePath: hospitalList[index].img,
                  height: getVerticalSize(
                    88.00,
                  ),
                  width: getHorizontalSize(
                    98.00,
                  ),
                ),
              ),
            ),
            HorizontalSpace(width: 16),
            Container(
              margin: getMargin(
                left: 0,
                top: 0,
                right: 0,
                bottom: 27,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Padding(
                    padding: getPadding(
                      right: 0,
                    ),
                    child: Text(
                     hospitalList[index].title,
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
                            top: 1,
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
                            top: 1,
                          ),
                          child: Text(
                            "Akhalia, Sylhet",
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
                      width: getHorizontalSize(
                        162.00,
                      ),
                      margin: getMargin(
                        left: 1,
                        top: 9,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Padding(
                            padding: getPadding(
                              top: 3,
                              bottom: 3,
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
                              top: 1,
                              bottom: 2,
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
                              bottom: 2,
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
                          Padding(
                            padding: getPadding(
                              top: 1,
                              bottom: 2,
                            ),
                            child: Text(
                              "|",
                              overflow: TextOverflow.ellipsis,
                              textAlign:   TextAlign.start,
                              style: TextStyle(
                                color: ColorConstant.bluegray50051,
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
                              top: 2,
                            ),
                            child: Text(
                              "Open 24 Hours",
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
