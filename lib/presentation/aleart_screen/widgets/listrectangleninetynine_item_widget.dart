import 'package:flutter/material.dart';
import 'package:helpcare/core/app_export.dart';
import 'package:helpcare/data/calls_list.dart';
import 'package:helpcare/presentation/emergency_help_call_screen/emergency_help_call_screen.dart';
import 'package:helpcare/widgets/custom_button.dart';

// ignore: must_be_immutable
class ListrectangleninetynineItemWidget extends StatelessWidget {
  int index;
  ListrectangleninetynineItemWidget(

    {super.key, required this.index}
  );

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
                left: 15,
                right: 15,
                top: 15,
                bottom: 15,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  getHorizontalSize(
                    6.00,
                  ),
                ),
                child: CommonImageView(
                  imagePath: callsList[index].img,
                  height: getVerticalSize(
                    130.00,
                  ),
                  width: getHorizontalSize(
                    95.00,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                margin: getMargin(
                  left: 0,
                  top: 22,
                  right: 0,
                  bottom: 25,
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
                        callsList[index].title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.start,
                        style: TextStyle(
                          fontSize: getFontSize(16),
                          fontFamily: 'Gilroy-Medium',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Padding(
                      padding: getPadding(top: 14, right: 10),
                      child: Text(
                        "Get help by making a phone\ncall from here ",
                        softWrap: true,
                        textAlign: TextAlign.start,
                        style: TextStyle(
                          color: ColorConstant.bluegray500,
                          fontSize: getFontSize(12),
                          fontFamily: 'Gilroy-Medium',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    CustomButton(
                      width: 89,
                      text: "Call Now",
                      margin: getMargin(
                        top: 19,
                        right: 10,
                      ),
                      variant: ButtonVariant.FillIndigo50,
                      shape: ButtonShape.RoundedBorder4,
                      padding: ButtonPadding.PaddingAll12,
                      fontStyle: ButtonFontStyle.GilroyMedium12,
                      onTap: (){
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const EmergencyHelpCallScreen()),
                        );
                      },
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
