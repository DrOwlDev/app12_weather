const String gammaApiBase = 'https://gamma-api.polymarket.com';

const int defaultClosingWindowHours = 6;
const double defaultClosingBetMinPrice = 0.90;
const double defaultClosingBetMaxPrice = 0.97;
const int defaultRefreshMinutes = 5;
const int webSnapshotRefreshMinutes = 5;
const int maxEventsPerFetch = 100;
const int maxEventPages = 20;

const String githubRepo = 'DrOwlDev/app12_weather';
const String refreshWorkflowUrl =
    'https://github.com/$githubRepo/actions/workflows/refresh-web-data.yml';

const String polymarketEventUrl = 'https://polymarket.com/event/';
const String polymarketMarketUrl = 'https://polymarket.com/market/';

/// Export window so web clients can filter with wider slider ranges.
const int exportClosingWindowHours = 72;
