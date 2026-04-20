import 'package:flutter/material.dart';
import 'package:helpcare/core/utils/image_constant.dart';
import 'package:helpcare/core/config/app_constants.dart';
import 'package:helpcare/core/utils/settings_storage.dart';
import 'package:easy_localization/easy_localization.dart';

class SensorRemovePage extends StatelessWidget {
  const SensorRemovePage({super.key});

  @override
  Widget build(BuildContext context) {
    // evidence marker (best-effort)
    () async {
      try {
        final st = await SettingsStorage.load();
        st['sc0801ViewedAt'] = DateTime.now().toUtc().toIso8601String();
        await SettingsStorage.save(st);
      } catch (_) {}
    }();
    // removed unused theme variable
    return Scaffold(
      appBar: AppBar(title: Text('sensor_remove_title'.tr())),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/images/remove.png',
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Image.asset(ImageConstant.imageNotFound, width: double.infinity, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 16),
              _card(
                context,
                leading: Icons.info_outline,
                title: 'sensor_remove_heading'.tr(),
                body: 'sensor_remove_intro'.tr(args: <String>[AppConstants.defaultSensorValidityDays.toString()]),
              ),
              _card(
                context,
                leading: Icons.format_list_numbered,
                title: 'sensor_remove_steps_title'.tr(),
                children: [
                  _step(context, 'sensor_remove_step1'.tr()),
                  _step(context, 'sensor_remove_step2'.tr()),
                  _step(context, 'sensor_remove_step3'.tr()),
                ],
              ),
              _card(
                context,
                leading: Icons.warning_amber_rounded,
                title: 'sensor_remove_caution_title'.tr(),
                body: 'sensor_remove_caution_body'.tr(),
              ),
              _card(
                context,
                leading: Icons.link_off,
                title: 'sensor_remove_early_title'.tr(),
                body: 'sensor_remove_early_body'.tr(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, {required IconData leading, required String title, String? body, List<Widget>? children}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1D1D1D) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(leading, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
        ]),
        if (body != null) ...[
          const SizedBox(height: 8),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
        ],
        if (children != null) ...[
          const SizedBox(height: 8),
          ...children,
        ]
      ]),
    );
  }

  Widget _step(BuildContext context, String text) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(width: 2),
      const Icon(Icons.check_circle_outline, size: 18, color: Colors.green),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
    ]);
  }
}

// Wrapper to keep navigator push type simple in sensor list
class SensorRemovePageWrapper extends StatelessWidget {
  const SensorRemovePageWrapper({super.key});
  @override
  Widget build(BuildContext context) => const SensorRemovePage();
}


