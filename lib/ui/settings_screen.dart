import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/constants.dart';
import '../data/stations.dart';
import '../providers/app_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final allCities = stationRegistry.values.map((s) => s.displayName).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const ListTile(
            title: Text('Minimum edge threshold'),
            subtitle: Text('Only show bets with at least this expected edge'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Slider(
                    value: settings.minEdge,
                    min: 0.03,
                    max: 0.20,
                    divisions: 17,
                    label: '${(settings.minEdge * 100).toStringAsFixed(0)}%',
                    onChanged: (v) {
                      ref.read(settingsProvider.notifier).setMinEdge(v);
                      ref.read(scannerProvider.notifier).refresh();
                    },
                  ),
                ),
                Text('${(settings.minEdge * 100).toStringAsFixed(0)}%'),
              ],
            ),
          ),
          const Divider(),
          const ListTile(
            title: Text('Auto-refresh interval'),
            subtitle: Text('How often to re-scan markets (manual refresh always available)'),
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
          SwitchListTile(
            title: const Text('Today & tomorrow only'),
            subtitle: const Text(
              'Scan markets for the current and next calendar day',
            ),
            value: settings.todayTomorrowOnly,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setTodayTomorrowOnly(value);
              ref.read(scannerProvider.notifier).refresh();
            },
          ),
          SwitchListTile(
            title: const Text('Hide locked markets'),
            subtitle: const Text(
              'Exclude markets where one outcome is ~100% and nothing else is tradeable',
            ),
            value: settings.hideLockedAt100,
            onChanged: (value) {
              ref.read(settingsProvider.notifier).setHideLockedAt100(value);
              ref.read(scannerProvider.notifier).refresh();
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Preferred cities'),
            subtitle: Text(
              settings.preferredCities.isEmpty
                  ? 'All cities (no filter)'
                  : settings.preferredCities.join(', '),
            ),
            trailing: const Icon(Icons.filter_list),
            onTap: () async {
              final selected = Set<String>.from(settings.preferredCities);
              await showDialog<void>(
                context: context,
                builder: (ctx) => StatefulBuilder(
                  builder: (ctx, setState) => AlertDialog(
                    title: const Text('Filter cities'),
                    content: SizedBox(
                      width: double.maxFinite,
                      child: ListView(
                        shrinkWrap: true,
                        children: allCities.map((city) {
                          return CheckboxListTile(
                            title: Text(city),
                            value: selected.contains(city),
                            onChanged: (checked) {
                              setState(() {
                                if (checked == true) {
                                  selected.add(city);
                                } else {
                                  selected.remove(city);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          ref.read(settingsProvider.notifier).setPreferredCities([]);
                          ref.read(scannerProvider.notifier).refresh();
                          Navigator.pop(ctx);
                        },
                        child: const Text('Clear'),
                      ),
                      FilledButton(
                        onPressed: () {
                          ref
                              .read(settingsProvider.notifier)
                              .setPreferredCities(selected.toList());
                          ref.read(scannerProvider.notifier).refresh();
                          Navigator.pop(ctx);
                        },
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Reset to defaults'),
            onTap: () async {
              await ref.read(settingsProvider.notifier).setMinEdge(defaultMinEdge);
              await ref.read(settingsProvider.notifier).setRefreshMinutes(defaultRefreshMinutes);
              await ref.read(settingsProvider.notifier).setPreferredCities([]);
              await ref.read(settingsProvider.notifier).setTodayTomorrowOnly(defaultTodayTomorrowOnly);
              await ref.read(settingsProvider.notifier).setHideLockedAt100(defaultHideLockedAt100);
              ref.read(scannerProvider.notifier).refresh();
            },
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'This app scans Polymarket daily temperature markets using free Open-Meteo '
              'ensemble forecasts and METAR observations. It does not place trades.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
