import 'dart:async';
import 'package:flutter/material.dart';

class SensorScanNfcPage extends StatelessWidget {
  const SensorScanNfcPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SC_01_03 - NFC 스캔')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('NFC 태그를 센서에 가져다 대세요.'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const SensorWarmupPage()),
              ),
              child: const Text('스캔 성공 처리'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const SensorSerialInputPage())),
              child: const Text('스캔 실패 · 일련번호 입력'),
            )
          ],
        ),
      ),
    );
  }
}

class SensorScanQrPage extends StatelessWidget {
  const SensorScanQrPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SC_01_04 - QR 스캔')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('QR 코드를 프레임 안에 맞추세요.'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const SensorWarmupPage()),
              ),
              child: const Text('스캔 성공 처리'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const SensorSerialInputPage())),
              child: const Text('스캔 실패 · 일련번호 입력'),
            )
          ],
        ),
      ),
    );
  }
}

class SensorSerialInputPage extends StatefulWidget {
  const SensorSerialInputPage({super.key});
  @override
  State<SensorSerialInputPage> createState() => _SensorSerialInputPageState();
}

class _SensorSerialInputPageState extends State<SensorSerialInputPage> {
  final TextEditingController controller = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SC_01_05 - 일련번호 입력')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: '센서 일련번호'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const SensorWarmupPage()),
              ),
              child: const Text('등록'),
            )
          ],
        ),
      ),
    );
  }
}

class SensorWarmupPage extends StatefulWidget {
  const SensorWarmupPage({super.key});
  @override
  State<SensorWarmupPage> createState() => _SensorWarmupPageState();
}

class _SensorWarmupPageState extends State<SensorWarmupPage> {
  static const int totalSeconds = 30 * 60; // 30분
  late Timer timer;
  int remaining = totalSeconds;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        remaining--;
        if (remaining <= 0) {
          t.cancel();
          Navigator.of(context).pop();
        }
      });
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (remaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (remaining % 60).toString().padLeft(2, '0');
    return Scaffold(
      appBar: AppBar(title: const Text('SC_01_06 - 센서 웜업')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('센서 웜업 중...'),
            const SizedBox(height: 12),
            Text('$minutes:$seconds', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('완료 시 자동으로 이전 화면으로 돌아갑니다.'),
          ],
        ),
      ),
    );
  }
}


