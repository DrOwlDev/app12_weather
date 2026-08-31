import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/constants.dart';
import '../models/recommendation.dart';
import '../providers/app_providers.dart';
import '../services/market_filters.dart';
import 'market_detail_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanAsync = ref.watch(scannerProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weather Bet Scanner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(scannerProvider.notifier).refresh(),
            tooltip: 'Refresh',
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
              Text('Scanning Polymarket weather markets…'),
            ],
          ),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off, size: 48, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 16),
                Text('Scan failed: $err', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.read(scannerProvider.notifier).refresh(),
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
            onRefresh: () => ref.read(scannerProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (kIsWeb) const _WebDataBanner(),
                if (kIsWeb) const SizedBox(height: 12),
                _DisclaimerBanner(),
                const SizedBox(height: 12),
                _ScanSummary(
                  count: result.recommendations.length,
                  minEdge: settings.minEdge,
                  scannedAt: result.scannedAt,
                  todayTomorrowOnly: settings.todayTomorrowOnly,
                  hideLockedAt100: settings.hideLockedAt100,
                ),
                const SizedBox(height: 16),
                if (result.recommendations.isEmpty)
                  const _EmptyState()
                else
                  ...result.recommendations.map(
                    (rec) => _RecommendationCard(
                      recommendation: rec,
                      onTap: () {
                        ref.read(selectedEventProvider.notifier).state = rec.event;
                        ref.read(selectedRecommendationProvider.notifier).state = rec;
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => MarketDetailScreen(
                              event: rec.event,
                              highlight: rec,
                            ),
                          ),
                        );
                      },
                      onOpenPolymarket: () => _openUrl(rec.event.polymarketUrl),
                    ),
                  ),
                const SizedBox(height: 24),
                Text(
                  'All active markets (${result.events.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...result.events.take(20).map(
                  (event) => ListTile(
                    title: Text(event.city),
                    subtitle: Text(_formatEventDate(event.targetDate)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      ref.read(selectedEventProvider.notifier).state = event;
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => MarketDetailScreen(event: event),
                        ),
                      );
                    },
                  ),
                ),
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

String _formatEventDate(DateTime date) {
  final label = dateLabel(date);
  final formatted = DateFormat.yMMMd().format(date);
  return label.isEmpty ? formatted : '$formatted ($label)';
}

class _WebDataBanner extends StatelessWidget {
  const _WebDataBanner();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.cloud_download_outlined, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Web data refreshes every $webSnapshotRefreshMinutes minutes. '
                'Install the Android APK for live scanning.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            TextButton(
              onPressed: () {
                launchUrl(
                  Uri.base.resolve('output.apk'),
                  mode: LaunchMode.externalApplication,
                );
              },
              child: const Text('Get APK'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DisclaimerBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Scanner only — not financial advice. Edge estimates are model-based, not guaranteed.',
                style: TextStyle(fontSize: 12),
              ),
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
    required this.minEdge,
    required this.scannedAt,
    required this.todayTomorrowOnly,
    required this.hideLockedAt100,
  });

  final int count;
  final double minEdge;
  final DateTime scannedAt;
  final bool todayTomorrowOnly;
  final bool hideLockedAt100;

  @override
  Widget build(BuildContext context) {
    final filters = <String>[
      if (todayTomorrowOnly) 'today & tomorrow',
      if (hideLockedAt100) 'unlocked only',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$count opportunities with ≥${(minEdge * 100).toStringAsFixed(0)}% edge',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              DateFormat.Hm().format(scannedAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        if (filters.isNotEmpty)
          Text(
            'Showing: ${filters.join(', ')}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
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
            Icon(Icons.search_off, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              'No bets meet the minimum edge threshold right now.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Try lowering the threshold in Settings or check back after the next forecast update.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.recommendation,
    required this.onTap,
    required this.onOpenPolymarket,
  });

  final BetRecommendation recommendation;
  final VoidCallback onTap;
  final VoidCallback onOpenPolymarket;

  @override
  Widget build(BuildContext context) {
    final rec = recommendation;
    final event = rec.event;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      event.city,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _StabilityBadge(score: rec.cityStabilityScore),
                ],
              ),
              Text(
                _formatEventDate(event.targetDate),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  rec.strategyLabel,
                  style: theme.textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _MetricChip(
                    label: 'Model',
                    value: '${(rec.modelProbability * 100).toStringAsFixed(1)}%',
                  ),
                  const SizedBox(width: 8),
                  _MetricChip(
                    label: 'Edge',
                    value: '${(rec.effectiveEdge * 100).toStringAsFixed(1)}%',
                    highlight: true,
                  ),
                  const SizedBox(width: 8),
                  _MetricChip(
                    label: 'Return',
                    value: '${(rec.returnOnCost * 100).toStringAsFixed(1)}%',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                rec.confidenceNote,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                    onPressed: onTap,
                    child: const Text('Details'),
                  ),
                  const Spacer(),
                  FilledButton.tonal(
                    onPressed: onOpenPolymarket,
                    child: const Text('Open Polymarket'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StabilityBadge extends StatelessWidget {
  const _StabilityBadge({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    final pct = (score * 100).round();
    Color color;
    if (score >= 0.85) {
      color = Colors.green;
    } else if (score >= 0.7) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Stability $pct%',
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
                color: highlight ? Theme.of(context).colorScheme.primary : null,
              ),
        ),
      ],
    );
  }
}
