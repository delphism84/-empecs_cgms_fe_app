import 'package:flutter/material.dart';
import 'package:helpcare/core/app_export.dart';

// ignore: must_be_immutable
class ListglobeItemWidget extends StatelessWidget {
  const ListglobeItemWidget({super.key});

  @override
    Widget build(BuildContext context) {
    return Container(
      margin: getMargin(
        top: 10.0,
        bottom: 10.0,
      ),
      decoration: BoxDecoration(
        color: ColorConstant.whiteA700,
        borderRadius: BorderRadius.circular(
          getHorizontalSize(
            8.00,
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
              top: 16,
              bottom: 16,
            ),
            child: CommonImageView(
              svgPath: ImageConstant.imgGlobe,
              height: getSize(
                63.00,
              ),
              width: getSize(
                63.00,
              ),
            ),
          ),
          Container(
            margin: getMargin(
              left: 18,
              top: 18,
              right: 73,
              bottom: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Padding(
                  padding: getPadding(
                    right: 10,
                  ),
                  child: Text(
                    "Wash Your Hands",
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
                Container(
                  width: getHorizontalSize(
                    157.00,
                  ),
                  margin: getMargin(
                    top: 13,
                  ),
                  child: Text(
                    "Get help by making a phone\ncall from here ",
                    maxLines: null,
                    textAlign:   TextAlign.start,
                    style: TextStyle(
                      color: ColorConstant.bluegray500,
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
    );
  }
}
