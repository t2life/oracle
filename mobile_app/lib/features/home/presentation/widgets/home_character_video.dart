import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// ホーム中央の「ロンさん浮遊」動画（寺院背景を合成済み）。
/// 無音・ループ再生。初期化前と失敗時はポスター静止画にフォールバックする。
class HomeCharacterVideo extends StatefulWidget {
  const HomeCharacterVideo({super.key, required this.asset, this.poster});

  final String asset;
  final String? poster;

  @override
  State<HomeCharacterVideo> createState() => _HomeCharacterVideoState();
}

class _HomeCharacterVideoState extends State<HomeCharacterVideo> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
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
      await c.play();
      setState(() => _ready = true);
    } catch (_) {
      // 初期化失敗はポスター表示のまま継続（非致命）
    }
  }

  @override
  void dispose() {
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
