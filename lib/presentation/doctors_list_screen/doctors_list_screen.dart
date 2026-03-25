import 'package:helpcare/data/doctors_list.dart';
import 'package:helpcare/presentation/search_screen/search_screen.dart';
import '../doctors_list_screen/widgets/listintersect_item_widget.dart';
 import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:helpcare/core/app_export.dart';
import 'package:helpcare/widgets/custom_icon_button.dart';

class DoctorsListScreen extends StatelessWidget {
  const DoctorsListScreen({super.key});

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
                          
                          left: 20,
                        right: 20,
                        top: 20
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            CustomIconButton(isDark:isDark,
                              height: 50,
                              width: 50,
                              margin: getMargin(
                                top: 1,
                              ),
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
                                top: 13,
                                bottom: 17,
                              ),
                              child: Text(
                                "Doctors",
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
                            CustomIconButton(isDark:isDark,
                              height: 50,
                              width: 50,
                              onTap: (){
                                Navigator.push(
    context,
    MaterialPageRoute(builder: (context)
 =>const SearchScreen()),
  );
                              },
                              margin: getMargin(
                                bottom: 1,
                              ),
                              child: CommonImageView(
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
                          top: 0,
                        ),
                        child: ListView.builder(
                          padding: getPadding(
                              left: 20,
                        right: 20,
                          ),
                          physics: const BouncingScrollPhysics(),
                          shrinkWrap: true,
                          itemCount: doctorsList.length,
                          itemBuilder: (context, index) {
                            return ListintersectItemWidget(index: index,);
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
