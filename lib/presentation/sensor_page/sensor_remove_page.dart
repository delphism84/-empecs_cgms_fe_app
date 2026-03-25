import 'package:flutter/material.dart';
import 'package:helpcare/core/utils/image_constant.dart';
import 'package:helpcare/core/utils/settings_storage.dart';

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
      appBar: AppBar(title: const Text('How to remove')),
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
                title: 'How to Remove the Sensor',
                body: 'Medisign CG01 can be used for up to 14 days.\n'
                    'You will receive a notification 72 hours before the sensor expires.\n'
                    'When it expires, the sensor will automatically disconnect, and you can then remove it.',
              ),
              _card(
                context,
                leading: Icons.format_list_numbered,
                title: 'Steps',
                children: [
                  _step(context, '1) Remove the sensor from your arm. Gently peel it off from the edge of the adhesive tape.'),
                  _step(context, '2) If the tape does not come off easily, apply a small amount of baby oil around the edges and rub gently.'),
                  _step(context, '3) Wash the area and apply moisturizer to care for your skin.'),
                ],
              ),
              _card(
                context,
                leading: Icons.warning_amber_rounded,
                title: 'Caution',
                body: 'If you experience pain, itching, redness, fever, or signs of infection after removing the sensor, consult a healthcare professional, such as a dermatologist.',
              ),
              _card(
                context,
                leading: Icons.link_off,
                title: 'Removing Before Expiration',
                body: 'If you want to remove the sensor before it expires, press the Disconnect button in the app.',
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


