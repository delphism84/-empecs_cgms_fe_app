import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:easy_localization/easy_localization.dart';
// removed unused imports
import 'package:helpcare/presentation/chart_page/trend_tab_page.dart';
// kept for explicit ChartPage references elsewhere if any
// import removed (not directly used here)
// trend 탭은 TrendTabPage 사용
import 'package:helpcare/presentation/sensor_page/sensor_page.dart';
import 'package:helpcare/presentation/settings_page/settings_page.dart';
import 'package:helpcare/presentation/report/cgms_report_screen.dart';
import 'package:helpcare/presentation/dashboard/main_dashboard.dart';
import 'package:helpcare/presentation/alerts/alerts_root.dart';
import 'package:helpcare/core/utils/focus_bus.dart';

import '../core/app_export.dart';
import 'package:helpcare/widgets/gradient_icon.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
   List<Widget> screens=[
    // IndexedStack 비가시 탭은 기본 TickerMode off — 대시보드는 혈당 스트림·토스트 애니 항상 동작
    const TickerMode(enabled: true, child: MainDashboardPage()),
    const TrendTabPage(),  // Trend tab
    const CgmsReportScreen(),    // RP_01_01 리포트 별도 페이지
    const SensorPage(),          // SC_02_01
    const AlertsRootPage(),      // AR_01_01
    const SettingsPage(),        // Settings root
  ];

  bool pop=false;
  
 
  int selectedNavBarIndex=0;
  @override
  void initState() {
    super.initState();
    HomeTab.index.addListener(_onTabChange);
  }

  @override
  void dispose() {
    HomeTab.index.removeListener(_onTabChange);
    super.dispose();
  }

  void _onTabChange() {
    if (!mounted) return;
    setState(() { selectedNavBarIndex = HomeTab.index.value.clamp(0, screens.length-1); });
  }
  
  
  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final double width = MediaQuery.sizeOf(context).width;
    final bool narrow = width < 400 || kIsWeb && width < 520;
    return Scaffold(
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          final exit = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              content: Text(
                'exit_app_body'.tr(),
                style: TextStyle(fontSize: 13, fontFamily: 'Poppins', color: isDark ? Colors.white : Colors.black),
              ),
              title: Text(
                'exit_app_title'.tr(),
                style: TextStyle(fontSize: 13, fontFamily: 'Poppins', color: isDark ? Colors.white : Colors.black),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text('common_no'.tr(), style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13, fontFamily: 'Poppins')),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text('common_yes'.tr(), style: TextStyle(color: Colors.red, fontSize: 13, fontFamily: 'Poppins')),
                ),
              ],
            ),
          );
          if (exit == true && context.mounted && !kIsWeb) {
            SystemNavigator.pop();
          }
        },
        child: IndexedStack(
          index: selectedNavBarIndex,
          children: screens,
        ),
      ),
     bottomNavigationBar: BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Theme.of(context).colorScheme.primary,
      unselectedItemColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
      showSelectedLabels: true,
      showUnselectedLabels: true,
      selectedFontSize: narrow ? 10 : 12,
      unselectedFontSize: narrow ? 10 : 12,
      backgroundColor: isDark ? ColorConstant.darkBg : Colors.white,
      // selectedItemColor:isDark?ColorConstant.darkBlue: ColorConstant.blue900 ,
      // unselectedItemColor:ColorConstant.bluegray300 ,
     
      
        selectedLabelStyle: TextStyle(
         
          fontSize: getFontSize(
            12,
          ),
            fontFamily: "Gilroy-Medium",
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: TextStyle(
          // color: ColorConstant.gray600,
          fontSize: getFontSize(
            12,
          ),
            fontFamily: "Gilroy-Medium",
          fontWeight: FontWeight.w500,
        ),
        currentIndex: selectedNavBarIndex,
        onTap: (index){
          setState(() {
           
           selectedNavBarIndex=index;
          });
         
        },
        items: [
          BottomNavigationBarItem(
            icon: Opacity(opacity: 0.4, child: GradientIcon(Icons.home_outlined, gradient: AppIconGradients.resolve(Icons.home_outlined))),
            activeIcon: GradientIcon(Icons.home_rounded, gradient: AppIconGradients.resolve(Icons.home_rounded)),
            label: tr('nav_home'),
          ),
          BottomNavigationBarItem(
            icon: Opacity(opacity: 0.4, child: GradientIcon(Icons.timeline, gradient: AppGradients.primary)),
            activeIcon: GradientIcon(Icons.timeline, gradient: AppGradients.primary),
            label: tr('nav_trend'),
          ),
          BottomNavigationBarItem(
            icon: Opacity(opacity: 0.4, child: GradientIcon(Icons.description_outlined, gradient: AppIconGradients.resolve(Icons.description_outlined))),
            activeIcon: GradientIcon(Icons.description, gradient: AppIconGradients.resolve(Icons.description)),
            label: tr('nav_report'),
          ),
          BottomNavigationBarItem(
            icon: Opacity(opacity: 0.4, child: GradientIcon(Icons.sensors, gradient: AppGradients.primary)),
            activeIcon: GradientIcon(Icons.sensors, gradient: AppGradients.primary),
            label: tr('nav_sensor'),
          ),
          BottomNavigationBarItem(
            icon: Opacity(opacity: 0.4, child: GradientIcon(Icons.notifications_none, gradient: AppGradients.primary)),
            activeIcon: GradientIcon(Icons.notifications, gradient: AppGradients.primary),
            label: tr('nav_alarm'),
          ),
          BottomNavigationBarItem(
            icon: Opacity(opacity: 0.4, child: GradientIcon(Icons.settings, gradient: AppIconGradients.resolve(Icons.settings))),
            activeIcon: GradientIcon(Icons.settings, gradient: AppIconGradients.resolve(Icons.settings)),
            label: tr('nav_settings'),
          ),
        ],
      ),
    );
  }
}