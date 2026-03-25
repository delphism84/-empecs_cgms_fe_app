import 'package:helpcare/data/notificationList.dart';

import '../notification_screen/widgets/listplus_item_widget.dart';
import '../notification_screen/widgets/listsearch_item_widget.dart';
 import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:helpcare/core/app_export.dart';
import 'package:helpcare/widgets/custom_icon_button.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
    Widget build(BuildContext context) {
    bool isDark =Theme.of(context).brightness==Brightness.dark;
bool isRtl = context.locale==Constants.arLocal;
    return Scaffold(
       
        body: SafeArea(
          child: Column(
            children: [
               Container(
                margin: getMargin(
                  top: 20,
                  left: 20,
                  bottom: 10,
                  right: 20
                ),
                      width: size.width,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          CustomIconButton(isDark:isDark,
                                height: 50,
                                width: 50,
                                onTap: () {
                                  Navigator.pop(context);
                                },
                                child: CommonImageView(
                                  isBackBtn: true,
        
                            isRtl: isRtl,
                           isDark: isDark,
                            svgPath: ImageConstant.imgArrowleft,
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: getPadding(
                                    left: 12,
                                    top: 12,
                                    bottom: 17,
                                  ),
                                  child: Text(
                                    "Notifications",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.start,
                                    style: TextStyle(
                                      fontSize: getFontSize(20),
                                      fontFamily: 'Gilroy-Medium',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                           
                          
                          Padding(
                            padding: getPadding(
                              top: 23,
                              bottom: 24,
                            ),
                            child: CommonImageView(
                              isDark: isDark,
                              svgPath: ImageConstant.imgOption,
                              height: getVerticalSize(
                                3.00,
                              ),
                              width: getHorizontalSize(
                                17.00,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
              Expanded(
                child: ListView(
                  padding: getPadding(left: 24, right: 24, top: 10, bottom: 12),
                  children: [
                    Text(
                      "New",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.start,
                      style: TextStyle(
                        fontSize: getFontSize(18),
                        fontFamily: 'Gilroy-Medium',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const ListsearchItemWidget(),
                    const SizedBox(height: 22),
                    Text(
                      "Earlier",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.start,
                      style: TextStyle(
                        fontSize: getFontSize(18),
                        fontFamily: 'Gilroy-Medium',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(notificationList.length, (index) => ListplusItemWidget(index: index)),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      
    );
  }
}
