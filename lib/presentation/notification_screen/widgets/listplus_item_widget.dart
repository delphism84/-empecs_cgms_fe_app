 import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:helpcare/core/app_export.dart';
import 'package:helpcare/data/notificationList.dart';
import '../../../widgets/spacing.dart';

// ignore: must_be_immutable
class ListplusItemWidget extends StatelessWidget {
  int index;
  ListplusItemWidget(
{super.key, 
  required this.index
}

  );

  @override
    Widget build(BuildContext context) {
bool isRtl = context.locale==Constants.arLocal;
    return Padding(
      padding: getPadding(
        top: 11.0,
        bottom: 11.0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          Expanded(
            child: Row(
            children: [
              CommonImageView(
                svgPath: notificationList[index].img,
                width: 58,
                height: 58,
              ),
              HorizontalSpace(width: 14),
              Expanded(
                child: Container(
                margin: getMargin(
                  left: 0,
                  top: 10,
                  bottom: 7,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      notificationList[index].title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign:   TextAlign.start,
                      style: TextStyle(
                          
                        fontSize: getFontSize(
                          14,
                        ),
                         fontFamily: 'Gilroy-Medium',
                                fontWeight: FontWeight.w600,
                      ),
                    ),
                    Padding(
                      padding: getPadding(
                        top: 12,
                        right: 10,
                      ),
                      child: Text(
                        "12 Hours ago",
                        maxLines: 1,
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
              ),
            ],
          ),
          ),
         
         index==2?
          Container(
            height: getVerticalSize(
              36.00,
            ),
            width: getHorizontalSize(
              40.00,
            ),
            margin: getMargin(
              left: 0,
              top: 12,
              bottom: 10,
            ),
            child: Card(
              clipBehavior: Clip.antiAlias,
              elevation: 0,
              margin: const EdgeInsets.all(0),
              color: ColorConstant.deepPurple50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  getHorizontalSize(
                    4.00,
                  ),
                ),
              ),
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Padding(
                      padding: getPadding(
                        left: 17,
                        top: 12,
                        right: 17,
                        bottom: 12,
                      ),
                      child: CommonImageView(
                        isRtl: isRtl,
                        svgPath: ImageConstant.imgVectorDeepPurpleA400,
                        height: getVerticalSize(
                          11.00,
                        ),
                        width: getHorizontalSize(
                          5.00,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
       :const SizedBox(),
       
        ],
      ),
    );
  }
}
