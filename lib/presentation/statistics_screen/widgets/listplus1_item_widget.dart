import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:helpcare/core/app_export.dart';
import 'package:helpcare/widgets/custom_icon_button.dart';

// ignore: must_be_immutable
class Listplus1ItemWidget extends StatelessWidget {
  const Listplus1ItemWidget({super.key});

  @override
    Widget build(BuildContext context) {
    bool isDark =Theme.of(context).brightness==Brightness.dark;
    return IntrinsicWidth(
      child: Align(
        alignment: Alignment.center,
        child: Container(
          margin: getMargin(
            right: 18,
          ),
          decoration: BoxDecoration(
            color: ColorConstant.whiteA700,
            borderRadius: BorderRadius.circular(
              getHorizontalSize(
                6.00,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              CustomIconButton(isDark:isDark,
                height: 48,
                width: 48,
                margin: getMargin(
                  left: 19,
                  top: 21,
                  right: 19,
                ),
                variant: IconButtonVariant.FillDeeporange50,
                shape: IconButtonShape.CircleBorder24,
                child: CommonImageView(
                  svgPath: ImageConstant.imgPlus48X48,
                ),
              ),
              Padding(
                padding: getPadding(
                  left: 19,
                  top: 18,
                  right: 19,
                ),
                child: Text(
                  'stats_demo_active'.tr(),
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
                  left: 19,
                  top: 13,
                  right: 17,
                  bottom: 23,
                ),
                child: Text(
                  "20,000+",
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
            ],
          ),
        ),
      ),
    
    
    
    );
  }
}
