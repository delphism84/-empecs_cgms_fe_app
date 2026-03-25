import 'package:flutter/material.dart';
import 'package:helpcare/core/app_export.dart';
import 'package:helpcare/presentation/home.dart';
import 'package:helpcare/widgets/custom_button.dart';
import 'package:helpcare/widgets/custom_icon_button.dart';

// ignore_for_file: must_be_immutable
class ApplysuccessdialogPage extends StatelessWidget {
  const ApplysuccessdialogPage({super.key});

  @override
    Widget build(BuildContext context) {
    bool isDark =Theme.of(context).brightness==Brightness.dark;
    return Dialog(
      child: Container(
        width: double.infinity,
        margin: getMargin(
          left: 0,
          top: 20,
          right: 0,
          bottom: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CustomIconButton(isDark:isDark,
                  height: 50,
                  width: 50,
                  margin: getMargin(
                    left: 0,
                    top: 0,
                    right: 0,
                  ),
                  
                  onTap: () {
                    Navigator.pop(context);
                    
                  },
                  child: CommonImageView(
                    isDark: isDark,
                    svgPath: ImageConstant.imgClose50X50,
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.center,
              child: Container(
                height: getSize(
                  142.00,
                ),
                width: getSize(
                  142.00,
                ),
                margin: getMargin(
                  left: 24,
                  top: 24,
                  right: 24,
                ),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  elevation: 0,
                  margin: const EdgeInsets.all(0),
                  color: ColorConstant.indigo50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      getHorizontalSize(
                        71.00,
                      ),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: Padding(
                          padding: getPadding(
                            left: 36,
                            top: 40,
                            right: 32,
                            bottom: 40,
                          ),
                          child: CommonImageView(
                            svgPath: ImageConstant.imgCheckmark57X74,
                            height: getVerticalSize(
                              57.00,
                            ),
                            width: getHorizontalSize(
                              74.00,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: Padding(
                padding: getPadding(
                  left: 24,
                  top: 44,
                  right: 24,
                ),
                child: Text(
                  "Successfully Applied",
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
              alignment: Alignment.center,
              child: Container(
                width: getHorizontalSize(
                  264.00,
                ),
                margin: getMargin(
                  left: 24,
                  top: 22,
                  right: 24,
                ),
                child: Text(
                  "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Dictum vulputate nulla sed viverra.",
                  maxLines: null,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ColorConstant.bluegray302,
                    fontSize: getFontSize(
                      14,
                    ),
                      fontFamily: 'Gilroy-Medium',
                                fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
            CustomButton(
              width: 279,
              text: "aPPLY ANOTHER TEST".toUpperCase(),
              margin: getMargin(
                left: 24,
                top: 71,
                right: 24,
                bottom: 20,
              ),
              onTap: (){
               Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) =>
    const Home()), (Route<dynamic> route) => false);
              },
              // variant: ButtonVariant.FillIndigoA700,
              shape: ButtonShape.RoundedBorder4,
              fontStyle: ButtonFontStyle.GilroyMedium12WhiteA700,
              alignment: Alignment.center,
            ),
          ],
        ),
      ),
    );
  }
}
