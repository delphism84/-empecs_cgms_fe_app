import 'dart:ui';
import 'package:flutter/material.dart';

class ColorConstant {
  // base brand color
  static Color baseColor = fromHex('#5bb990');
  // login primary color
  static Color loginGreen = fromHex('#7bb177');
  static Color deepPurple90014 = fromHex('#140e00b2');

  static Color bluegray50 = fromHex('#edeff2');

  static Color deepPurple90011 = fromHex('#110500b3');

  static Color green500 = fromHex('#46cb5c');

  static Color deepPurpleA400 = fromHex('#7c1bf7');

  static Color gray800 = fromHex('#494949');

  static Color yellow50 = fromHex('#fff8e5');

  static Color indigoA40047 = fromHex('#475450e4');

  static Color indigoA70007 = fromHex('#07443ee0');

  static Color yellow70047 = fromHex('#47f7ba27');

  static Color deepPurple50 = fromHex('#f1e5ff');

  static Color indigo400 = fromHex('#6361bc');

  static Color bluegray4007a = fromHex('#7a7d7da2');

  static Color indigoA700 = fromHex('#443fe0');

  static Color bluegray401 = fromHex('#7d808a');

  static Color cyan40047 = fromHex('#4718cfe5');

  static Color bluegray400 = fromHex('#7e808a');
  static Color darkChoice = fromHex('#213045');
  static Color darkStatistics = fromHex('#25354D');

  static Color bluegray200 = fromHex('#a9afc4');
  static Color darkLine = fromHex('#1B2738');
  static Color da = fromHex('#a9afc4');

  static Color whiteA700 = fromHex('#ffffff');

  static Color deepPurple9002b = fromHex('#2b0500b3');

  static Color cyan400 = fromHex('#19cfe5');

  static Color indigo10019 = fromHex('#19c6ccdf');

  static Color deepOrange50 = fromHex('#ffede5');

  static Color deepOrangeA200 = fromHex('#f76f39');
  static Color purble = fromHex('#7D1BF7');

  static Color deepOrangeA20047 = fromHex('#47f76f38');

  static Color deepPurple103 = fromHex('#d4d3ec');

  static Color deepPurple100 = fromHex('#d0cee8');

  static Color gray50 = fromHex('#fafafc');

  static Color greenCardBackground = fromHex('#5bb990');

  static Color deepPurple101 = fromHex('#d1cfe8');

  static Color bluegray50051 = fromHex('#5172768a');

  static Color yellow700 = fromHex('#f7ba27');

  static Color green40047 = fromHex('#4773c255');

  static Color gray700 = fromHex('#5e5e5e');

  static Color gray901 = fromHex('#110c26');

  static Color indigo50 = fromHex('#eaeaff');

  static Color gray900 = fromHex('#171f2c');
  static Color darkBg = fromHex('#171f2c');

  static Color indigo51 = fromHex('#dedefc');

  static Color bluegray100 = fromHex('#d9d9d9');

  static Color lightBlue50 = fromHex('#e5fcff');

  static Color green50 = fromHex('#e5ffea');

  static Color gray300 = fromHex('#d9d8ee');

  static Color gray100 = fromHex('#f1f1fc');

  static Color bluegray900 = fromHex('#1b2738');
  static Color darkTextField = fromHex('#1b2738');

  static Color indigo100 = fromHex('#bebcff');

  static Color indigo101 = fromHex('#b4b2f3');

  static Color bluegray302 = fromHex('#8d93aa');

  static Color bluegray500 = fromHex('#767b8e');

  static Color bluegray301 = fromHex('#949ab2');

  static Color bluegray300 = fromHex('#9399ab');

  static Color bluegray902 = fromHex('#2d2d2d');

  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
