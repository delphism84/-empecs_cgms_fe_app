import 'package:flutter/material.dart';
import 'package:helpcare/core/app_export.dart';
import 'package:helpcare/data/services_lits.dart';
import 'package:helpcare/presentation/apply_covid_test_screen/apply_covid_test_screen.dart';
import 'package:helpcare/presentation/nearest_hospital_screen/nearest_hospital_screen.dart';
import 'package:helpcare/presentation/symptoms_screen/symptoms_screen.dart';

// ignore: must_be_immutable
class GridcutItemWidget extends StatelessWidget {
  int index;
  GridcutItemWidget({super.key, required this.index});

  @override
    Widget build(BuildContext context) {
    bool isDark =Theme.of(context).brightness==Brightness.dark;
    return InkWell(
      onTap:()=> onSectionTap(context),
      child: Align(
        alignment: Alignment.center,
        child: Container(
          decoration: BoxDecoration(
            color:isDark?ColorConstant.darkTextField: ColorConstant.whiteA700,
            borderRadius: BorderRadius.circular(
              getHorizontalSize(
                8.00,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: getVerticalSize(60),
                width: getHorizontalSize(60),
                margin: getMargin(
                  left: 38,
                  top: 24,
                  right: 38,
                ),
                decoration: BoxDecoration(
                  color: getColor(index),
                  shape: BoxShape.circle
                ),
    
             
                padding: getPadding(
                  all: 14
                ),
                child: CommonImageView(
                  svgPath: servicesList[index].img,
                ),
              ),
              Padding(
                padding: getPadding(
                  left: 10,
                  top: 20,
                  right: 10,
                  bottom: 31,
                ),
                child: Text(
                 servicesList[index].title,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
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
    );
  }
  
  Color getColor(int index) {

     if (index==0) {
       return ColorConstant.deepOrange50;
     } else if ( index==1)
return ColorConstant.lightBlue50;

else if(index==2)
return ColorConstant.deepPurple50;

return ColorConstant.yellow50;

  }

  void onSectionTap( BuildContext context) {
    if(index==0)
    {
      Navigator.push(
    context,
    MaterialPageRoute(builder: (context)
 =>const ApplyCovidTestScreen()),
  );
    }

    else if (index==1)
    {
      Navigator.push(
    context,
    MaterialPageRoute(builder: (context)
 =>const NearestHospitalScreen()),
  );
    }

    else if (index==3)
    {
      Navigator.push(
    context,
    MaterialPageRoute(builder: (context)
 =>const SymptomsScreen()),
  );
    }
  }
}
