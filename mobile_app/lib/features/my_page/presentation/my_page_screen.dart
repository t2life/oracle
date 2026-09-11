import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/config/app_links.dart';
import '../../../core/state/app_state.dart';
import '../../../core/state/app_state_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/app_actions.dart';
import '../../shared/plan_l10n.dart';
import '../../shared/state_message_l10n.dart';

/// マイページタブ（シェル内。Scaffold/AppBarはシェルが提供）。
class MyPageTab extends StatelessWidget {
  const MyPageTab({super.key});

  /// テーマ見本は配色ルール（`app_theme.dart` のパレット）から生成する＝色の二重定義を作らない。
  /// 円の塗り＝背景色、縁＝アクセント色で「地色と操作色の組」を1粒で示す。
  static List<({String id, Color fill, Color edge})> get _themeSwatches => [
        for (final id in oracleThemeOrder)
          (
            id: id,
            fill: paletteFor(id).background,
            edge: paletteFor(id).accent,
          ),
      ];

  Future<void> _restorePurchase(BuildContext context) async {
    final state = OracleAppStateScope.of(context);
    await state.restoreTicket20();
  }

  Future<void> _pickThemeImage(BuildContext context) async {
    final state = OracleAppStateScope.of(context);
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
    );
    if (picked == null) {
      return;
    }
    // 端末内のアプリ領域へコピー（元画像の削除・移動に影響されないようにする）
    final dir = await getApplicationDocumentsDirectory();
    final dest = File(
      '${dir.path}/theme_bg_${DateTime.now().millisecondsSinceEpoch}.img',
    );
    await File(picked.path).copy(dest.path);
    await state.setThemeImagePath(dest.path);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return OracleStateBuilder(
      builder: (context, state) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(state.displayName),
              subtitle: Text(l10n.visitCountLabel(state.visitCount)),
              trailing: TextButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(l10n.nicknameEdit),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _NicknameEditPage(),
                  ),
                ),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.workspace_premium_outlined),
                title: Text(
                  l10n.planLabel(localizedPlanName(context, state.plan)),
                ),
                subtitle: Text(l10n.ticketBalanceLabel(state.tickets)),
              ),
            ),
            const SizedBox(height: 8),
            _LanguageCard(state: state),
            const SizedBox(height: 8),
            _ThemeCard(
              state: state,
              swatches: _themeSwatches,
              onPickImage: () => _pickThemeImage(context),
            ),
            if (state.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  resolveStateMessage(context, state.errorMessage!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (state.infoMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(resolveStateMessage(context, state.infoMessage!)),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: state.loading ? null : () => _restorePurchase(context),
              child: Text(l10n.restoreTicket20),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pushNamed('/inquiry'),
              child: Text(l10n.goToInquiry),
            ),
            const SizedBox(height: 12),
            // 2026-09-10 承認: 「プラン購入画面へ」を外し、アプリ本体まわりの
            // 導線をここへ集約する（プラン購入は≡メニューではなく残数表示から辿る）。
            Card(
              child: Column(
                children: [
                  ListTile(
                    // ストア未公開のあいだは押せない（掲載前のURLは開けない）
                    enabled: AppLinks.storeListingUrl.isNotEmpty,
                    leading: const Icon(Icons.star_outline),
                    title: Text(l10n.rateApp),
                    subtitle: AppLinks.storeListingUrl.isEmpty
                        ? Text(l10n.comingSoon)
                        : null,
                    trailing: AppLinks.storeListingUrl.isEmpty
                        ? null
                        : const Icon(Icons.open_in_new),
                    onTap: AppLinks.storeListingUrl.isEmpty
                        ? null
                        : () => openStoreListing(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.ios_share),
                    title: Text(l10n.shareApp),
                    onTap: () => shareApp(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.phonelink_setup_outlined),
                    title: Text(l10n.transferCodeTitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        Navigator.of(context).pushNamed('/transfer-code'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.apps_outlined),
                    title: Text(l10n.developerApps),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () => openDeveloperApps(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(l10n.legalInfoTitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).pushNamed('/legal-info'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({required this.state});

  final OracleAppState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: DropdownButtonFormField<String>(
          initialValue: state.languagePreference,
          decoration: InputDecoration(
            labelText: l10n.languageLabel,
            border: InputBorder.none,
          ),
          items: [
            DropdownMenuItem(value: 'system', child: Text(l10n.languageSystem)),
            DropdownMenuItem(value: 'ja', child: Text(l10n.languageJa)),
            DropdownMenuItem(value: 'en', child: Text(l10n.languageEn)),
            DropdownMenuItem(value: 'zh', child: Text(l10n.languageZh)),
          ],
          onChanged: (value) {
            if (value != null) {
              state.setLanguagePreference(value);
            }
          },
        ),
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.state,
    required this.swatches,
    required this.onPickImage,
  });

  final OracleAppState state;
  final List<({String id, Color fill, Color edge})> swatches;
  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.displayThemeLabel,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final swatch in swatches)
                  _SwatchDot(
                    fill: swatch.fill,
                    edge: swatch.edge,
                    selected: state.themePreference == swatch.id,
                    onTap: () => state.setThemePreference(swatch.id),
                  ),
                // ユーザー画像テーマ
                GestureDetector(
                  onTap: onPickImage,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: state.themePreference == 'image'
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.withValues(alpha: 0.5),
                        width: state.themePreference == 'image' ? 3 : 1,
                      ),
                      image: (state.themeImagePath != null &&
                              File(state.themeImagePath!).existsSync())
                          ? DecorationImage(
                              image: FileImage(File(state.themeImagePath!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: (state.themeImagePath == null)
                        ? const Icon(Icons.add_photo_alternate_outlined,
                            size: 20)
                        : null,
                  ),
                ),
              ],
            ),
            // 画像テーマ選択時のみスクリム濃度スライダー（可読性調整・指摘事項1）
            if (state.themePreference == 'image') ...[
              const SizedBox(height: 12),
              Text(l10n.imageScrimLabel,
                  style: Theme.of(context).textTheme.bodySmall),
              Slider(
                value: state.imageScrim,
                min: 0.2,
                max: 0.85,
                onChanged: (value) => state.setImageScrim(value),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// テーマ見本の粒（塗り＝背景色／縁＝アクセント色）。
class _SwatchDot extends StatelessWidget {
  const _SwatchDot({
    required this.fill,
    required this.edge,
    required this.selected,
    required this.onTap,
  });

  final Color fill;
  final Color edge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(color: edge, width: selected ? 4 : 2),
        ),
        child: selected ? Icon(Icons.check, size: 20, color: edge) : null,
      ),
    );
  }
}

/// マイページからのニックネーム編集（初回設定画面の非初回モード）。
class _NicknameEditPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // nickname_screen の編集モードを流用
    return const _NicknameEditProxy();
  }
}

class _NicknameEditProxy extends StatelessWidget {
  const _NicknameEditProxy();

  @override
  Widget build(BuildContext context) {
    // 遅延importを避けるためここで直接構築（isInitialSetup=false）
    return const _NicknameEditInline();
  }
}

class _NicknameEditInline extends StatefulWidget {
  const _NicknameEditInline();

  @override
  State<_NicknameEditInline> createState() => _NicknameEditInlineState();
}

class _NicknameEditInlineState extends State<_NicknameEditInline> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: OracleAppStateScope.of(context).nickname);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      return;
    }
    final state = OracleAppStateScope.of(context);
    await state.saveNickname(name);
    if (mounted && state.errorMessage == null) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.nicknameTitle)),
      body: OracleStateBuilder(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            children: [
              Text(l10n.nicknamePrompt,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                maxLength: 20,
                decoration: InputDecoration(
                  labelText: l10n.nicknameLabel,
                  border: const OutlineInputBorder(),
                  counterText: '',
                ),
                onSubmitted: (_) => _save(),
              ),
              if (state.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    resolveStateMessage(context, state.errorMessage!),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: state.loading ? null : _save,
                child: Text(l10n.nicknameSave),
              ),
            ],
          );
        },
      ),
    );
  }
}
