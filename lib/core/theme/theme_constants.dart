import 'package:flutter/material.dart';
import '../app_export.dart';


// 전역 텍스트 스케일은 main.dart의 MediaQuery.textScaler에서 한 번만 적용한다.
// (ThemeData에서 fontSize에 곱하면 이중 적용되어 UI 겹침/텍스트 과대가 되기 쉬움)
const double kGlobalTextScale = 1.1;

ThemeData lightTheme = ThemeData(
  // primaryColor: Colors.black,
  primaryColor: ColorConstant.baseColor,
  colorScheme: ColorScheme.fromSeed(seedColor: ColorConstant.baseColor),
  visualDensity: VisualDensity.compact,
  dialogTheme: DialogThemeData(
     shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(getHorizontalSize(10))
      ),
      backgroundColor: Colors.white
  ),
  
  scaffoldBackgroundColor:ColorConstant.gray50,
appBarTheme: AppBarTheme(
  backgroundColor:  ColorConstant.whiteA700,
  foregroundColor: Colors.black),
  
  brightness: Brightness.light,
  textTheme: TextTheme(
    titleLarge: TextStyle(
      color: Colors.black,
      fontSize: getFontSize(20),
      fontFamily: 'Gilroy-Medium',
      fontWeight: FontWeight.bold,
    ),
    bodyMedium: TextStyle(
      color: Colors.black,
      fontSize: getFontSize(13),
      fontFamily: 'Gilroy-Medium',
      fontWeight: FontWeight.w400,
    ),
    bodySmall: TextStyle(
      color: Colors.black87,
      fontSize: getFontSize(11),
      fontFamily: 'Gilroy-Medium',
      fontWeight: FontWeight.w400,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ButtonStyle(
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(getHorizontalSize(10))),
      ),
      minimumSize: WidgetStateProperty.all(Size.fromHeight(getVerticalSize(36))),
      padding: WidgetStateProperty.all(EdgeInsets.symmetric(horizontal: getHorizontalSize(12))),
      backgroundColor: WidgetStateProperty.all(ColorConstant.baseColor),
      foregroundColor: WidgetStateProperty.all(ColorConstant.whiteA700),
      textStyle: WidgetStateProperty.all(TextStyle(
        fontFamily: 'Gilroy-Medium',
        fontSize: getFontSize(11),
        fontWeight: FontWeight.w600,
      )),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: ButtonStyle(
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(getHorizontalSize(10))),
      ),
      // side: MaterialStateProperty.all(BorderSide(color: ColorConstant.indigo51, width: 1)),
      side: WidgetStateProperty.all(BorderSide(color: ColorConstant.baseColor, width: 1)),
      minimumSize: WidgetStateProperty.all(Size.fromHeight(getVerticalSize(36))),
      padding: WidgetStateProperty.all(EdgeInsets.symmetric(horizontal: getHorizontalSize(12))),
      foregroundColor: WidgetStateProperty.all(ColorConstant.baseColor),
      textStyle: WidgetStateProperty.all(TextStyle(
        fontFamily: 'Gilroy-Medium',
        fontSize: getFontSize(11),
        fontWeight: FontWeight.w600,
      )),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: ButtonStyle(
      minimumSize: WidgetStateProperty.all(Size.fromHeight(getVerticalSize(36))),
      padding: WidgetStateProperty.all(EdgeInsets.symmetric(horizontal: getHorizontalSize(12))),
      textStyle: WidgetStateProperty.all(TextStyle(
        fontFamily: 'Gilroy-Medium',
        fontSize: getFontSize(11),
        fontWeight: FontWeight.w600,
      )),
    ),
  ),
  switchTheme: const SwitchThemeData(
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    splashRadius: 16,
  ),
  


bottomSheetTheme: BottomSheetThemeData(
backgroundColor: ColorConstant.whiteA700,
shape:  const RoundedRectangleBorder(
           
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(20),
            )
        ),
        

 ),
 

inputDecorationTheme: InputDecorationTheme(
                                        alignLabelWithHint: true,
                                        
      hintStyle: TextStyle(
                color:
                    ColorConstant.bluegray300,
                fontSize: getFontSize(16),
                fontFamily:
                    'Gilroy-Medium',
                fontWeight:
                    FontWeight.w400,
              ),
   
  
  border:  OutlineInputBorder(
    borderRadius: BorderRadius.circular(
      getHorizontalSize(
        10.00,
      ),
    ),
  borderSide: BorderSide.none,
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(
      getHorizontalSize(
        10.00,
      ),
    ),
    borderSide: BorderSide.none
  ),
  focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: ColorConstant.baseColor,
            width: 1,
          ),
        ),


  filled: true,
  fillColor: ColorConstant.bluegray50,
                                      ),



);
                                     
                                     




