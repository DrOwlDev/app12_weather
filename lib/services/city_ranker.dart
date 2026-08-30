import '../data/stations.dart';
import '../models/weather_event.dart';

class CityRanker {
  double scoreEvent(WeatherMarketEvent event, {Map<String, double>? cityWinRates}) {
    final station = lookupStation(event.city);
    var score = station?.dataQualityScore ?? 0.7;

    if (cityWinRates != null) {
      final key = event.city.toLowerCase();
      final winRate = cityWinRates[key];
      if (winRate != null) {
        score = score * 0.4 + winRate * 0.6;
      }
    }

    final spread = event.ensembleSpread;
    if (spread != null) {
      if (spread < 0.8) {
        score += 0.1;
      } else if (spread > 2.0) {
        score -= 0.15;
      }
    }

    if (event.isSameDay && event.metRunningMax != null) {
      score += 0.08;
    } else if (event.isSameDay) {
      score -= 0.05;
    }

    return score.clamp(0.0, 1.0);
  }

  List<WeatherMarketEvent> rankEvents(
    List<WeatherMarketEvent> events, {
    Map<String, double>? cityWinRates,
  }) {
    final sorted = List<WeatherMarketEvent>.from(events);
    sorted.sort((a, b) {
      final scoreA = scoreEvent(a, cityWinRates: cityWinRates);
      final scoreB = scoreEvent(b, cityWinRates: cityWinRates);
      return scoreB.compareTo(scoreA);
    });
    return sorted;
  }
}
