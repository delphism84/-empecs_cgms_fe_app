import 'package:helpcare/data/hospital_list.dart';
import 'package:helpcare/presentation/search_screen/search_screen.dart';

import '../hospital_list_screen/widgets/listrectangle105_item_widget.dart';
 import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:helpcare/core/app_export.dart';
import 'package:helpcare/widgets/custom_icon_button.dart';

class HospitalListScreen extends StatelessWidget {
  const HospitalListScreen({super.key});

  @override
    Widget build(BuildContext context) {
    bool isDark =Theme.of(context).brightness==Brightness.dark;
bool isRtl = context.locale==Constants.arLocal;
    return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
                Container(
                      width: size.width,
                      margin: getMargin(
                        top: 20,
                        bottom: 10,
                        left: 20,
                        right: 20
                      ),
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
                          Padding(
                            padding: getPadding(
                              top: 14,
                              bottom: 15,
                            ),
                            child: Text(
                              "Hospitals",
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
                          CustomIconButton(
                            onTap: (){
                              Navigator.push(
            context,
            MaterialPageRoute(builder: (context)
         =>const SearchScreen()),
          );
                            },
                            isDark:isDark,
                            height: 50,
                            width: 50,
                            child: CommonImageView(
                              isDark: isDark,
                              svgPath: ImageConstant.imgSearchBluegray400,
                            ),
                          ),
                        ],
                      ),
                    ),
                   
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                     
                      Padding(
                        padding: getPadding(
                          top: 5,
                        ),
                        child: ListView.builder(
                          padding: getPadding(
                            left: 24,
                            right: 24
                          ),
                          physics: const BouncingScrollPhysics(),
                          shrinkWrap: true,
                          itemCount: hospitalList.length,
                          itemBuilder: (context, index) {
                            return Listrectangle105ItemWidget(index: index);
                          },
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
