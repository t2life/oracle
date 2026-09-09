import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../shell/presentation/main_shell.dart';

/// ホームのキャラ動画へ「描画を張り直せ」と伝える合図。
/// ≡ドロワーや言語ダイアログを閉じた直後に [requestHomeVideoRefresh] を呼ぶ。
final ValueNotifier<int> homeVideoRefreshRequest = ValueNotifier<int>(0);

/// モーダルを閉じた側から呼ぶ。値の変化だけが意味を持つ。
void requestHomeVideoRefresh() => homeVideoRefreshRequest.value++;

/// ホーム中央の「ロンさん浮遊」動画（寺院背景を合成済み）。
/// 無音・ループ再生。初期化前と失敗時はポスター静止画にフォールバックする。
///
/// ホームが他画面に覆われている間・アプリが非アクティブな間は再生を止める。
/// （覆われたまま再生し続けると24fps・768x1024のデコードが遷移処理と競合し、
///   下部ナビからの画面切替が遅れる。ホーム自体は破棄されないため自動では止まらない）
class HomeCharacterVideo extends StatefulWidget {
  const HomeCharacterVideo({super.key, required this.asset, this.poster});

  final String asset;
  final String? poster;

  @override
  State<HomeCharacterVideo> createState() => _HomeCharacterVideoState();
}

class _HomeCharacterVideoState extends State<HomeCharacterVideo>
    with WidgetsBindingObserver, RouteAware {
  VideoPlayerController? _controller;
  bool _ready = false;

  /// ホームが最前面か（他画面に覆われている間はfalse）。
  bool _routeVisible = true;

  /// アプリが前面か（バックグラウンド中はfalse）。
  bool _appResumed = true;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    homeVideoRefreshRequest.addListener(_refreshPlayback);
    _init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      shellRouteObserver.subscribe(this, route);
    }
  }

  Future<void> _init() async {
    final startedAt = DateTime.now();
    final c = VideoPlayerController.asset(widget.asset);
    _controller = c;
    try {
      await c.initialize();
      await c.setLooping(true);
      await c.setVolume(0); // 効果音システムと独立＝動画は常時無音
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _ready = true);
      await _applyPlayback();
      debugPrint(
        'ホーム: キャラ動画を初期化 '
        '所要=${DateTime.now().difference(startedAt).inMilliseconds}ms',
      );
    } catch (_) {
      // 初期化失敗はポスター表示のまま継続（非致命）
    }
  }

  /// 表示状態とアプリの前面状態から、再生／停止を決める単一の判断点。
  Future<void> _applyPlayback() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return;
    }
    final shouldPlay = _routeVisible && _appResumed;
    if (shouldPlay == c.value.isPlaying) {
      return;
    }
    if (shouldPlay) {
      await c.play();
    } else {
      await c.pause();
    }
    debugPrint('ホーム: キャラ動画を${shouldPlay ? "再開" : "一時停止"}');
  }

  /// モーダル（≡ドロワー／言語ダイアログ）が閉じた後の描画復帰。
  ///
  /// 実機（Pixel Fold）で、モーダルを開閉すると**再生は続いている
  /// （position は進む・isPlaying も true）のに映像が更新されなくなる**ことを確認した。
  /// 状態からは検知できないため、閉じた合図を受けて `pause`→`play` で描画を張り直す
  /// （アプリ復帰時と同じ手順。実測でこの手順なら必ず復帰する）。
  Future<void> _refreshPlayback() async {
    // 閉じる演出の途中で張り直すと再び止まるため、演出後にもう一度張り直す。
    await _reattach();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await _reattach();
  }

  Future<void> _reattach() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || !mounted) {
      return;
    }
    if (!(_routeVisible && _appResumed)) {
      return;
    }
    await c.pause();
    await c.play();
    debugPrint('ホーム: キャラ動画の描画を張り直した');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    _applyPlayback();
  }

  /// ホームの上に別画面がpushされた（覆われた）。
  @override
  void didPushNext() {
    _routeVisible = false;
    _applyPlayback();
  }

  /// 上の画面がpopされ、ホームへ戻った。
  /// 復帰は `play()` だけでは描画が戻らない（実機確認）ため、張り直しを行う。
  @override
  void didPopNext() {
    _routeVisible = true;
    _refreshPlayback();
  }

  @override
  void dispose() {
    homeVideoRefreshRequest.removeListener(_refreshPlayback);
    shellRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (_ready && c != null) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: c.value.size.width,
            height: c.value.size.height,
            child: VideoPlayer(c),
          ),
        ),
      );
    }
    if (widget.poster != null) {
      return Image.asset(
        widget.poster!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }
    return const ColoredBox(color: Color(0xFF0B1024));
  }
}
