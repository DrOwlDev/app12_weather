import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/constants.dart';
import '../providers/app_providers.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(cityStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('City Win Rates'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(cityStatsProvider.notifier).refresh(),
            tooltip: 'Refresh stats',
          ),
        ],
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Failed to load stats: $err')),
        data: (stats) {
          if (stats.isEmpty) {
            return const Center(
              child: Text('No historical data yet. Check back after markets resolve.'),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(cityStatsProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (kIsWeb)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Historical stats refresh every $webSnapshotRefreshMinutes minutes on web.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                Text(
                  'Per-city accuracy from recently resolved Polymarket temperature markets. '
                  'Higher accuracy cities are more predictable for betting.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                ...stats.map(
                  (s) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(s.city),
                      subtitle: Text('${s.totalMarkets} resolved markets'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${(s.modelAccuracy * 100).toStringAsFixed(0)}%',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: _accuracyColor(s.modelAccuracy),
                                ),
                          ),
                          Text(
                            'YES ${(s.yesWinRate * 100).toStringAsFixed(0)}% · '
                            'NO ${(s.noWinRate * 100).toStringAsFixed(0)}%',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _accuracyColor(double accuracy) {
    if (accuracy >= 0.7) return Colors.green;
    if (accuracy >= 0.5) return Colors.orange;
    return Colors.red;
  }
}
