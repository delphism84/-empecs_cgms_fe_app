import 'package:animate_do/animate_do.dart';
import 'package:audio_wave/audio_wave.dart';
import 'package:helpcare/widgets/spacing.dart';
import '../notification_screen/notification_screen.dart';
import '../search_screen/search_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:helpcare/core/app_export.dart';
import 'package:helpcare/widgets/custom_icon_button.dart';
import 'package:helpcare/presentation/chart_page/chart_page.dart';
import 'package:helpcare/widgets/debug_badge.dart';
// import 'package:helpcare/presentation/dashboard/memo_modal.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key, this.showEmbeddedChart = false});
  final bool showEmbeddedChart;
  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  List<String> dropdownItemList2 = ["3일", "7일", "15일", "30일"];
  Object? value2;
  Object? value1;
  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    bool isRtl = context.locale == Constants.arLocal;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.center,
              child: Container(
                width: size.width,
                margin: getMargin(left: 24, right: 24, top: 20, bottom: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Padding(
                      padding: getPadding(
                        top: 4,
                        bottom: 5,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CommonImageView(
                            svgPath: ImageConstant.appLogo,
                            height: getVerticalSize(
                              41.00,
                            ),
                            width: getHorizontalSize(
                              34.00,
                            ),
                          ),
                          Padding(
                            padding: getPadding(
                              left: 8,
                              right: 8,
                              top: 13,
                              bottom: 9,
                            ),
                            child: Text(
                              "CGMS".toUpperCase(),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.start,
                              style: TextStyle(
                                fontSize: getFontSize(
                                  18,
                                ),
                                  fontFamily: 'Gilroy-Medium',
                                fontWeight: FontWeight.bold,
                              
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomIconButton(
                          isDark: isDark,
                          height: 50,
                          width: 50,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const SearchScreen()),
                            );
                          },
                          child: CommonImageView(
                            isDark: isDark,
                            svgPath: ImageConstant.imgSearchBluegray400,
                          ),
                        ),
                        HorizontalSpace(width: 16),
                        CustomIconButton(
                          isDark: isDark,
                          height: 50,
                          width: 50,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const NotificationScreen()),
                            );
                          },
                          margin: getMargin(
                            left: 0,
                          ),
                          child: CommonImageView(
                            isDark: isDark,
                            svgPath: ImageConstant.imgNotification,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    if (widget.showEmbeddedChart)
                      Padding(
                        padding: getPadding(left: 16, right: 16, top: 8),
                        child: DebugBadge(
                          reqId: 'TG_01_01',
                          child: Container(
                            height: 800,
                            decoration: BoxDecoration(
                              color: isDark ? ColorConstant.darkTextField : ColorConstant.whiteA700,
                              borderRadius: BorderRadius.circular(getHorizontalSize(12)),
                              border: Border.all(color: ColorConstant.indigo51, width: 1),
                            ),
                            child: const ChartPage(embedded: true),
                          ),
                        ),
                      ),
                    Align(
                      alignment: Alignment.center,
                      child: Padding(
                        padding: getPadding(
                          left: 24,
                          top: 22,
                          right: 24,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Container(
                              margin: getMargin(
                                top: 1,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Text(
                                    "혈당 리포트",
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.start,
                                    style: TextStyle(
                                      fontSize: getFontSize(
                                        20,
                                      ),
                                        fontFamily: 'Gilroy-Medium',
                                fontWeight: FontWeight.bold,
                                     
                                    ),
                                  ),
                                  Container(
                                    height: getVerticalSize(
                                      2.00,
                                    ),
                                    width: getHorizontalSize(
                                      50.00,
                                    ),
                                    margin: getMargin(
                                      top: 17,
                                      right: 0,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          isDark ? Colors.white : Colors.black,
                                      borderRadius: BorderRadius.circular(
                                        getHorizontalSize(
                                          1.00,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: getHorizontalSize(120),
                              height: getVerticalSize(
                                36.00,
                              ),
                              padding: EdgeInsets.only(
                                  left: getHorizontalSize(12),
                                  right: getHorizontalSize(12),
                                  top: getVerticalSize(8),
                                  bottom: getVerticalSize(8)),
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: ColorConstant.indigoA700),
                                  color: ColorConstant.indigo50),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton(
                                  autofocus: true,
                                  value: value1,
                                  isExpanded: true,
                                  icon: Container(
                                    child: Padding(
                                      padding: getPadding(bottom: 13),
                                      child: Icon(
                                        Icons.keyboard_arrow_down,
                                        color: ColorConstant.indigoA700,
                                      ),
                                    ),
                                  ),
                                  hint: Text(
                                    '기간',
                                    textAlign: TextAlign.start,
                                    style: TextStyle(
                                      color: ColorConstant.indigoA700,
                                      fontSize: getFontSize(
                                        14,
                                      ),
                                      fontFamily: 'Gilroy-Medium',
                                      fontWeight: FontWeight.w500,
                                      height: 1.00,
                                    ),
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      value1 = value;
                                    });
                                  },
                                  items: dropdownItemList2
                                      .map<DropdownMenuItem<String>>(
                                          (String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(
                                        value,
                                        textAlign: TextAlign.start,
                                      ),
                                    );
                                  }).toList(),
                                  selectedItemBuilder: (BuildContext context) {
                                    return dropdownItemList2
                                        .map((String value) {
                                      return Text(
                                        value,
                                        textAlign: TextAlign.start,
                                        style: TextStyle(
                                          color: ColorConstant.indigoA700,
                                          fontSize: getFontSize(
                                            14,
                                          ),
                                          fontFamily: 'Gilroy-Medium',
                                          fontWeight: FontWeight.w500,
                                          height: 1.00,
                                        ),
                                      );
                                    }).toList();
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                          margin: getMargin(left: 20, right: 20),
                          height: getVerticalSize(
                            185.00,
                          ),
                          width: getHorizontalSize(
                            327.00,
                          ),
                          child: FadeInDown(
                            child: Row(
                              children: [
                                Align(
                                  alignment: Alignment.center,
                                  child: Container(
                                    width: getHorizontalSize(97),
                                    margin: getMargin(
                                      right: 0,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? ColorConstant.darkTextField
                                          : ColorConstant.whiteA700,
                                      borderRadius: BorderRadius.circular(
                                        getHorizontalSize(
                                          6.00,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      children: [
                                        VerticalSpace(height: 21),
                                        CommonImageView(
                                          imagePath: ImageConstant.active,
                                          width: 48,
                                          height: 48,
                                        ),
                                        Padding(
                                          padding: getPadding(
                                            left: 19,
                                            top: 18,
                                            right: 19,
                                          ),
                                          child: Text(
                                            "Measured",
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.start,
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
                                            left: 10,
                                            top: 13,
                                            right: 10,
                                            bottom: 23,
                                          ),
                                          child: Text(
                                            "20,000+",
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.start,
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
                                HorizontalSpace(width: 18),
                                Align(
                                  alignment: Alignment.center,
                                  child: Container(
                                    width: getHorizontalSize(97),
                                    margin: getMargin(
                                      right: 0,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? ColorConstant.darkTextField
                                          : ColorConstant.whiteA700,
                                      borderRadius: BorderRadius.circular(
                                        getHorizontalSize(
                                          6.00,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      children: [
                                        VerticalSpace(height: 21),
                                        CommonImageView(
                                          imagePath: ImageConstant.recovered,
                                          width: 48,
                                          height: 48,
                                        ),
                                        Padding(
                                          padding: getPadding(
                                            left: 19,
                                            top: 18,
                                            right: 19,
                                          ),
                                          child: Text(
                                            "Normal",
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.start,
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
                                            "6,000+",
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.start,
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
                                HorizontalSpace(width: 18),
                                Align(
                                  alignment: Alignment.center,
                                  child: Container(
                                    width: getHorizontalSize(97),
                                    margin: getMargin(
                                      right: 0,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? ColorConstant.darkTextField
                                          : ColorConstant.whiteA700,
                                      borderRadius: BorderRadius.circular(
                                        getHorizontalSize(
                                          6.00,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      children: [
                                        VerticalSpace(height: 21),
                                        CommonImageView(
                                          imagePath: ImageConstant.deaths,
                                          width: 48,
                                          height: 48,
                                        ),
                                        Padding(
                                          padding: getPadding(
                                            left: 19,
                                            top: 18,
                                            right: 19,
                                          ),
                                          child: Text(
                                            "Alarm",
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.start,
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
                                            "800+",
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.start,
                                            style: TextStyle(
                                              fontSize: getFontSize(
                                                16,
                                              ),
                                              fontFamily: 'Gilroy-SemiBold',
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: Padding(
                        padding: getPadding(
                          left: 24,
                          top: 23,
                          right: 24,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Container(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Text(
                                    "Cases Overview",
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.start,
                                    style: TextStyle(
                                      fontSize: getFontSize(
                                        20,
                                      ),
                                        fontFamily: 'Gilroy-Medium',
                                fontWeight: FontWeight.bold,
                                    
                                    ),
                                  ),
                                  Container(
                                    height: getVerticalSize(
                                      2.00,
                                    ),
                                    width: getHorizontalSize(
                                      50.00,
                                    ),
                                    margin: getMargin(
                                      top: 17,
                                      right: 0,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          isDark ? Colors.white : Colors.black,
                                      borderRadius: BorderRadius.circular(
                                        getHorizontalSize(
                                          1.00,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: getHorizontalSize(120),
                              height: getVerticalSize(
                                36.00,
                              ),
                              padding: EdgeInsets.only(
                                  left: getHorizontalSize(12),
                                  right: getHorizontalSize(12),
                                  top: getVerticalSize(8),
                                  bottom: getVerticalSize(8)),
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: ColorConstant.indigoA700),
                                  color: ColorConstant.indigo50),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton(
                                  autofocus: true,
                                  value: value2,
                                  isExpanded: true,
                                  icon: Container(
                                    child: Padding(
                                      padding: getPadding(bottom: 13),
                                      child: Icon(
                                        Icons.keyboard_arrow_down,
                                        color: ColorConstant.indigoA700,
                                      ),
                                    ),
                                  ),
                                  hint: Text(
                                    'week',
                                    textAlign: TextAlign.start,
                                    style: TextStyle(
                                      color: ColorConstant.indigoA700,
                                      fontSize: getFontSize(
                                        14,
                                      ),
                                      fontFamily: 'Gilroy-Medium',
                                      fontWeight: FontWeight.w500,
                                      height: 1.00,
                                    ),
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      value2 = value;
                                    });
                                  },
                                  items: dropdownItemList2
                                      .map<DropdownMenuItem<String>>(
                                          (String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(
                                        value,
                                        textAlign: TextAlign.start,
                                      ),
                                    );
                                  }).toList(),
                                  selectedItemBuilder: (BuildContext context) {
                                    return dropdownItemList2
                                        .map((String value) {
                                      return Text(
                                        value,
                                        textAlign: TextAlign.start,
                                        style: TextStyle(
                                          color: ColorConstant.indigoA700,
                                          fontSize: getFontSize(
                                            14,
                                          ),
                                          fontFamily: 'Gilroy-Medium',
                                          fontWeight: FontWeight.w500,
                                          height: 1.00,
                                        ),
                                      );
                                    }).toList();
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        margin: getMargin(
                            top: 60,
                            bottom: 20,
                            left: isRtl ? 0 : 40,
                            right: isRtl ? 40 : 0),
                        child: Row(
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Text(
                                  "600",
                                  style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : ColorConstant.bluegray400,
                                      fontFamily: 'Gilroy-Medium',
                                      fontSize: getFontSize(11)),
                                ),
                                VerticalSpace(height: 32),
                                Text(
                                  "300",
                                  style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : ColorConstant.bluegray400,
                                      fontFamily: 'Gilroy-Medium',
                                      fontSize: getFontSize(11)),
                                ),
                                VerticalSpace(height: 32),
                                Text(
                                  "100",
                                  style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : ColorConstant.bluegray400,
                                      fontFamily: 'Gilroy-Medium',
                                      fontSize: getFontSize(11)),
                                ),
                                VerticalSpace(height: 32),
                                Text(
                                  "50",
                                  style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : ColorConstant.bluegray400,
                                      fontFamily: 'Gilroy-Medium',
                                      fontSize: getFontSize(11)),
                                ),
                                VerticalSpace(height: 32),
                                Text(
                                  "00",
                                  style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : ColorConstant.bluegray400,
                                      fontFamily: 'Gilroy-Medium',
                                      fontSize: getFontSize(11)),
                                ),
                                VerticalSpace(height: 32),
                              ],
                            ),
                           
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Padding(
                                  padding:  getPadding(
                                    left:isRtl?0: 21,
                                    right: isRtl?21:0
                                  ),
                                  child: Stack(
                                    children: [
                                      Padding(
                                        padding: getPadding(top: 8),
                                        child: Image.asset(
                                          isDark
                                              ? ImageConstant.statistics
                                              : ImageConstant.lightStatistics,
                                          height: getVerticalSize(200),
                                          width: getHorizontalSize(250),
                                          fit: BoxFit.fill,
                                        ),
                                      ),
                                      Align(
                                        alignment: Alignment.bottomCenter,
                                        child: AudioWave(
                                          height: getVerticalSize(200),
                                          width: getHorizontalSize(250),
                                          spacing: getHorizontalSize(30),
                                          alignment: 'bottom',
                                          animation: false,
                                          beatRate: const Duration(milliseconds: 50),
                                          bars: [
                                            AudioWaveBar(
                                                color: isDark
                                                    ? ColorConstant.darkStatistics
                                                    : ColorConstant.indigo50,
                                                heightFactor: 1),
                                            AudioWaveBar(
                                                color: isDark
                                                    ? ColorConstant.darkStatistics
                                                    : ColorConstant.indigo50,
                                                heightFactor: 1),
                                            AudioWaveBar(
                                                color: isDark
                                                    ? ColorConstant.darkStatistics
                                                    : ColorConstant.indigo50,
                                                heightFactor: 1),
                                            AudioWaveBar(
                                                color: isDark
                                                    ? ColorConstant.darkStatistics
                                                    : ColorConstant.indigo50,
                                                heightFactor: 1),
                                            AudioWaveBar(
                                                color: isDark
                                                    ? ColorConstant.darkStatistics
                                                    : ColorConstant.indigo50,
                                                heightFactor: 1),
                                            AudioWaveBar(
                                                color: isDark
                                                    ? ColorConstant.darkStatistics
                                                    : ColorConstant.indigo50,
                                                heightFactor: 1),
                                            AudioWaveBar(
                                                color: isDark
                                                    ? ColorConstant.darkStatistics
                                                    : ColorConstant.indigo50,
                                                heightFactor: 1),
                                          ],
                                        ),
                                      ),
                                      Align(
                                        alignment: Alignment.bottomCenter,
                                        child: Padding(
                                          padding: getPadding(top: 20),
                                          child: AudioWave(
                                            height: getVerticalSize(200),
                                            width: getHorizontalSize(250),
                                            spacing: getHorizontalSize(30),
                                            alignment: 'bottom',
                                            animationLoop: 1,
                                            beatRate: const Duration(milliseconds: 50),
                                            bars: [
                                              AudioWaveBar(
                                                  color: ColorConstant.indigoA700,
                                                  heightFactor: 0.24),
                                              AudioWaveBar(
                                                  color: ColorConstant.indigoA700,
                                                  heightFactor: 0.51),
                                              AudioWaveBar(
                                                  color: ColorConstant.indigoA700,
                                                  heightFactor: 0.39),
                                              AudioWaveBar(
                                                  color: ColorConstant.indigoA700,
                                                  heightFactor: 0.64),
                                              AudioWaveBar(
                                                  color: ColorConstant.indigoA700,
                                                  heightFactor: 0.8),
                                              AudioWaveBar(
                                                  color: ColorConstant.indigoA700,
                                                  heightFactor: 0.44),
                                              AudioWaveBar(
                                                  color: ColorConstant.indigoA700,
                                                  heightFactor: 0.61),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    
                                    Text(
                                      "S",
                                      style: TextStyle(
                                          color: isDark
                                              ? Colors.white
                                              : ColorConstant.bluegray400,
                                          fontFamily: 'Gilroy-Medium',
                                          fontSize: getFontSize(11)),
                                    ),
                                    HorizontalSpace(width: 30),
                                    Text(
                                      "S",
                                      style: TextStyle(
                                          color: isDark
                                              ? Colors.white
                                              : ColorConstant.bluegray400,
                                          fontFamily: 'Gilroy-Medium',
                                          fontSize: getFontSize(11)),
                                    ),
                                    HorizontalSpace(width: 30),
                                    Text(
                                      "M",
                                      style: TextStyle(
                                          color: isDark
                                              ? Colors.white
                                              : ColorConstant.bluegray400,
                                          fontFamily: 'Gilroy-Medium',
                                          fontSize: getFontSize(11)),
                                    ),
                                    HorizontalSpace(width: 28),
                                    Text(
                                      "T",
                                      style: TextStyle(
                                          color: isDark
                                              ? Colors.white
                                              : ColorConstant.bluegray400,
                                          fontFamily: 'Gilroy-Medium',
                                          fontSize: getFontSize(11)),
                                    ),
                                    HorizontalSpace(width: 28),
                                    Text(
                                      "W",
                                      style: TextStyle(
                                          color: isDark
                                              ? Colors.white
                                              : ColorConstant.bluegray400,
                                          fontFamily: 'Gilroy-Medium',
                                          fontSize: getFontSize(11)),
                                    ),
                                    HorizontalSpace(width: 28),
                                    Text(
                                      "T",
                                      style: TextStyle(
                                          color: isDark
                                              ? Colors.white
                                              : ColorConstant.bluegray400,
                                          fontFamily: 'Gilroy-Medium',
                                          fontSize: getFontSize(11)),
                                    ),
                                    HorizontalSpace(width: 28),
                                    Text(
                                      "F",
                                      style: TextStyle(
                                          color: isDark
                                              ? Colors.white
                                              : ColorConstant.bluegray400,
                                          fontFamily: 'Gilroy-Medium',
                                          fontSize: getFontSize(11)),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ],
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


//  Container(
//                     width: getHorizontalSize(
//                       301.00,
//                     ),
//                     margin: getMargin(
//                       left: 10,
//                       top: 10,
//                       bottom: 7,
//                     ),
//                     decoration: BoxDecoration(
//                       color: ColorConstant.whiteA700,
//                       borderRadius: BorderRadius.circular(
//                         getHorizontalSize(
//                           6.00,
//                         ),
//                       ),
//                     ),
//                     child: Column(
//                       mainAxisSize: MainAxisSize.min,
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Align(
//                           alignment: Alignment.centerLeft,
//                           child: Container(
//                             height: getVerticalSize(
//                               36.00,
//                             ),
//                             width: getHorizontalSize(
//                               44.00,
//                             ),
//                             margin: getMargin(
//                               left: 78,
//                               top: 22,
//                               right: 78,
//                             ),
//                             child: Stack(
//                               alignment: Alignment.topCenter,
//                               children: [
//                                 Align(
//                                   alignment: Alignment.centerLeft,
//                                   child: CommonImageView(
//                                     svgPath: ImageConstant.imgSettings36X44,
//                                     height: getVerticalSize(
//                                       36.00,
//                                     ),
//                                     width: getHorizontalSize(
//                                       44.00,
//                                     ),
//                                   ),
//                                 ),
//                                 Align(
//                                   alignment: Alignment.topCenter,
//                                   child: Padding(
//                                     padding: getPadding(
//                                       left: 8,
//                                       top: 8,
//                                       right: 9,
//                                       bottom: 10,
//                                     ),
//                                     child: Text(
//                                       "100+",
//                                       overflow: TextOverflow.ellipsis,
//                                       textAlign:   TextAlign.start,
//                                       style: TextStyle(
//                                         color: ColorConstant.whiteA700,
//                                         fontSize: getFontSize(
//                                           12,
//                                         ),
//                                         fontFamily: 'Gilroy-SemiBold',
//                                         fontWeight: FontWeight.w500,
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                         Align(
//                           alignment: Alignment.centerRight,
//                           child: Container(
//                             height: getVerticalSize(
//                               189.00,
//                             ),
//                             width: getHorizontalSize(
//                               278.00,
//                             ),
//                             margin: getMargin(
//                               left: 10,
//                               top: 3,
//                             ),
//                             child: Stack(
//                               alignment: Alignment.bottomLeft,
//                               children: [
//                                 Align(
//                                   alignment: Alignment.bottomLeft,
//                                   child: Padding(
//                                     padding: getPadding(
//                                       top: 10,
//                                       bottom: 2,
//                                     ),
//                                     child: Row(
//                                       crossAxisAlignment:
//                                           CrossAxisAlignment.end,
//                                       mainAxisSize: MainAxisSize.max,
//                                       children: [
//                                         Text(
//                                           "00",
//                                           overflow: TextOverflow.ellipsis,
//                                           textAlign:   TextAlign.start,
//                                           style: TextStyle(
//                                             color: ColorConstant.bluegray400,
//                                             fontSize: getFontSize(
//                                               11,
//                                             ),
//                                             fontFamily: 'Gilroy-Regular',
//                                             fontWeight: FontWeight.w500,
//                                           ),
//                                         ),
//                                         Container(
//                                           height: getVerticalSize(
//                                             1.00,
//                                           ),
//                                           width: getHorizontalSize(
//                                             244.00,
//                                           ),
//                                           margin: getMargin(
//                                             left: 20,
//                                             top: 5,
//                                             bottom: 4,
//                                           ),
//                                           decoration: BoxDecoration(
//                                             color: ColorConstant.indigo10019,
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 ),
//                                 Align(
//                                   alignment: Alignment.bottomLeft,
//                                   child: Padding(
//                                     padding: getPadding(
//                                       top: 45,
//                                       bottom: 45,
//                                     ),
//                                     child: Row(
//                                       crossAxisAlignment:
//                                           CrossAxisAlignment.end,
//                                       mainAxisSize: MainAxisSize.max,
//                                       children: [
//                                         Text(
//                                           "50",
//                                           overflow: TextOverflow.ellipsis,
//                                           textAlign:   TextAlign.start,
//                                           style: TextStyle(
//                                             color: ColorConstant.bluegray400,
//                                             fontSize: getFontSize(
//                                               11,
//                                             ),
//                                             fontFamily: 'Gilroy-Regular',
//                                             fontWeight: FontWeight.w500,
//                                           ),
//                                         ),
//                                         Container(
//                                           height: getVerticalSize(
//                                             1.00,
//                                           ),
//                                           width: getHorizontalSize(
//                                             244.00,
//                                           ),
//                                           margin: getMargin(
//                                             left: 21,
//                                             top: 5,
//                                             bottom: 4,
//                                           ),
//                                           decoration: BoxDecoration(
//                                             color: ColorConstant.indigo10019,
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 ),
//                                 Align(
//                                   alignment: Alignment.centerLeft,
//                                   child: Padding(
//                                     padding: getPadding(
//                                       top: 88,
//                                       bottom: 88,
//                                     ),
//                                     child: Row(
//                                       crossAxisAlignment:
//                                           CrossAxisAlignment.end,
//                                       mainAxisSize: MainAxisSize.max,
//                                       children: [
//                                         Text(
//                                           "100",
//                                           overflow: TextOverflow.ellipsis,
//                                           textAlign:   TextAlign.start,
//                                           style: TextStyle(
//                                             color: ColorConstant.bluegray400,
//                                             fontSize: getFontSize(
//                                               11,
//                                             ),
//                                             fontFamily: 'Gilroy-Regular',
//                                             fontWeight: FontWeight.w500,
//                                           ),
//                                         ),
//                                         Container(
//                                           height: getVerticalSize(
//                                             1.00,
//                                           ),
//                                           width: getHorizontalSize(
//                                             244.00,
//                                           ),
//                                           margin: getMargin(
//                                             left: 16,
//                                             top: 5,
//                                             bottom: 4,
//                                           ),
//                                           decoration: BoxDecoration(
//                                             color: ColorConstant.indigo10019,
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 ),
//                                 Align(
//                                   alignment: Alignment.topLeft,
//                                   child: Padding(
//                                     padding: getPadding(
//                                       top: 44,
//                                       bottom: 44,
//                                     ),
//                                     child: Row(
//                                       crossAxisAlignment:
//                                           CrossAxisAlignment.end,
//                                       mainAxisSize: MainAxisSize.max,
//                                       children: [
//                                         Text(
//                                           "300",
//                                           overflow: TextOverflow.ellipsis,
//                                           textAlign:   TextAlign.start,
//                                           style: TextStyle(
//                                             color: ColorConstant.bluegray400,
//                                             fontSize: getFontSize(
//                                               11,
//                                             ),
//                                             fontFamily: 'Gilroy-Regular',
//                                             fontWeight: FontWeight.w500,
//                                           ),
//                                         ),
//                                         Container(
//                                           height: getVerticalSize(
//                                             1.00,
//                                           ),
//                                           width: getHorizontalSize(
//                                             244.00,
//                                           ),
//                                           margin: getMargin(
//                                             left: 14,
//                                             top: 5,
//                                             bottom: 4,
//                                           ),
//                                           decoration: BoxDecoration(
//                                             color: ColorConstant.indigo10019,
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 ),
//                                 Align(
//                                   alignment: Alignment.topLeft,
//                                   child: Padding(
//                                     padding: getPadding(
//                                       top: 1,
//                                       bottom: 10,
//                                     ),
//                                     child: Row(
//                                       crossAxisAlignment:
//                                           CrossAxisAlignment.end,
//                                       mainAxisSize: MainAxisSize.max,
//                                       children: [
//                                         Text(
//                                           "600",
//                                           overflow: TextOverflow.ellipsis,
//                                           textAlign:   TextAlign.start,
//                                           style: TextStyle(
//                                             color: ColorConstant.bluegray400,
//                                             fontSize: getFontSize(
//                                               11,
//                                             ),
//                                             fontFamily: 'Gilroy-Regular',
//                                             fontWeight: FontWeight.w500,
//                                           ),
//                                         ),
//                                         Container(
//                                           height: getVerticalSize(
//                                             1.00,
//                                           ),
//                                           width: getHorizontalSize(
//                                             244.00,
//                                           ),
//                                           margin: getMargin(
//                                             left: 14,
//                                             top: 5,
//                                             bottom: 4,
//                                           ),
//                                           decoration: BoxDecoration(
//                                             color: ColorConstant.indigo10019,
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 ),
//                                 Align(
//                                   alignment: Alignment.centerLeft,
//                                   child: Container(
//                                     height: getVerticalSize(
//                                       178.00,
//                                     ),
//                                     width: getHorizontalSize(
//                                       5.00,
//                                     ),
//                                     margin: getMargin(
//                                       left: 34,
//                                       top: 4,
//                                       right: 34,
//                                       bottom: 7,
//                                     ),
//                                     child: Stack(
//                                       alignment: Alignment.bottomLeft,
//                                       children: [
//                                         Container(
//                                           height: getVerticalSize(
//                                             178.00,
//                                           ),
//                                           width: getHorizontalSize(
//                                             5.00,
//                                           ),
//                                           decoration: BoxDecoration(
//                                             color: ColorConstant.indigo50,
//                                             borderRadius:
//                                                 BorderRadius.circular(
//                                               getHorizontalSize(
//                                                 2.50,
//                                               ),
//                                             ),
//                                           ),
//                                         ),
//                                         Container(
//                                           height: getVerticalSize(
//                                             44.00,
//                                           ),
//                                           width: getHorizontalSize(
//                                             5.00,
//                                           ),
//                                           margin: getMargin(
//                                             top: 10,
//                                           ),
//                                           decoration: BoxDecoration(
//                                             color: ColorConstant.indigoA700,
//                                             borderRadius:
//                                                 BorderRadius.circular(
//                                               getHorizontalSize(
//                                                 2.50,
//                                               ),
//                                             ),
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 ),
//                                 Align(
//                                   alignment: Alignment.centerLeft,
//                                   child: Container(
//                                     height: getVerticalSize(
//                                       178.00,
//                                     ),
//                                     width: getHorizontalSize(
//                                       5.00,
//                                     ),
//                                     margin: getMargin(
//                                       left: 74,
//                                       top: 4,
//                                       right: 74,
//                                       bottom: 7,
//                                     ),
//                                     child: Stack(
//                                       alignment: Alignment.bottomLeft,
//                                       children: [
//                                         Container(
//                                           height: getVerticalSize(
//                                             178.00,
//                                           ),
//                                           width: getHorizontalSize(
//                                             5.00,
//                                           ),
//                                           decoration: BoxDecoration(
//                                             color: ColorConstant.indigo50,
//                                             borderRadius:
//                                                 BorderRadius.circular(
//                                               getHorizontalSize(
//                                                 2.50,
//                                               ),
//                                             ),
//                                           ),
//                                         ),
//                                         Container(
//                                           height: getVerticalSize(
//                                             91.00,
//                                           ),
//                                           width: getHorizontalSize(
//                                             5.00,
//                                           ),
//                                           margin: getMargin(
//                                             top: 10,
//                                           ),
//                                           decoration: BoxDecoration(
//                                             color: ColorConstant.indigoA700,
//                                             borderRadius:
//                                                 BorderRadius.circular(
//                                               getHorizontalSize(
//                                                 2.50,
//                                               ),
//                                             ),
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 ),
//                                 Align(
//                                   alignment: Alignment.centerLeft,
//                                   child: Container(
//                                     height: getVerticalSize(
//                                       178.00,
//                                     ),
//                                     width: getHorizontalSize(
//                                       5.00,
//                                     ),
//                                     margin: getMargin(
//                                       left: 114,
//                                       top: 4,
//                                       right: 114,
//                                       bottom: 7,
//                                     ),
//                                     child: Stack(
//                                       alignment: Alignment.bottomLeft,
//                                       children: [
//                                         Container(
//                                           height: getVerticalSize(
//                                             178.00,
//                                           ),
//                                           width: getHorizontalSize(
//                                             5.00,
//                                           ),
//                                           decoration: BoxDecoration(
//                                             color: ColorConstant.indigo50,
//                                             borderRadius:
//                                                 BorderRadius.circular(
//                                               getHorizontalSize(
//                                                 2.50,
//                                               ),
//                                             ),
//                                           ),
//                                         ),
//                                         Container(
//                                           height: getVerticalSize(
//                                             70.00,
//                                           ),
//                                           width: getHorizontalSize(
//                                             5.00,
//                                           ),
//                                           margin: getMargin(
//                                             top: 10,
//                                           ),
//                                           decoration: BoxDecoration(
//                                             color: ColorConstant.indigoA700,
//                                             borderRadius:
//                                                 BorderRadius.circular(
//                                               getHorizontalSize(
//                                                 2.50,
//                                               ),
//                                             ),
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 ),
//                                 Align(
//                                   alignment: Alignment.centerRight,
//                                   child: Container(
//                                     height: getVerticalSize(
//                                       178.00,
//                                     ),
//                                     width: getHorizontalSize(
//                                       5.00,
//                                     ),
//                                     margin: getMargin(
//                                       left: 119,
//                                       top: 4,
//                                       right: 119,
//                                       bottom: 7,
//                                     ),
//                                     child: Stack(
//                                       alignment: Alignment.bottomLeft,
//                                       children: [
//                                         Container(
//                                           height: getVerticalSize(
//                                             178.00,
//                                           ),
//                                           width: getHorizontalSize(
//                                             5.00,
//                                           ),
//                                           decoration: BoxDecoration(
//                                             color: ColorConstant.indigo50,
//                                             borderRadius:
//                                                 BorderRadius.circular(
//                                               getHorizontalSize(
//                                                 2.50,
//                                               ),
//                                             ),
//                                           ),
//                                         ),
//                                         Container(
//                                           height: getVerticalSize(
//                                             115.00,
//                                           ),
//                                           width: getHorizontalSize(
//                                             5.00,
//                                           ),
//                                           margin: getMargin(
//                                             top: 10,
//                                           ),
//                                           decoration: BoxDecoration(
//                                             color: ColorConstant.indigoA700,
//                                             borderRadius:
//                                                 BorderRadius.circular(
//                                               getHorizontalSize(
//                                                 2.50,
//                                               ),
//                                             ),
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 ),
//                                 Align(
//                                   alignment: Alignment.centerRight,
//                                   child: Container(
//                                     height: getVerticalSize(
//                                       178.00,
//                                     ),
//                                     width: getHorizontalSize(
//                                       5.00,
//                                     ),
//                                     margin: getMargin(
//                                       left: 79,
//                                       top: 4,
//                                       right: 79,
//                                       bottom: 7,
//                                     ),
//                                     child: Stack(
//                                       alignment: Alignment.bottomLeft,
//                                       children: [
//                                         Container(
//                                           height: getVerticalSize(
//                                             178.00,
//                                           ),
//                                           width: getHorizontalSize(
//                                             5.00,
//                                           ),
//                                           decoration: BoxDecoration(
//                                             color: ColorConstant.indigo50,
//                                             borderRadius:
//                                                 BorderRadius.circular(
//                                               getHorizontalSize(
//                                                 2.50,
//                                               ),
//                                             ),
//                                           ),
//                                         ),
//                                         Container(
//                                           height: getVerticalSize(
//                                             144.00,
//                                           ),
//                                           width: getHorizontalSize(
//                                             5.00,
//                                           ),
//                                           margin: getMargin(
//                                             top: 10,
//                                           ),
//                                           decoration: BoxDecoration(
//                                             color: ColorConstant.indigoA700,
//                                             borderRadius:
//                                                 BorderRadius.circular(
//                                               getHorizontalSize(
//                                                 2.50,
//                                               ),
//                                             ),
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 ),
//                                 Align(
//                                   alignment: Alignment.centerRight,
//                                   child: Container(
//                                     height: getVerticalSize(
//                                       178.00,
//                                     ),
//                                     width: getHorizontalSize(
//                                       5.00,
//                                     ),
//                                     margin: getMargin(
//                                       left: 39,
//                                       top: 4,
//                                       right: 39,
//                                       bottom: 7,
//                                     ),
//                                     child: Stack(
//                                       alignment: Alignment.bottomLeft,
//                                       children: [
//                                         Container(
//                                           height: getVerticalSize(
//                                             178.00,
//                                           ),
//                                           width: getHorizontalSize(
//                                             5.00,
//                                           ),
//                                           decoration: BoxDecoration(
//                                             color: ColorConstant.indigo50,
//                                             borderRadius:
//                                                 BorderRadius.circular(
//                                               getHorizontalSize(
//                                                 2.50,
//                                               ),
//                                             ),
//                                           ),
//                                         ),
//                                         Container(
//                                           height: getVerticalSize(
//                                             80.00,
//                                           ),
//                                           width: getHorizontalSize(
//                                             5.00,
//                                           ),
//                                           margin: getMargin(
//                                             top: 10,
//                                           ),
//                                           decoration: BoxDecoration(
//                                             color: ColorConstant.indigoA700,
//                                             borderRadius:
//                                                 BorderRadius.circular(
//                                               getHorizontalSize(
//                                                 2.50,
//                                               ),
//                                             ),
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 ),
//                                 Align(
//                                   alignment: Alignment.centerRight,
//                                   child: Container(
//                                     height: getVerticalSize(
//                                       178.00,
//                                     ),
//                                     width: getHorizontalSize(
//                                       5.00,
//                                     ),
//                                     margin: getMargin(
//                                       left: 10,
//                                       top: 4,
//                                       bottom: 7,
//                                     ),
//                                     child: Stack(
//                                       alignment: Alignment.bottomLeft,
//                                       children: [
//                                         Container(
//                                           height: getVerticalSize(
//                                             178.00,
//                                           ),
//                                           width: getHorizontalSize(
//                                             5.00,
//                                           ),
//                                           decoration: BoxDecoration(
//                                             color: ColorConstant.indigo50,
//                                             borderRadius:
//                                                 BorderRadius.circular(
//                                               getHorizontalSize(
//                                                 2.50,
//                                               ),
//                                             ),
//                                           ),
//                                         ),
//                                         Container(
//                                           height: getVerticalSize(
//                                             111.00,
//                                           ),
//                                           width: getHorizontalSize(
//                                             5.00,
//                                           ),
//                                           margin: getMargin(
//                                             top: 10,
//                                           ),
//                                           decoration: BoxDecoration(
//                                             color: ColorConstant.indigoA700,
//                                             borderRadius:
//                                                 BorderRadius.circular(
//                                               getHorizontalSize(
//                                                 2.50,
//                                               ),
//                                             ),
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                         Align(
//                           alignment: Alignment.centerRight,
//                           child: Padding(
//                             padding: getPadding(
//                               left: 10,
//                               top: 4,
//                               bottom: 24,
//                             ),
//                             child: Row(
//                               mainAxisAlignment: MainAxisAlignment.end,
//                               crossAxisAlignment: CrossAxisAlignment.center,
//                               mainAxisSize: MainAxisSize.max,
//                               children: [
//                                 Text(
//                                   "S",
//                                   overflow: TextOverflow.ellipsis,
//                                   textAlign:   TextAlign.start,
//                                   style: TextStyle(
//                                     color: ColorConstant.bluegray400,
//                                     fontSize: getFontSize(
//                                       11,
//                                     ),
//                                     fontFamily: 'Gilroy-Regular',
//                                     fontWeight: FontWeight.w500,
//                                   ),
//                                 ),
//                                 Padding(
//                                   padding: getPadding(
//                                     left: 33,
//                                   ),
//                                   child: Text(
//                                     "S",
//                                     overflow: TextOverflow.ellipsis,
//                                     textAlign:   TextAlign.start,
//                                     style: TextStyle(
//                                       color: ColorConstant.bluegray400,
//                                       fontSize: getFontSize(
//                                         11,
//                                       ),
//                                       fontFamily: 'Gilroy-Regular',
//                                       fontWeight: FontWeight.w500,
//                                     ),
//                                   ),
//                                 ),
//                                 Padding(
//                                   padding: getPadding(
//                                     left: 32,
//                                   ),
//                                   child: Text(
//                                     "M",
//                                     overflow: TextOverflow.ellipsis,
//                                     textAlign:   TextAlign.start,
//                                     style: TextStyle(
//                                       color: ColorConstant.bluegray400,
//                                       fontSize: getFontSize(
//                                         11,
//                                       ),
//                                       fontFamily: 'Gilroy-Regular',
//                                       fontWeight: FontWeight.w500,
//                                     ),
//                                   ),
//                                 ),
//                                 Padding(
//                                   padding: getPadding(
//                                     left: 32,
//                                   ),
//                                   child: Text(
//                                     "T",
//                                     overflow: TextOverflow.ellipsis,
//                                     textAlign:   TextAlign.start,
//                                     style: TextStyle(
//                                       color: ColorConstant.bluegray400,
//                                       fontSize: getFontSize(
//                                         11,
//                                       ),
//                                       fontFamily: 'Gilroy-Regular',
//                                       fontWeight: FontWeight.w500,
//                                     ),
//                                   ),
//                                 ),
//                                 Padding(
//                                   padding: getPadding(
//                                     left: 32,
//                                   ),
//                                   child: Text(
//                                     "W",
//                                     overflow: TextOverflow.ellipsis,
//                                     textAlign:   TextAlign.start,
//                                     style: TextStyle(
//                                       color: ColorConstant.bluegray400,
//                                       fontSize: getFontSize(
//                                         11,
//                                       ),
//                                       fontFamily: 'Gilroy-Regular',
//                                       fontWeight: FontWeight.w500,
//                                     ),
//                                   ),
//                                 ),
//                                 Padding(
//                                   padding: getPadding(
//                                     left: 31,
//                                   ),
//                                   child: Text(
//                                     "T",
//                                     overflow: TextOverflow.ellipsis,
//                                     textAlign:   TextAlign.start,
//                                     style: TextStyle(
//                                       color: ColorConstant.bluegray400,
//                                       fontSize: getFontSize(
//                                         11,
//                                       ),
//                                       fontFamily: 'Gilroy-Regular',
//                                       fontWeight: FontWeight.w500,
//                                     ),
//                                   ),
//                                 ),
//                                 Padding(
//                                   padding: getPadding(
//                                     left: 34,
//                                   ),
//                                   child: Text(
//                                     "F",
//                                     overflow: TextOverflow.ellipsis,
//                                     textAlign: TextAlign.center,
//                                     style: TextStyle(
//                                       color: ColorConstant.bluegray400,
//                                       fontSize: getFontSize(
//                                         11,
//                                       ),
//                                       fontFamily: 'Gilroy-Regular',
//                                       fontWeight: FontWeight.w500,
//                                     ),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
                