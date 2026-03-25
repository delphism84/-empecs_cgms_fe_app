import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:helpcare/core/utils/focus_bus.dart';
import 'package:helpcare/core/utils/settings_storage.dart';

import '../../../core/app_export.dart';
import '../../../widgets/spacing.dart';


class LightSettingsLanguageScreen extends StatefulWidget {
  const LightSettingsLanguageScreen({super.key});

  @override
  State<LightSettingsLanguageScreen> createState() =>
      _LightSettingsLanguageScreenState();
}

class _LightSettingsLanguageScreenState
    extends State<LightSettingsLanguageScreen> {
  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    bool isRtl = context.locale == Constants.arLocal;
    int radioGroup = isRtl ? 1 : 0;
    return SizedBox(
        height: getVerticalSize(500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
             Container(
                                                height: getVerticalSize(
                                                  3.00,
                                                ),
                                                width: getHorizontalSize(
                                                  56.00,
                                                ),
                                                margin: EdgeInsets.only(
                                                  left: getHorizontalSize(
                                                    10.00,
                                                  ),
                                                  top: getVerticalSize(
                                                    16.00,
                                                  ),
                                                  right: getHorizontalSize(
                                                    10.00,
                                                  ),
                                                ),
                                                decoration: BoxDecoration(
                                                  color:isDark?ColorConstant.darkTextField: ColorConstant.gray300,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                    getHorizontalSize(
                                                      1.50,
                                                    ),
                                                  ),
                                                ),
                                              ),
              
            Align(
              alignment: Alignment.center,
              child: Padding(
                  padding: getPadding(
                    left: 20,
                    top: 30,
                    right: 20,
                  ),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Padding(
                          padding: getPadding(
                            bottom: 2,
                          ),
                          child: Text(
                           "Language",
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.start,
                            style: TextStyle(
                              fontFamily: 'Gilroy-Medium',
                              fontSize: getFontSize(16),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                       
                        InkWell(
                          onTap: (){
                            Navigator.pop(context);
                          },
                          child: CommonImageView(
                            isDark: isDark,
                            svgPath: ImageConstant.imgClose,
                            height: getVerticalSize(
                              18.00,
                            ),
                            width: getHorizontalSize(
                              18.00,
                            ),
                          ),
                        )
                      ]))),
     Container(
      height: 1,
      margin: getMargin(
       
        left: 20,
        right: 20,
        top: 20,
        bottom: 20
      ),
      color: ColorConstant.darkLine,
     ),
           
            // Padding(
            //   padding: getPadding(
            //     left: 24,
            //     top: 33,
            //     right: 24,
            //   ),
            //   child: Text(
            //     "Suggested",
            //     overflow: TextOverflow.ellipsis,
            //     textAlign: TextAlign.start,
            //     style: TextStyle(
            //       fontSize: getFontSize(
            //         20,
            //       ),
            //         fontFamily: "Montserrat",
            //       fontWeight: FontWeight.w700,
            //     ),
            //   ),
            // ),
           
           VerticalSpace(height: 20),
            Align(
              alignment: Alignment.center,
              child: Padding(
                padding: getPadding(
                  left: 24,
                  top: 10,
                  bottom: 10,
                  right: 24,
                ),
                child: InkWell(
                  onTap: () async {
                    setState(() { radioGroup = 0; });
                    await context.setLocale(const Locale("en"));
                    try {
                      final s = await SettingsStorage.load();
                      s['language'] = 'en';
                      await SettingsStorage.save(s);
                      AppSettingsBus.notify();
                    } catch (_) {}
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Text(
                        "English (US)",
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.start,
                        style: TextStyle(
                              fontFamily: 'Gilroy-Medium',
                              fontSize: getFontSize(14),
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      Theme(
                        data: Theme.of(context).copyWith(
                          unselectedWidgetColor: ColorConstant.indigoA700,
                          // disabledColor: Colors.blue
                        ),
                        child: Radio(
                          value: 0,
                          activeColor: ColorConstant.indigoA700,
                          groupValue: radioGroup,
                          onChanged: (value) async {
                            setState(() { radioGroup = 0; });
                            await context.setLocale(const Locale("en"));
                            try {
                              final s = await SettingsStorage.load();
                              s['language'] = 'en';
                              await SettingsStorage.save(s);
                              AppSettingsBus.notify();
                            } catch (_) {}
                          },
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
                  top: 10,
                  bottom: 10,
                  right: 24,
                ),
                child: InkWell(
                  onTap: () async {
                    setState(() { radioGroup = 1; });
                    await context.setLocale(const Locale("ar"));
                    try {
                      final s = await SettingsStorage.load();
                      s['language'] = 'ar';
                      await SettingsStorage.save(s);
                      AppSettingsBus.notify();
                    } catch (_) {}
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Text(
                        "العربية",
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.start,
                        style: TextStyle(
                              fontFamily: 'Gilroy-Medium',
                              fontSize: getFontSize(14),
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      Theme(
                        data: Theme.of(context).copyWith(
                          unselectedWidgetColor: ColorConstant.indigoA700,
                          // disabledColor: Colors.blue
                        ),
                        child: Radio(
                          value: 1,
                          activeColor: ColorConstant.indigoA700,
                          groupValue: radioGroup,
                          onChanged: (value) {
                            setState(() { radioGroup = value as int; });
                            () async {
                              await context.setLocale(const Locale("ar"));
                              try {
                                final s = await SettingsStorage.load();
                                s['language'] = 'ar';
                                await SettingsStorage.save(s);
                                AppSettingsBus.notify();
                              } catch (_) {}
                            }();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      
    );
  }
}