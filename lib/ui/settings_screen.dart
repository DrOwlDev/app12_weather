import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/constants.dart';
import '../providers/app_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const ListTile(
            title: Text('Auto-refresh interval'),
            subtitle: Text(
              'How often to re-scan markets (manual refresh always available)',
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<int>(
              initialValue: settings.refreshMinutes,
              items: const [
                DropdownMenuItem(value: 5, child: Text('5 minutes')),
                DropdownMenuItem(value: 15, child: Text('15 minutes')),
                DropdownMenuItem(value: 30, child: Text('30 minutes')),
                DropdownMenuItem(value: 60, child: Text('60 minutes')),
              ],
              onChanged: (v) {
                if (v != null) {
                  ref.read(settingsProvider.notifier).setRefreshMinutes(v);
                }
              },
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Reset to defaults'),
            onTap: () async {
              await ref.read(settingsProvider.notifier).resetToDefaults();
            },
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Closing window and share-price filters are on the Scanner tab. '
              'This app lists Polymarket daily temperature markets closing soon '
              'with YES or NO shares in your chosen price band. It does not place trades.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Defaults: ${defaultClosingWindowHours}h window, '
              '${(defaultClosingBetMinPrice * 100).toStringAsFixed(0)}–'
              '${(defaultClosingBetMaxPrice * 100).toStringAsFixed(0)}¢',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
