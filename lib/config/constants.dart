const String gammaApiBase = 'https://gamma-api.polymarket.com';
const String openMeteoEnsembleBase = 'https://ensemble-api.open-meteo.com/v1/ensemble';
const String metarApiBase =
    'https://aviationweather.gov/api/data/metar';

const double defaultMinEdge = 0.07;
const bool defaultHideLockedAt100 = true;
const bool defaultShowYesterday = true;
const bool defaultShowToday = true;
const bool defaultShowTomorrow = true;
const bool defaultHideZeroPriceBuckets = true;
const double spreadInflationFactor = 1.15;
const int defaultRefreshMinutes = 5;
const int webSnapshotRefreshMinutes = 5;
const int maxEventsPerFetch = 100;
const int maxEventPages = 20;
const int historyCacheDays = 60;

const String polymarketEventUrl = 'https://polymarket.com/event/';
