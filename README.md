# RENOK

Flutter arrow-puzzle game (Android).

## Release build

1. Create an upload keystore and `android/key.properties` (see `android/key.properties.example`).
2. Create the AdMob app + a rewarded and an interstitial unit; put the app id in `key.properties` (`admobAppId`).
3. Set up the consent (GDPR) message in AdMob > Privacy & messaging.
4. Build:

```
flutter build appbundle --release \
  --dart-define=ADMOB_REWARDED_ID=ca-app-pub-XXXX/YYYY \
  --dart-define=ADMOB_INTERSTITIAL_ID=ca-app-pub-XXXX/ZZZZ
```

Without these values the build uses debug signing and Google's test ad ids, so never upload such a build.
