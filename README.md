# Polymarket Weather Bet Scanner

Cross-platform Flutter app that scans Polymarket **daily temperature** markets, compares crowd odds to free ensemble weather forecasts, and surfaces **YES** or **NO-bundle** opportunities with at least **7% expected edge**.

Scanner only — no wallet or auto-trading. Open recommendations directly on Polymarket to place bets manually.

## Features

- Fetches active Polymarket daily temperature events via the public Gamma API
- Forecasts daily highs using Open-Meteo GFS ensemble at each market's resolution airport
- Same-day METAR nowcast from aviationweather.gov when available
- Recommends **YES on one bucket** or **NO on all other buckets**
- Ranks cities by predictability (ensemble spread, data source quality, historical accuracy)
- Historical win rates from recently resolved markets
- Runs on **Windows**, **Android**, and **Web**

## Quick start (Windows)

```bash
flutter pub get
flutter run -d windows
```

## Android

```bash
flutter build apk --release
```

APK output: `build/app/outputs/flutter-apk/app-release.apk`

Download latest APK: https://drowldev.github.io/app12_weather/output.apk

## Web (local)

```bash
flutter run -d chrome
```

## GitHub Pages

Live site: **https://drowldev.github.io/app12_weather/**

1. Push this repo to GitHub (`DrOwlDev/app12_weather`)
2. GitHub Pages is configured for **GitHub Actions** deployment
3. Every push to `main` runs [`.github/workflows/deploy-web.yml`](.github/workflows/deploy-web.yml) automatically

Manual redeploy:

```bash
gh workflow run "Deploy Web to GitHub Pages"
```

## Settings

- **Minimum edge** — default 7%; only show bets meeting this threshold
- **Preferred cities** — optional filter (Miami, Dallas, Hong Kong, etc.)
- **Refresh** — pull-to-refresh on dashboard; change auto-refresh interval in Settings

## How edge is calculated

| Strategy | Formula |
|----------|---------|
| YES | `model_probability − yes_ask ≥ min_edge` |
| NO bundle | `(win_prob × sum(1 − no_askᵢ) − total_cost) / total_cost ≥ min_edge` |

Model probability = fraction of GFS ensemble members landing in each temperature bucket, with same-day METAR running-max adjustment.

## Resolution stations

Markets resolve against specific airport stations (not city centers). The app maps known cities to ICAO codes and parses resolution sources from market descriptions. Always verify the resolution source link before betting.

## Optional CORS proxy (web only)

If the web build cannot reach `gamma-api.polymarket.com` from the browser, run a simple reverse proxy on Oracle Free Tier or Cloudflare Workers:

```
GET /api/gamma/* → https://gamma-api.polymarket.com/*
```

Mobile and desktop apps call the API directly and do not need this.

## Disclaimer

Prediction markets involve financial risk. Forecast edges are model estimates, not guarantees. This app is for informational purposes only.
