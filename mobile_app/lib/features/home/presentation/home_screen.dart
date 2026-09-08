import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../core/audio/sound_service.dart';
import '../../../core/state/app_state.dart';
import '../../../core/state/app_state_scope.dart';
import '../../../core/state/state_messages.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/oracle_card_visuals.dart';
import '../../shared/plan_l10n.dart';
import '../../shared/state_message_l10n.dart';
import '../../shell/presentation/main_shell.dart';
import 'widgets/home_character_video.dart';

// 宝石画像(768x1024)内のオーブ中心（実測・fractional）。
const double _kSceneW = 768;
const double _kSceneH = 1024;
const double _kOrbHit = 168; // タップ判定＆発光の直径（768空間）
// 宝石リングがキャラの顔に被らないよう、中心基準で縮小＋下方へオフセットする。
const double _kGemsScale = 0.80;
const double _kGemsDy = 82; // 768x1024空間でのpx

/// ホームタブ（没入型）。背景合成済みのキャラ動画＋宝石＆パーティクル(screen合成)＋
/// タップで発光する5オーブ＋右上のフローティング操作（スピーカー/≡/LANG）。
/// 状態依存（ニックネーム/オフライン/⑨無料上限CTA）は最前面に集約する。
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: <Widget>[
        _HomeScene(),
        _HomeTopOverlay(),
      ],
    );
  }
}

/// 演出層：動画＋宝石(screen合成)＋オーブ。全要素を768x1024空間に置き、
/// FittedBox(cover)で画面に敷く＝宝石とタップ判定・発光が常に一致する。
class _HomeScene extends StatelessWidget {
  const _HomeScene();

  void _push(BuildContext context, String route) =>
      Navigator.of(context).pushNamed(route);

