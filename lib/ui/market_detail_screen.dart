import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/bucket.dart';
import '../models/recommendation.dart';
import '../models/weather_event.dart';
import '../providers/app_providers.dart';
import '../services/market_filters.dart';

class MarketDetailScreen extends ConsumerWidget {
  const MarketDetailScreen({
    super.key,
    required this.event,
    this.highlight,
  });

  final WeatherMarketEvent event;
  final BetRecommendation? highlight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final displayEvent = filterEventBuckets(
      event,
      hideZeroPriceBuckets: settings.hideZeroPriceBuckets,
    );
    final favorite = displayEvent.favoriteBucket;
    final unitLabel =
        displayEvent.buckets.isNotEmpty &&
                displayEvent.buckets.first.unit == TemperatureUnit.fahrenheit
            ? '°F'
            : '°C';

    return Scaffold(
      appBar: AppBar(
        title: Text(event.city),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            onPressed: () => _openUrl(event.polymarketUrl),
            tooltip: 'Open on Polymarket',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            event.title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(DateFormat.yMMMEd().format(event.targetDate)),
          if (highlight != null) ...[
            const SizedBox(height: 16),
            _HighlightCard(recommendation: highlight!),
          ],
          const SizedBox(height: 16),
          _InfoRow(label: 'Resolution station', value: event.icaoCode),
          _InfoRow(
            label: 'Ensemble spread',
            value: event.ensembleSpread?.toStringAsFixed(2) ?? '—',
          ),
          if (event.metRunningMax != null)
            _InfoRow(
              label: 'METAR running max',
              value: '${event.metRunningMax!.toStringAsFixed(1)}$unitLabel',
            ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _openUrl(event.resolutionSource.startsWith('http')
                ? event.resolutionSource
                : event.polymarketUrl),
            icon: const Icon(Icons.link, size: 16),
            label: const Text('Resolution source'),
          ),
          const SizedBox(height: 16),
          Text(
            'Temperature buckets',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...displayEvent.buckets.map(
            (bucket) => _BucketRow(
              bucket: bucket,
              isFavorite: favorite?.id == bucket.id,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({required this.recommendation});

  final BetRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recommended: ${recommendation.strategyLabel}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Edge ${(recommendation.effectiveEdge * 100).toStringAsFixed(1)}% · '
              'Expected return ${(recommendation.returnOnCost * 100).toStringAsFixed(1)}%',
            ),
            Text(recommendation.confidenceNote),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _BucketRow extends StatelessWidget {
  const _BucketRow({required this.bucket, required this.isFavorite});

  final TemperatureBucket bucket;
  final bool isFavorite;

  @override
  Widget build(BuildContext context) {
    final modelPct = bucket.modelProbability;
    final marketPct = bucket.yesPrice;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isFavorite
          ? Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.4)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    bucket.label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (isFavorite)
                  const Icon(Icons.star, size: 16, color: Colors.amber),
              ],
            ),
            const SizedBox(height: 8),
            _ProbBar(label: 'Model', value: modelPct, color: Colors.blue),
            const SizedBox(height: 4),
            _ProbBar(label: 'Market YES', value: marketPct, color: Colors.green),
            const SizedBox(height: 4),
            Text(
              'YES ${(bucket.effectiveYesAsk * 100).toStringAsFixed(1)}¢ · '
              'NO ${(bucket.effectiveNoAsk * 100).toStringAsFixed(1)}¢',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProbBar extends StatelessWidget {
  const _ProbBar({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 72, child: Text(label, style: const TextStyle(fontSize: 12))),
        Expanded(
          child: LinearProgressIndicator(
            value: value.clamp(0, 1),
            backgroundColor: color.withValues(alpha: 0.15),
            color: color,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          child: Text(
            '${(value * 100).toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
