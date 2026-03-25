import 'package:flutter/material.dart';
import 'package:helpcare/core/app_export.dart';
import 'package:helpcare/core/utils/ble_service.dart';
import 'package:helpcare/core/utils/app_nav.dart';
import 'package:helpcare/widgets/custom_button.dart';

class Sc0101BtStepScreen extends StatelessWidget {
  const Sc0101BtStepScreen({super.key});

  Future<void> _goBack(BuildContext context) async {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }
    // If opened without a back stack (e.g., QA nav replace), fallback to SC_01_01 scan page.
    await AppNav.goNamed('/sc/01/01/scan', replaceStack: true);
  }

  Future<void> _onSensorConnect(BuildContext context) async {
    await BleService().startWarmupAndNavigate();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('BT Connect Guide'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _goBack(context),
          tooltip: 'Back',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? ColorConstant.darkTextField : Colors.white,
                    border: Border.all(color: ColorConstant.indigo51, width: 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Image.asset(
                    'docs/btstep.png',
                    fit: BoxFit.fitWidth,
                    width: double.infinity,
                    errorBuilder: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('Guide image not found')),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: CustomButton(
                  width: double.infinity,
                  text: 'Sensor Connect',
                  variant: ButtonVariant.FillLoginGreen,
                  onTap: () => _onSensorConnect(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

