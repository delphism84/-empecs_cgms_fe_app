import 'package:flutter/material.dart';
import 'package:helpcare/core/app_export.dart';
import 'package:helpcare/data/covid_symptoms_list.dart';

// ignore: must_be_immutable
class GridglobeItemWidget extends StatelessWidget {
  int index;
  GridglobeItemWidget(
    {super.key, required this.index}
  );

  @override
    Widget build(BuildContext context) {
    bool isDark =Theme.of(context).brightness==Brightness.dark;
    return SizedBox(
      height: getVerticalSize(
        166.00,
      ),
      width: getHorizontalSize(
        159.00,
      ),
      child: Stack(
        alignment: Alignment.topLeft,
        children: [
          Align(
            alignment: Alignment.bottomRight,
            child: Container(
              width: getHorizontalSize(
                150.00,
              ),
              margin: getMargin(
                left: 10,
                top: 10,
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
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: getPadding(
                      left: 35,
                      top: 28,
                      right: 35,
                    ),
                    child: CommonImageView(
                      svgPath: covidSymptomsList[index].img,
                      height: getSize(
                        65.00,
                      ),
                      width: getSize(
                        65.00,
                      ),
                    ),
                  ),
                  Padding(
                    padding: getPadding(
                      left: 0,
                      top: 19,
                      right: 0,
                      bottom: 30,
                    ),
                    child: Text(
                     covidSymptomsList[index].title,
                      overflow: TextOverflow.ellipsis,
                      textAlign:   TextAlign.center,
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
          Align(
            alignment: Alignment.topLeft,
            child: Container(
              margin: getMargin(
                right: 10,
                bottom: 10,
              ),
              padding: getPadding(
                left: 11,
                top: 5,
                right: 10,
                bottom: 7,
              ),
              decoration: BoxDecoration(
                color: getColor(index),
               shape: BoxShape.circle
              ),
              child: Text(
                (index+1).toString(),
                overflow: TextOverflow.ellipsis,
                textAlign:   TextAlign.start,
                style: TextStyle(
                  color: ColorConstant.whiteA700,
                  fontSize: getFontSize(
                    12,
                  ),
                  fontFamily: 'Gilroy-Medium',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Color getColor(int index) {
if(index==0) {
  return ColorConstant.yellow700;
} else if (index==1)
return ColorConstant.cyan400;
else if(index==2)
return ColorConstant.deepOrangeA200;
else if(index==3)
return ColorConstant.purble;

else if(index==4)
return ColorConstant.green500;

else if(index==5)
return ColorConstant.deepOrangeA200;

return ColorConstant.cyan400;


  }
}
