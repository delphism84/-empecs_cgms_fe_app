import 'package:flutter/material.dart';
import 'create_account_step2_country.dart';

/// Create Account Step 1: Choose type
class CreateAccountStep1Page extends StatefulWidget {
  const CreateAccountStep1Page({super.key});

  @override
  State<CreateAccountStep1Page> createState() => _CreateAccountStep1PageState();
}

class _CreateAccountStep1PageState extends State<CreateAccountStep1Page> {
  String? _selected; // 'new' | 'add'

  static const _kMinTouchTarget = 44.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _OptionCard(
                title: 'Account',
                subtitle: 'Of legal age: Create your new account.\n\nUnder legal age: A parent/guardian must create an account first and then add you.',
                value: 'new',
                groupValue: _selected,
                onChanged: (v) => setState(() => _selected = v),
              ),
              const SizedBox(height: 12),
              _OptionCard(
                title: 'Add user to existing account',
                subtitle: 'Add a dependent (minor or adult) to your existing account.',
                value: 'add',
                groupValue: _selected,
                onChanged: (v) => setState(() => _selected = v),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: _kMinTouchTarget + 8,
                child: ElevatedButton(
                  onPressed: _selected == null
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const CreateAccountStep2CountryPage(),
                          ),
                        );
                      },
                  child: const Text('Next'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final String? groupValue;
  final ValueChanged<String> onChanged;
  const _OptionCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    final bool selected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? Theme.of(context).colorScheme.primary : Colors.grey.shade400),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Radio<String>(
              value: value,
              groupValue: groupValue,
              onChanged: (_) => onChanged(value),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.black54)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// no trailing imports


