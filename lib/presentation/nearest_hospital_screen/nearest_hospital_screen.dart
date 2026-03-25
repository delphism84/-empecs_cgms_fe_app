import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:helpcare/presentation/hospital_list_screen/hospital_list_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:helpcare/core/app_export.dart';
import 'package:helpcare/widgets/custom_button.dart';
import 'package:helpcare/widgets/custom_icon_button.dart';
import 'package:helpcare/widgets/custom_text_form_field.dart';

class NearestHospitalScreen extends StatefulWidget {
  const NearestHospitalScreen({super.key});

  @override
  State<NearestHospitalScreen> createState() => _NearestHospitalScreenState();
}

class _NearestHospitalScreenState extends State<NearestHospitalScreen> {
  final Completer<GoogleMapController> _controller = Completer();

  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962),
    zoom: 14.4746,
  );
  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    bool isRtl = context.locale == Constants.arLocal;
    return Scaffold(
        body: SafeArea(
            child: SizedBox(
      height: size.height,
      width: size.width,
      child: SingleChildScrollView(
        child: Column(children: [
          SizedBox(
            height: size.height - getVerticalSize(107),
            width: size.width,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                SizedBox(
                  // imagePath:isDark?ImageConstant.darkMap: ImageConstant.imgScreenshot2022,
                  height: size.height - getVerticalSize(107),

                  width: size.width,
                  child: GoogleMap(
                    mapType: MapType.normal,
                    initialCameraPosition: _kGooglePlex,
                    onMapCreated: (GoogleMapController controller) {
                      _controller.complete(controller);
                    },
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Container(
                        width: size.width,
                        margin: getMargin(
                          left: 24,
                          top: 40,
                          right: 24,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            CustomIconButton(
                              isDark: isDark,
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
                                left: 20,
                                right: 20,
                                top: 14,
                                bottom: 15,
                              ),
                              child: Text(
                                "Nearest Hospital",
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
                            ),
                          ],
                        ),
                      ),
                      CustomTextFormField(
                        isDark: isDark,
                        width: 325,
                        focusNode: FocusNode(),
                        hintText: "Akhalia Sylhet, Bangladesh",
                        margin: getMargin(
                          left: 24,
                          top: 24,
                          right: 24,
                        ),
                        padding: TextFormFieldPadding.PaddingT19,
                        fontStyle:
                            TextFormFieldFontStyle.GilroyMedium14Bluegray400,
                        textInputAction: TextInputAction.done,
                        alignment: Alignment.center,
                        suffix: Container(
                          margin: getMargin(
                            left: 30,
                            top: 22,
                            right: 22,
                            bottom: 22,
                          ),
                          child: CommonImageView(
                            svgPath: ImageConstant.imgClose12X12,
                          ),
                        ),
                        suffixConstraints: BoxConstraints(
                          minWidth: getHorizontalSize(
                            12.00,
                          ),
                          minHeight: getVerticalSize(
                            12.00,
                          ),
                        ),
                      ),

                      //                 ],
                      //               ),
                      //             ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          CustomButton(
            width: 325,
            text: "SEE ALL HOSPITALS".toUpperCase(),
            margin: getMargin(
              left: 24,
              top: 10,
              right: 24,
              bottom: 12,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HospitalListScreen()),
              );
            },
            alignment: Alignment.center,
          ),
        ]),
      ),
    )));
  }
}
