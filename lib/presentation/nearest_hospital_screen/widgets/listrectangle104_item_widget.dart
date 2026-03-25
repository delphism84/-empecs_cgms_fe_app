import 'package:flutter/material.dart';
import 'package:helpcare/core/app_export.dart';

// ignore: must_be_immutable
class Listrectangle104ItemWidget extends StatelessWidget {
  const Listrectangle104ItemWidget({super.key});

  @override
    Widget build(BuildContext context) {
    bool isDark =Theme.of(context).brightness==Brightness.dark;
    return Align(
      alignment: Alignment.center,
      child: Container(
        margin: getMargin(
          top: 11.0,
          bottom: 11.0,
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
                left: 20,
                right: 20,
                top: 20,
                bottom: 20,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  getHorizontalSize(
                    6.00,
                  ),
                ),
                child: CommonImageView(
                  imagePath: ImageConstant.imgRectangle104,
                  height: getVerticalSize(
                    94.00,
                  ),
                  width: getHorizontalSize(
                    88.00,
                  ),
                ),
              ),
            ),
            Container(
              margin: getMargin(
                left: 0,
                top: 26,
                right: 0,
                bottom: 22,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    "Mount Adora Hospital",
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
                  Padding(
                    padding: getPadding(
                      top: 9,
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
                              color: ColorConstant.bluegray401,
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
                  Padding(
                    padding: getPadding(
                      left: 1,
                      top: 5,
                      right: 10,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: getPadding(
                            top: 3,
                            bottom: 1,
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
                            top: 1,
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
                            bottom: 1,
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
                  Padding(
                    padding: getPadding(
                      left: 1,
                      top: 12,
                      right: 10,
                    ),
                    child: Text(
                      "Opens 24 Hours",
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
    );
  }
}
