import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/constants.dart';
import '../models/closing_bet_row.dart';
import '../providers/app_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanAsync = ref.watch(closingSoonProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Closing Weather Bets'),
        actions: [
          if (kIsWeb)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: FilledButton.tonalIcon(
                onPressed: () => _openUrl(refreshWorkflowUrl),
                icon: const Icon(Icons.play_circle_outline, size: 18),
                label: const Text('Run data refresh'),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(closingSoonProvider.notifier).refresh(),
            tooltip: kIsWeb
                ? 'Reload data from site'
                : 'Refresh Polymarket scan',
          ),
        ],
      ),
      body: scanAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Scanning Polymarket temperature markets…'),
            ],
          ),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off,
                    size: 48, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 16),
                Text('Scan failed: $err', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () =>
                      ref.read(closingSoonProvider.notifier).refresh(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (result) {
          if (result == null) {
            return const Center(child: Text('No data'));
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(closingSoonProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (kIsWeb) const _WebDataBanner(),
                if (kIsWeb) const SizedBox(height: 12),
                _FilterSliders(settings: settings),
                const SizedBox(height: 12),
                _ScanSummary(
                  count: result.rows.length,
                  scannedAt: result.scannedAt,
                  settings: settings,
                ),
                const SizedBox(height: 16),
                if (result.rows.isEmpty)
                  const _EmptyState()
                else
                  _ClosingBetsTable(rows: result.rows),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _WebDataBanner extends StatelessWidget {
  const _WebDataBanner();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context)
          .colorScheme
          .primaryContainer
          .withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.schedule, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Site data auto-refreshes every $webSnapshotRefreshMinutes minutes '
                '(GitHub Actions limit). Use Run data refresh to trigger an immediate update.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterSliders extends ConsumerWidget {
  const _FilterSliders({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filters', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(
              'Closing within ${settings.closingWindowHours} hours',
              style: theme.textTheme.bodySmall,
            ),
            Slider(
              value: settings.closingWindowHours.toDouble(),
              min: 1,
              max: 48,
              divisions: 47,
              label: '${settings.closingWindowHours}h',
              onChanged: (v) async {
                await ref
                    .read(settingsProvider.notifier)
                    .setClosingWindowHours(v.round());
              },
            ),
            Text(
              'Min share price ${(settings.minPrice * 100).toStringAsFixed(0)}¢',
              style: theme.textTheme.bodySmall,
            ),
            Slider(
              value: settings.minPrice,
              min: 0.50,
              max: 0.95,
              divisions: 45,
              label: '${(settings.minPrice * 100).toStringAsFixed(0)}¢',
              onChanged: (v) async {
                await ref.read(settingsProvider.notifier).setMinPrice(v);
              },
            ),
            Text(
              'Max share price ${(settings.maxPrice * 100).toStringAsFixed(0)}¢',
              style: theme.textTheme.bodySmall,
            ),
            Slider(
              value: settings.maxPrice,
              min: 0.85,
              max: 0.99,
              divisions: 14,
              label: '${(settings.maxPrice * 100).toStringAsFixed(0)}¢',
              onChanged: (v) async {
                await ref.read(settingsProvider.notifier).setMaxPrice(v);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanSummary extends StatelessWidget {
  const _ScanSummary({
    required this.count,
    required this.scannedAt,
    required this.settings,
  });

  final int count;
  final DateTime scannedAt;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '$count bets closing ≤${settings.closingWindowHours}h '
            'at ${(settings.minPrice * 100).toStringAsFixed(0)}–'
            '${(settings.maxPrice * 100).toStringAsFixed(0)}¢',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Text(
          DateFormat.Hm().format(scannedAt),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.search_off,
                size: 48,
                color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              'No matching bets right now',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Try widening the closing window or price range.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ClosingBetsTable extends StatelessWidget {
  const _ClosingBetsTable({required this.rows});

  final List<ClosingBetRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(
            theme.colorScheme.surfaceContainerHighest,
          ),
          columns: const [
            DataColumn(label: Text('City')),
            DataColumn(label: Text('High / Low')),
            DataColumn(label: Text('Temperature')),
            DataColumn(label: Text('Side')),
            DataColumn(label: Text('Price')),
            DataColumn(label: Text('Closes')),
            DataColumn(label: Text('')),
          ],
          rows: rows.map((row) {
            final priceLabel =
                '${(row.sharePrice * 100).toStringAsFixed(1)}¢';
            final closesLabel = DateFormat.Hm().format(row.endDate.toLocal());

            return DataRow(
              cells: [
                DataCell(Text(row.city)),
                DataCell(Text(row.metric.label)),
                DataCell(Text(row.bucketLabel)),
                DataCell(
                  Text(
                    row.side.label,
                    style: TextStyle(
                      color: row.side == BetSide.yes
                          ? theme.colorScheme.primary
                          : theme.colorScheme.tertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                DataCell(Text(priceLabel)),
                DataCell(Text(closesLabel)),
                DataCell(
                  FilledButton.tonal(
                    onPressed: () => _openUrl(row.polymarketUrl),
                    child: const Text('Open'),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
