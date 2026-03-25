import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:helpcare/widgets/custom_button.dart';
import 'package:helpcare/core/utils/settings_storage.dart';

void _mmLog(String message) {
  debugPrint('[MemoModal] $message');
}

class MemoModal extends StatefulWidget {
  const MemoModal({super.key, this.scrollController});
  final ScrollController? scrollController;
  @override
  State<MemoModal> createState() => _MemoModalState();
}

class _MemoModalState extends State<MemoModal> {
  @override
  void initState() {
    super.initState();
    _mmLog('initState');
  }

  @override
  void dispose() {
    _mmLog('dispose');
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? payload;
    return LayoutBuilder(builder: (context, constraints) {
      _mmLog('build: maxW=${constraints.maxWidth} maxH=${constraints.maxHeight}');
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          height: constraints.maxHeight,
          width: double.infinity,
          child: Column(
            children: [
              // 콘텐츠 영역은 주어진 높이 내에서만 확장
              Expanded(child: MemoModalContent(onChanged: (p) => payload = p, externalScroll: widget.scrollController)),
              const SizedBox(height: 12),
              CustomButton(
                width: double.infinity,
                text: 'SAVE',
                variant: ButtonVariant.FillLoginGreen,
                onTap: () {
                  _mmLog('save pressed payload=${payload ?? const {}}');
                  Navigator.of(context).pop(payload ?? const {});
                },
              )
            ],
          ),
        ),
      );
    });
  }
}

class MemoModalContent extends StatefulWidget {
  const MemoModalContent({super.key, required this.onChanged, this.externalScroll});
  final void Function(Map<String, dynamic> payload) onChanged;
  final ScrollController? externalScroll;
  @override
  State<MemoModalContent> createState() => _MemoModalContentState();
}

class _MemoModalContentState extends State<MemoModalContent> {
  String type = 'Memo';
  final TextEditingController note = TextEditingController();
  final FocusNode noteFocus = FocusNode();
  final ScrollController _scroll = ScrollController();
  DateTime when = DateTime.now();
  String _foodShotAsset = '';
  String _foodShotAt = '';
  // 6개 버튼으로 축소, 아이콘은 차트와 동일 계열로 통일
  // 차트와 동일 아이콘 매핑
  // order: Blood glucose, Exercise, Insulin, Memo, Meal, Medication
  static const List<_EventItem> _items = <_EventItem>[
    _EventItem(key: 'Blood glucose', label: 'Blood glucose', icon: Icons.water_drop),
    _EventItem(key: 'Exercise', label: 'Exercise', icon: Icons.directions_run),
    _EventItem(key: 'Insulin', label: 'Insulin', icon: Icons.vaccines),
    _EventItem(key: 'Memo', label: 'Memo', icon: Icons.sticky_note_2_outlined),
    _EventItem(key: 'Meal', label: 'Meal', icon: Icons.restaurant),
    _EventItem(key: 'Medication', label: 'Medication', icon: Icons.medication),
  ];

