 import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:helpcare/core/app_export.dart';
import 'package:helpcare/presentation/patient_update_screen/patient_update_screen.dart';
import 'package:helpcare/widgets/custom_icon_button.dart';

import '../../../widgets/spacing.dart';

// ignore: must_be_immutable
class ListsearchItemWidget extends StatelessWidget {
  const ListsearchItemWidget({super.key});

  @override
    Widget build(BuildContext context) {
    bool isDark =Theme.of(context).brightness==Brightness.dark;
bool isRtl = context.locale==Constants.arLocal;
    return InkWell(
      onTap: (){
        Navigator.push(
    context,
    MaterialPageRoute(builder: (context)
 =>const PatientUpdateScreen()),
  );
      },
      child: Padding(
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
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                CustomIconButton(isDark:isDark,
                  height: 58,
                  width: 58,
                  variant: IconButtonVariant.FillDeeporange50,
                  child: CommonImageView(
                    svgPath: ImageConstant.imgSearchDeepOrangeA200,
                  ),
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
                        "Your patient update",
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
                          top: 13,
                          right: 10,
                        ),
                        child: Text(
                          "44 minutes ago",
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
                color: ColorConstant.deepOrange50,
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
                          svgPath: ImageConstant.imgVectorDeepOrangeA200,
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
            ),
          ],
        ),
      ),
    );
  }
}