  /// 宝石リングと同じ変換（中心基準の縮小＋下方オフセット）でオーブ位置を合わせる。
  Widget _orbPositioned(_OrbSpec o) {
    const cx0 = _kSceneW / 2;
    const cy0 = _kSceneH / 2;
    final cx = cx0 + (o.fx * _kSceneW - cx0) * _kGemsScale;
    final cy = cy0 + (o.fy * _kSceneH - cy0) * _kGemsScale + _kGemsDy;
    const hit = _kOrbHit * _kGemsScale;
    return Positioned(
      left: cx - hit / 2,
      top: cy - hit / 2,
      width: hit,
      height: hit,
      child: _OrbHotspot(
        size: hit,
        glowColor: o.glow,
        label: o.label,
        onTap: o.onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final orbs = <_OrbSpec>[
      _OrbSpec(0.501, 0.171, const Color(0xFFEFCF8B), l10n.tabReading,
          () => _push(context, '/deck-selection')),
      _OrbSpec(0.169, 0.359, const Color(0xFF48D17A), l10n.historyTitle,
          () => _push(context, '/history')),
      _OrbSpec(0.846, 0.370, const Color(0xFFFF5A5A), l10n.ticketLabel,
          () => _push(context, '/paywall')),
      _OrbSpec(0.214, 0.710, const Color(0xFF4AA8FF), l10n.tabCards,
          () => ShellScope.of(context)?.selectTab(1)),
      _OrbSpec(0.803, 0.706, const Color(0xFFFFD23F), l10n.shopLabel,
          () => ShellScope.of(context)?.selectTab(2)),
    ];

    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: _kSceneW,
          height: _kSceneH,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              // 1) 背景合成済みキャラ動画（無音ループ）
              const Positioned.fill(
                child: HomeCharacterVideo(
                  asset: 'assets/home/character_home.mp4',
                  poster: 'assets/home/bg_temple.png',
                ),
              ),
              // 2) 宝石＆パーティクル（黒地に発光→screen合成）。顔に被らないよう縮小＋下げ。
              Positioned.fill(
                child: _BlendMask(
                  blendMode: BlendMode.screen,
                  child: Transform.translate(
                    offset: const Offset(0, _kGemsDy),
                    child: Transform.scale(
                      scale: _kGemsScale,
                      child: Image.asset(
                        'assets/home/gems_particles.png',
                        fit: BoxFit.fill,
                      ),
                    ),
                  ),
                ),
              ),
              // 3) 各オーブのタップ判定＋発光ブルーム（宝石リングと同じ変換で位置合わせ）
              for (final o in orbs) _orbPositioned(o),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrbSpec {
  const _OrbSpec(this.fx, this.fy, this.glow, this.label, this.onTap);
  final double fx;
  final double fy;
  final Color glow;
  final String label;
  final VoidCallback onTap;
}

/// タップで発光ブルームする透明ホットスポット（オーブ絵は宝石画像側に焼き込み済み）。
class _OrbHotspot extends StatefulWidget {
  const _OrbHotspot({
    required this.size,
    required this.glowColor,
    required this.label,
    required this.onTap,
  });

  final double size;
  final Color glowColor;
  final String label;
  final VoidCallback onTap;

  @override
  State<_OrbHotspot> createState() => _OrbHotspotState();
}

class _OrbHotspotState extends State<_OrbHotspot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 780),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _handleTap() {
    SoundService.instance.play(OracleSound.tap);
    _pulse.forward(from: 0).whenComplete(() {
      if (mounted) {
        _pulse.reverse();
      }
    });
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final g = Curves.easeOut.transform(_pulse.value);
            return Center(
              child: IgnorePointer(
                child: Opacity(
                  opacity: g,
                  child: Container(
                    width: widget.size * (0.72 + 0.5 * g),
                    height: widget.size * (0.72 + 0.5 * g),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: <Color>[
                          Colors.white.withValues(alpha: 0.9),
                          widget.glowColor.withValues(alpha: 0.6),
                          widget.glowColor.withValues(alpha: 0.0),
                        ],
                        stops: const <double>[0.0, 0.42, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 子を指定ブレンドモードで背後（動画）へ合成する。黒地の発光素材をscreenで重ねる用途。
class _BlendMask extends SingleChildRenderObjectWidget {
  const _BlendMask({required this.blendMode, required Widget super.child});

  final BlendMode blendMode;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBlendMask(blendMode);

  @override
  void updateRenderObject(BuildContext context, _RenderBlendMask renderObject) {
    renderObject.blendMode = blendMode;
  }
}

class _RenderBlendMask extends RenderProxyBox {
  _RenderBlendMask(this._blendMode);

  BlendMode _blendMode;
  set blendMode(BlendMode value) {
    if (value != _blendMode) {
      _blendMode = value;
      markNeedsPaint();
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) {
      return;
    }
    context.canvas.saveLayer(offset & size, Paint()..blendMode = _blendMode);
    super.paint(context, offset);
    context.canvas.restore();
  }
}

/// 最前面：右上の操作アイコン（スピーカー/≡/LANG）＋左上の挨拶＋オフライン/⑨エラー。
class _HomeTopOverlay extends StatelessWidget {
  const _HomeTopOverlay();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
        child: OracleStateBuilder(
          builder: (context, state) {
            final l10n = AppLocalizations.of(context)!;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _GreetingPill(
                          text: l10n.welcomeUser(state.displayName),
                          plan: localizedPlanName(context, state.plan),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const _TopIconBar(),
                  ],
                ),
                if (state.offlineMode)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 240),
                        child: _OfflinePill(text: l10n.offlineBanner),
                      ),
                    ),
                  ),
                if (state.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _HomeErrorCard(state: state),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 右上の操作アイコン群（実素材の≡/LANG＋生成したスピーカー）。
class _TopIconBar extends StatelessWidget {
  const _TopIconBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // スピーカー（効果音ON/OFF。OFF時はスラッシュ表示）
        ValueListenableBuilder<bool>(
          valueListenable: SoundService.instance.enabled,
          builder: (context, on, _) => _IconChip(
            asset: 'assets/home/icon_speaker.png',
            muted: !on,
            onTap: () => SoundService.instance.toggle(),
          ),
        ),
        const SizedBox(width: 8),
        // ≡ メニュー（endDrawer）
        Builder(
          builder: (ctx) => _IconChip(
            asset: 'assets/home/icon_menu.png',
            onTap: () {
              SoundService.instance.play(OracleSound.tap);
              Scaffold.of(ctx).openEndDrawer();
            },
          ),
        ),
        const SizedBox(width: 8),
        // LANG 言語切替
        _IconChip(
          asset: 'assets/home/icon_lang.png',
          onTap: () {
            SoundService.instance.play(OracleSound.tap);
            _showLanguageDialog(context);
          },
        ),
      ],
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({required this.asset, required this.onTap, this.muted = false});

  final String asset;
  final VoidCallback onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Opacity(
                opacity: muted ? 0.5 : 1.0,
                child: Image.asset(asset, height: 44, filterQuality: FilterQuality.medium),
              ),
              if (muted)
                const Positioned.fill(child: CustomPaint(painter: _SlashPainter())),
            ],
          ),
        ),
      ),
    );
  }
}

/// スピーカーOFFの斜線。
class _SlashPainter extends CustomPainter {
  const _SlashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final line = Paint()
      ..color = const Color(0xFFFF5A5A)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final a = Offset(size.width * 0.22, size.height * 0.24);
    final b = Offset(size.width * 0.78, size.height * 0.76);
    canvas.drawLine(a, b, outline);
    canvas.drawLine(a, b, line);
  }

