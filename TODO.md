# White Screen Issue Fix

## Done
- [x] Analyzed the codebase and identified root causes.
- [x] Updated `lib/widgets/mini_player.dart` to use named-route navigation.
- [x] Updated `lib/screens/now_playing_screen.dart` with error handling and safer rendering.
- [x] Registered missing named routes in `lib/main.dart` for queue and equalizer screens.

## Next
- [ ] Test all related flows and confirm the white screen issue is resolved:
- [ ] Tap mini player -> opens now playing screen without white screen.
- [ ] Open now playing directly via named route -> renders correctly.
- [ ] Return/back navigation from now playing -> no blank screen.
- [ ] App resume (background -> foreground) on now playing -> UI remains visible.
- [ ] Invalid/missing track data -> fallback UI appears instead of crash/blank view.
- [ ] Loading state (before track is ready) -> loading UI appears and transitions correctly.
- [ ] Playback controls still work after navigation changes.