ThemeData darkTheme = ThemeData(
  primaryColor: ColorConstant.baseColor,
  colorScheme: ColorScheme.fromSeed(seedColor: ColorConstant.baseColor, brightness: Brightness.dark),
  visualDensity: VisualDensity.compact,
   dialogTheme: DialogThemeData(
     shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(getHorizontalSize(10))
      ),
      backgroundColor: ColorConstant.darkBg
  ),
  scaffoldBackgroundColor: ColorConstant.darkBg,
  tabBarTheme: const TabBarThemeData(
    
  ),
appBarTheme: const AppBarTheme(
  // backgroundColor: ColorConstant.darkBg,
  foregroundColor: Colors.white),

  brightness: Brightness.dark,
  textTheme: TextTheme(
    titleLarge: TextStyle(
      color: Colors.white,
      fontSize: getFontSize(20),
      fontFamily: 'Gilroy-Medium',
      fontWeight: FontWeight.bold,
    ),
    bodyMedium: TextStyle(
      color: Colors.white,
      fontSize: getFontSize(13),
      fontFamily: 'Gilroy-Medium',
      fontWeight: FontWeight.w400,
    ),
    bodySmall: TextStyle(
      color: Colors.white70,
      fontSize: getFontSize(11),
      fontFamily: 'Gilroy-Medium',
      fontWeight: FontWeight.w400,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ButtonStyle(
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(getHorizontalSize(10))),
      ),
      minimumSize: WidgetStateProperty.all(Size.fromHeight(getVerticalSize(36))),
      padding: WidgetStateProperty.all(EdgeInsets.symmetric(horizontal: getHorizontalSize(12))),
      backgroundColor: WidgetStateProperty.all(ColorConstant.baseColor),
      foregroundColor: WidgetStateProperty.all(ColorConstant.whiteA700),
      textStyle: WidgetStateProperty.all(TextStyle(
        fontFamily: 'Gilroy-Medium',
        fontSize: getFontSize(11),
        fontWeight: FontWeight.w600,
      )),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: ButtonStyle(
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(getHorizontalSize(10))),
      ),
      side: WidgetStateProperty.all(BorderSide(color: ColorConstant.baseColor, width: 1)),
      minimumSize: WidgetStateProperty.all(Size.fromHeight(getVerticalSize(36))),
      padding: WidgetStateProperty.all(EdgeInsets.symmetric(horizontal: getHorizontalSize(12))),
      foregroundColor: WidgetStateProperty.all(ColorConstant.baseColor),
      textStyle: WidgetStateProperty.all(TextStyle(
        fontFamily: 'Gilroy-Medium',
        fontSize: getFontSize(11),
        fontWeight: FontWeight.w600,
      )),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: ButtonStyle(
      minimumSize: WidgetStateProperty.all(Size.fromHeight(getVerticalSize(36))),
      padding: WidgetStateProperty.all(EdgeInsets.symmetric(horizontal: getHorizontalSize(12))),
      textStyle: WidgetStateProperty.all(TextStyle(
        fontFamily: 'Gilroy-Medium',
        fontSize: getFontSize(11),
        fontWeight: FontWeight.w600,
      )),
    ),
  ),
  switchTheme: const SwitchThemeData(
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    splashRadius: 16,
  ),
  
  inputDecorationTheme: InputDecorationTheme(
hintStyle: TextStyle(
                color:
                    ColorConstant.bluegray300,
                fontSize: getFontSize(16),
                fontFamily:
                    'Gilroy-Medium',
                fontWeight:
                    FontWeight.w400,
              ),
     filled: true,
   fillColor: ColorConstant.darkTextField,
  border:  OutlineInputBorder(
    borderRadius: BorderRadius.circular(
      getHorizontalSize(
        10.00,
      ),
    ),
  borderSide: BorderSide.none,
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(
      getHorizontalSize(
        10.00,
      ),
    ),
    borderSide: BorderSide.none
  ),
  focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: ColorConstant.baseColor,
            width: 1,
          ),
        ),

),

 bottomSheetTheme: BottomSheetThemeData(
backgroundColor: ColorConstant.darkTextField,
shape:  const RoundedRectangleBorder(
           
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(20),
            )
        ),
        

 ),
 
);

Widget darkCustomContainer({required Widget child, EdgeInsetsGeometry
 padding= const EdgeInsets.symmetric(horizontal:1) }){
  return  Container(
    padding: padding,
     margin: EdgeInsets.only(
       
        bottom: getVerticalSize(
          8
        ),
      ),
      decoration: BoxDecoration(
        // color: ColorConstant.darkButton,
        borderRadius: BorderRadius.circular(
          getHorizontalSize(
            20.00,
          ),
        ),
      
     
      ),
      
      
      child: child
    
    );
 }

