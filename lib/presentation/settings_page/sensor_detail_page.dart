import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:helpcare/core/utils/settings_service.dart';
import 'package:helpcare/presentation/report/_report_widgets.dart';

class SensorDetailPage extends StatefulWidget {
  const SensorDetailPage({super.key, required this.sensor});
  final Map<String, dynamic> sensor;

  @override
  State<SensorDetailPage> createState() => _SensorDetailPageState();
}

class _SensorDetailPageState extends State<SensorDetailPage> {
  final SettingsService _svc = SettingsService();
  late TextEditingController _name;
  late TextEditingController _serial;
  late TextEditingController _offset;
  late TextEditingController _scale;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final s = widget.sensor;
    _name = TextEditingController(text: (s['name'] ?? '').toString());
    _serial = TextEditingController(text: (s['serial'] ?? '').toString());
    _offset = TextEditingController(text: (s['offset'] ?? 0).toString());
    _scale = TextEditingController(text: (s['scale'] ?? 1).toString());
    _isActive = s['isActive'] == true;
  }

  @override
  void dispose() {
    _name.dispose();
    _serial.dispose();
    _offset.dispose();
    _scale.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final id = (widget.sensor['_id'] ?? '').toString();
    await _svc.updateSensor(id, {
      'name': _name.text.trim(),
      'serial': _serial.text.trim(),
      'isActive': _isActive,
      'offset': double.tryParse(_offset.text) ?? 0,
      'scale': double.tryParse(_scale.text) ?? 1,
    });
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            ReportCard(
              title: 'sensor_detail_title'.tr(),
              subtitle: 'sensor_detail_basic_sub'.tr(),
              child: Column(children: [
                _textField(label: 'common_name'.tr(), controller: _name, icon: Icons.memory),
                const SizedBox(height: 10),
                _textField(label: 'sensor_detail_serial'.tr(), controller: _serial, icon: Icons.tag),
              ]),
            ),
            const SizedBox(height: 12),
            ReportCard(
              title: 'sensor_detail_calibration'.tr(),
              subtitle: 'sensor_detail_offset_scale'.tr(),
              child: Column(children: [
                _textField(label: 'sensor_detail_offset'.tr(), controller: _offset, icon: Icons.tune, keyboardType: TextInputType.number),
                const SizedBox(height: 10),
                _textField(label: 'sensor_detail_scale'.tr(), controller: _scale, icon: Icons.straighten, keyboardType: TextInputType.number),
              ]),
            ),
            const SizedBox(height: 12),
            ReportCard(
              title: 'Status',
              subtitle: 'Activation',
              child: Row(children: [
                const Icon(Icons.power_settings_new),
                const SizedBox(width: 8),
                const Expanded(child: Text('Active')),
                Switch(value: _isActive, onChanged: (v) => setState(() => _isActive = v)),
              ]),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: Text('common_save'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _textField({required String label, required TextEditingController controller, required IconData icon, TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
      ),
    );
  }
}


