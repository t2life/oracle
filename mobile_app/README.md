# mobile_app

Flutter client scaffold aligned with U-01 to U-19 screen requirements.

## Structure

- `lib/main.dart`: app entrypoint.
- `lib/app.dart`: `MaterialApp` setup.
- `lib/core/network/api_client.dart`: backend API wrapper.
- `lib/core/routing/app_router.dart`: route map and screen binding.
- `lib/core/theme/app_theme.dart`: visual tokens.
- `lib/core/models/domain_models.dart`: shared client models.
- `lib/features/**`: screen-level widgets mapped to UI spec IDs.

## Screen Mapping

- U-01/U-02: `features/onboarding/presentation/onboarding_screen.dart`
- U-03: `features/home/presentation/home_screen.dart`
- U-04: `features/deck_selection/presentation/deck_selection_screen.dart`
- U-05: `features/theme_selection/presentation/theme_selection_screen.dart`
- U-06: `features/shuffle/presentation/shuffle_screen.dart`
- U-07: `features/pile_selection/presentation/pile_selection_screen.dart`
- U-08: `features/card_spread/presentation/card_spread_screen.dart`
- U-09: `features/reading_result/presentation/reading_result_screen.dart`
- U-10: `features/history/presentation/history_screen.dart`
- U-12: `features/card_library/presentation/card_library_screen.dart`
- U-13: `features/announcements/presentation/announcements_screen.dart`
- U-14: `features/ron_room/presentation/ron_room_screen.dart`
- U-15: `features/consultation/presentation/consultation_screen.dart`
- U-16: `features/shop/presentation/shop_screen.dart`
- U-17: `features/my_page/presentation/my_page_screen.dart`
- U-18: `features/paywall/presentation/paywall_screen.dart`
- U-19: `features/notification_settings/presentation/notification_settings_screen.dart`

## Run

```bash
flutter pub get
flutter run
```
