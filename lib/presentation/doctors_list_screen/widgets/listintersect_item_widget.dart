import 'package:flutter/material.dart';
import 'package:helpcare/core/app_export.dart';
import 'package:helpcare/data/doctors_list.dart';
import 'package:helpcare/widgets/spacing.dart';

// ignore: must_be_immutable
class ListintersectItemWidget extends StatelessWidget {
  int index;
  ListintersectItemWidget(
    {super.key, required this.index}
  );

  @override
    Widget build(BuildContext context) {
    bool isDark =Theme.of(context).brightness==Brightness.dark;
    return Container(
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
          Container(
            height: getSize(
              86.00,
            ),
            width: getSize(
              86.00,
            ),
            margin: getMargin(
              left: 17,
              right: 17,
              top: 17,
              bottom: 17,
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: getPadding(
                  left: 1,
                  top: 10,
                  right: 3,
                ),
                child: CommonImageView(
                  imagePath: doctorsList[index].img,
                  height: getVerticalSize(
                    76.00,
                  ),
                  width: getHorizontalSize(
                    81.00,
                  ),
                ),
              ),
            ),
          ),
          Container(
            margin: getMargin(
              left: 0,
              top: 26,
              bottom: 26,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Padding(
                  padding: getPadding(
                    right: 5,
                  ),
                  child: Text(
                    doctorsList[index].title,
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
                  child: Padding(
                    padding: getPadding(
                      left: 1,
                      top: 13,
                    ),
                    child: Text(
                      "Neurology Specialist",
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
                ),
                Padding(
                  padding: getPadding(
                    left: 1,
                    top: 10,
                    right: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Padding(
                        padding: getPadding(
                          top: 2,
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
                      HorizontalSpace(width: 6),
                      Padding(
                        padding: getPadding(
                          left: 0,
                          top: 1,
                        ),
                        child: Text(
                          "50 Review",
                          overflow: TextOverflow.ellipsis,
                          textAlign:   TextAlign.start,
                          style: TextStyle(
                            color: ColorConstant.bluegray400,
                            fontSize: getFontSize(
                              12,
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
                          bottom: 1,
                        ),
                        child: Text(
                          "(4.8)",
                          overflow: TextOverflow.ellipsis,
                          textAlign:   TextAlign.start,
                          style: TextStyle(
                            color: ColorConstant.bluegray400,
                            fontSize: getFontSize(
                              12,
                            ),
                             fontFamily: 'Gilroy-Medium',
                            fontWeight: FontWeight.w400,
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
    );
  }
}
