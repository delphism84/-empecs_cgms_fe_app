import 'package:flutter/material.dart';
import 'package:helpcare/core/app_export.dart';
import 'package:helpcare/widgets/spacing.dart';

// ignore: must_be_immutable
class ListcabinroomItemWidget extends StatelessWidget {
  const ListcabinroomItemWidget({super.key});

  @override
    Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: getPadding(
          top: 13.4649965,
          right: 2,
          bottom: 13.4649965,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            Padding(
              padding: getPadding(
                top: 1,
              ),
              child: Text(
                "Cabin Room",
                overflow: TextOverflow.ellipsis,
                textAlign:   TextAlign.start,
                style: TextStyle(
                  color: ColorConstant.indigoA700,
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
                left: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: getPadding(
                      top: 1,
                    ),
                    child: Text(
                      "20",
                      overflow: TextOverflow.ellipsis,
                      textAlign:   TextAlign.start,
                      style: TextStyle(
                        color: ColorConstant.indigoA700,
                        fontSize: getFontSize(
                          12,
                        ),
                        fontFamily: 'Gilroy-Medium',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                HorizontalSpace(width: 30),
                 Padding(
                    padding: getPadding(
                      left: 0,
                      bottom: 1,
                    ),
                    child: Text(
                      "12",
                      overflow: TextOverflow.ellipsis,
                      textAlign:   TextAlign.start,
                      style: TextStyle(
                        color: ColorConstant.indigoA700,
                        fontSize: getFontSize(
                          12,
                        ),
                        fontFamily: 'Gilroy-Medium',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
