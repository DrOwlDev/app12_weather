const String gammaApiBase = 'https://gamma-api.polymarket.com';
const String openMeteoEnsembleBase = 'https://ensemble-api.open-meteo.com/v1/ensemble';
const String metarApiBase =
    'https://aviationweather.gov/api/data/metar';

const double defaultMinEdge = 0.07;
const bool defaultHideLockedAt100 = true;
const bool defaultTodayTomorrowOnly = true;
const double spreadInflationFactor = 1.15;
const int defaultRefreshMinutes = 15;
const int maxEventsPerFetch = 100;
const int maxEventPages = 15;
const int historyCacheDays = 60;

const String polymarketEventUrl = 'https://polymarket.com/event/';
