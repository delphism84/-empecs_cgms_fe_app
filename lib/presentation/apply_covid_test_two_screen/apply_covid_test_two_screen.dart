 import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:helpcare/core/app_export.dart';
import 'package:helpcare/presentation/applysuccessdialog_page/applysuccessdialog_page.dart';
import 'package:helpcare/widgets/custom_button.dart';
import 'package:helpcare/widgets/custom_icon_button.dart';
import 'package:helpcare/widgets/spacing.dart';
import '../../data/symptoms_list.dart';

class ApplyCovidTestTwoScreen extends StatefulWidget {
  const ApplyCovidTestTwoScreen({super.key});

  @override
  State<ApplyCovidTestTwoScreen> createState() => _ApplyCovidTestTwoScreenState();
}

class _ApplyCovidTestTwoScreenState extends State<ApplyCovidTestTwoScreen> {
  List<int> selected=[];

  @override
    Widget build(BuildContext context) {
    bool isDark =Theme.of(context).brightness==Brightness.dark;
bool isRtl = context.locale==Constants.arLocal;
    return Scaffold(
        body: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
            children: [
                 Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                   children: [
                     CustomIconButton(
                      isDark:isDark,
                      height: 50,
                      width: 50,
                      margin: getMargin(
                        left: 24,
                        top: 20,
                        right: 24,
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
                   ],
                 ),
               
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                   
                      Padding(
                        padding: getPadding(
                          left: 24,
                          top: 20,
                          right: 24,
                        ),
                        child: Text(
                          "Your CGMS Symptoms",
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
                      Container(
                        height: getVerticalSize(
                          2.00,
                        ),
                        width: getHorizontalSize(
                          44.00,
                        ),
                        margin: getMargin(
                          left: 24,
                          top: 13,
                          right: 24,
                        ),
                        decoration: BoxDecoration(
                          color: isDark?Colors.white:Colors.black,
                            
                          borderRadius: BorderRadius.circular(
                            getHorizontalSize(
                              1.00,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: getPadding(
                          left: 24,
                          top: 19,
                          right: 24,
                        ),
                        child: Text(
                          "Let us know about your symptoms",
                          overflow: TextOverflow.ellipsis,
                          textAlign:   TextAlign.start,
                          style: TextStyle(
                              
                            fontSize: getFontSize(
                              14,
                            ),
                            fontFamily: 'Gilroy-Medium',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    
                     
                    ListView.separated(
                      padding: getPadding(
                        top: 10
                      ),
                      physics: const BouncingScrollPhysics(),
                      separatorBuilder: (context,index){
                        return VerticalSpace(height: 22);
                      },
                      shrinkWrap: true,
                      itemCount: symptomsList.length,
                      itemBuilder: (context,index){
                      return    Align(
                        alignment: Alignment.center,
                        child: InkWell(
                          onTap: (){
                            if(selected.contains(index))
                            {
                             setState(() {
                                selected.remove(index);
                             });
                            }
                            else {
                              setState(() {
                              selected.add(index);
                            });
                            }
                            
                          },
                          child: Container(
                            margin: getMargin(
                              left: 24,
                              top: 0,
                              right: 24,
                            ),
                            padding: getPadding(
                              left: 20,
                              right: 20
                            ),
                            decoration: BoxDecoration(
                              color:selected.contains(index)?isDark?ColorConstant.darkChoice: ColorConstant.indigo50 : 
                              isDark?Colors.transparent:ColorConstant.whiteA700,
                              borderRadius: BorderRadius.circular(
                                getHorizontalSize(
                                  6.00,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Padding(
                                  padding: getPadding(
                                    top: 21,
                                    bottom: 20,
                                  ),
                                  child: Text(
                                    symptomsList[index],
                                    overflow: TextOverflow.ellipsis,
                                    textAlign:   TextAlign.start,
                                    style: TextStyle(
                                      color: selected.contains(index)?ColorConstant.indigoA700:isDark?Colors.white:Colors.black,
                                        
                                      fontSize: getFontSize(
                                        14,
                                      ),
                                      fontFamily: 'Gilroy-Medium',
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                               selected.contains(index)? Container(
                            padding: getPadding(
                              left: 6,
                              top: 7,
                              right: 6,
                              bottom: 8,
                            ),
                            margin: getMargin(
                              left: 0,
                              top: 15,
                              right: 0,
                              bottom: 15,
                            ),
                            decoration: BoxDecoration(
                              color: ColorConstant.indigoA700,
                              borderRadius: BorderRadius.circular(
                                getHorizontalSize(
                                  4.00,
                                ),
                              ),
                            ),
                            child: CommonImageView(
                              svgPath: ImageConstant.imgVectorWhiteA7005X8,
                            ),
                          )
                                              : Container(
                                  height: getSize(
                                    20.00,
                                  ),
                                  width: getSize(
                                    20.00,
                                  ),
                                  margin: getMargin(
                                    top: 18,
                                    bottom: 18,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      getHorizontalSize(
                                        4.00,
                                      ),
                                    ),
                                    border: Border.all(
                                      color: isDark?Colors.white:Colors.black,
                                        
                                      width: getHorizontalSize(
                                        1.00,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                     
                    })
                   , CustomButton(
                            width: 325,
                            text: "Aplly now".toUpperCase(),
                            margin: getMargin(
                              left: 1,
                              top: 20,
                              bottom: 20,
                              right: 8,
                            ),
                            alignment: Alignment.center,
                            onTap: (){
                             showDialog(
        context: context,
        builder: (_) => const ApplysuccessdialogPage()
    );
                            },
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