  Color _badgeColorFor(String key) {
    switch (key) {
      case 'Blood glucose':
        return const Color(0xFFE57373); // blood glucose – red
      case 'Insulin':
        return const Color(0xFFAB47BC); // insulin – purple
      case 'Medication':
        return const Color(0xFF26A69A); // medication – teal
      case 'Exercise':
        return const Color(0xFF5C6BC0); // exercise – indigo
      case 'Meal':
        return const Color(0xFFFFB74D); // meal – orange
      case 'Memo':
        return const Color(0xFF2ECC71); // memo – green
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  void _emit() {
    final String isoUtc = when.toUtc().toIso8601String();
    _mmLog('emit type=$type when=$isoUtc noteLen=${note.text.length}');
    final payload = <String, dynamic>{'type': type, 'note': note.text, 'when': isoUtc};
    if (type == 'Meal' && _foodShotAsset.trim().isNotEmpty) {
      payload['foodShotAsset'] = _foodShotAsset.trim();
      payload['foodShotAt'] = _foodShotAt;
    }
    widget.onChanged(payload);
  }

  @override
  void initState() {
    super.initState();
    _mmLog('content initState');
    note.addListener(() => _mmLog('note changed len=${note.text.length}'));
    _loadFoodShot();
  }

  Future<void> _loadFoodShot() async {
    try {
      final st = await SettingsStorage.load();
      final String asset = (st['me0101FoodShotAsset'] as String? ?? '').trim();
      final String at = (st['me0101FoodShotAt'] as String? ?? '').trim();
      if (!mounted) return;
      setState(() {
        _foodShotAsset = asset;
        _foodShotAt = at;
      });
    } catch (_) {}
  }

  Future<void> _attachSampleFoodShot() async {
    if (!kDebugMode) return;
    const String sample = 'assets/images/img_rectangle104.png';
    try {
      final st = await SettingsStorage.load();
      st['me0101FoodShotAsset'] = sample;
      st['me0101FoodShotAt'] = DateTime.now().toUtc().toIso8601String();
      await SettingsStorage.save(st);
      if (!mounted) return;
      setState(() {
        _foodShotAsset = sample;
        _foodShotAt = (st['me0101FoodShotAt'] as String? ?? '').trim();
      });
      _emit();
    } catch (_) {}
  }

  Future<void> _clearFoodShot() async {
    try {
      final st = await SettingsStorage.load();
      st['me0101FoodShotAsset'] = '';
      st['me0101FoodShotAt'] = '';
      await SettingsStorage.save(st);
      if (!mounted) return;
      setState(() {
        _foodShotAsset = '';
        _foodShotAt = '';
      });
      _emit();
    } catch (_) {}
  }

  @override
  void dispose() {
    _mmLog('content dispose');
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: when,
    );
    if (picked != null) {
      setState(() {
        when = DateTime(picked.year, picked.month, picked.day, when.hour, when.minute);
        _emit();
      });
      _mmLog('date picked ${when.toIso8601String()}');
    } else {
      _mmLog('date pick cancelled');
    }
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(when),
    );
    if (t != null) {
      setState(() {
        when = DateTime(when.year, when.month, when.day, t.hour, t.minute);
        _emit();
      });
      _mmLog('time picked ${when.toIso8601String()}');
    } else {
      _mmLog('time pick cancelled');
    }
  }

  void _setNow() {
    setState(() {
      when = DateTime.now();
      _emit();
    });
    _mmLog('now set ${when.toIso8601String()}');
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: widget.externalScroll ?? _scroll,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Event Editor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(null),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: _items.map((e) => _iconTile(e)).toList(),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$type',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16, // 더 크게
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: note,
            focusNode: noteFocus,
            style: const TextStyle(fontSize: 13), // 한 단계 작게
            decoration: InputDecoration(
              labelText: 'Content',
              border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(5))),
              focusedBorder: OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(5)),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1),
              ),
            ),
            maxLines: 3,
            onChanged: (_) => _emit(),
          ),
          const SizedBox(height: 8),
          if (type == 'Meal') ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED), // light orange tint
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.photo_camera, size: 18, color: Colors.black54),
                      SizedBox(width: 8),
                      Text('Food shot', style: TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_foodShotAsset.trim().isEmpty)
                    const Text('No photo attached', style: TextStyle(color: Colors.black54))
                  else
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.asset(_foodShotAsset.trim(), fit: BoxFit.cover),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (kDebugMode)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _attachSampleFoodShot,
                            icon: const Icon(Icons.image, size: 18),
                            label: const Text('ATTACH SAMPLE'),
                          ),
                        ),
                      if (kDebugMode) const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _foodShotAsset.trim().isEmpty ? null : _clearFoodShot,
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('CLEAR'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          // 시간 카드형 섹션
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Time', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text('${when.year}-${when.month}-${when.day} ${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_month, size: 18),
                      label: const Text('DATE'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.schedule, size: 18),
                      label: const Text('TIME'),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _setNow,
                    icon: const Icon(Icons.my_location, size: 18),
                    label: const Text('현재'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconTile(_EventItem e) {
    final bool selected = type == e.key;
    return InkWell(
      onTap: () {
        setState(() => type = e.key);
        _mmLog('type selected="$type"');
        _emit();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          noteFocus.requestFocus();
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 84,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? Theme.of(context).colorScheme.primary : const Color(0xFFE6E6E6)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _badgeColorFor(e.key),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2))],
              ),
              alignment: Alignment.center,
              child: Icon(e.icon, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(e.label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _EventItem {
  const _EventItem({required this.key, required this.label, required this.icon});
  final String key;
  final String label;
  final IconData icon;
}