  @override
  bool shouldRepaint(covariant _SlashPainter oldDelegate) => false;
}

void _showLanguageDialog(BuildContext context) {
  final state = OracleAppStateScope.of(context);
  final l10n = AppLocalizations.of(context)!;
  final options = <String, String>{
    'system': l10n.languageSystem,
    'ja': l10n.languageJa,
    'en': l10n.languageEn,
    'zh': l10n.languageZh,
  };
  showDialog<void>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: Text(l10n.languageLabel),
      children: options.entries.map((e) {
        final selected = state.languagePreference == e.key;
        return ListTile(
          title: Text(e.value),
          trailing: selected
              ? Icon(Icons.check, color: Theme.of(dialogContext).colorScheme.primary)
              : null,
          onTap: () {
            state.setLanguagePreference(e.key);
            Navigator.of(dialogContext).pop();
          },
        );
      }).toList(),
    ),
  );
}

/// ニックネーム挨拶＋プランの小ピル（④ニックネーム表示の維持）。
class _GreetingPill extends StatelessWidget {
  const _GreetingPill({required this.text, required this.plan});

  final String text;
  final String plan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kOracleGold.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.workspace_premium, size: 14, color: kOracleGoldBright),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            plan,
            style: TextStyle(
              color: kOracleGoldBright.withValues(alpha: 0.95),
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// オフライン表示ピル。
class _OfflinePill extends StatelessWidget {
  const _OfflinePill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .tertiaryContainer
            .withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.cloud_off, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// ホームのエラーカード。無料1日1回上限のみCTAを「プラン購入」にする（⑨）。
class _HomeErrorCard extends StatelessWidget {
  const _HomeErrorCard({required this.state});

  final OracleAppState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final message = state.errorMessage!;
    final isFreeLimit = message == StateMessages.freeDailyLimit;
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: ListTile(
        title: Text(
          resolveStateMessage(context, message),
          style: const TextStyle(fontSize: 13),
        ),
        trailing: isFreeLimit
            ? FilledButton(
                onPressed: () => Navigator.of(context).pushNamed('/paywall'),
                child: Text(l10n.goToPaywall),
              )
            : TextButton(
                onPressed: state.loading ? null : state.retryLastLoad,
                child: Text(l10n.retry),
              ),
      ),
    );
  }
}
