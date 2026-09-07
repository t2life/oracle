import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/state/app_state.dart';
import '../../../core/state/app_state_scope.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/oracle_card_visuals.dart';
import '../../shared/plan_l10n.dart';
import '../../shared/state_message_l10n.dart';

/// マイページタブ（シェル内。Scaffold/AppBarはシェルが提供）。
class MyPageTab extends StatelessWidget {
  const MyPageTab({super.key});

  static const List<({String id, Color color})> _themeSwatches = [
    (id: 'dark', color: Color(0xFF221C3A)),
    (id: 'light', color: Color(0xFFF3EFE4)),
    (id: 'pink', color: Color(0xFFEC6BA0)),
    (id: 'skyblue', color: Color(0xFF4FB0E0)),
    (id: 'lime', color: Color(0xFF9CCC65)),
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
              onPressed: () => Navigator.of(context).pushNamed('/paywall'),
              child: Text(l10n.goToPaywall),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pushNamed('/inquiry'),
              child: Text(l10n.goToInquiry),
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
  final List<({String id, Color color})> swatches;
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
                    color: swatch.color,
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
                            ? kOracleGold
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

class _SwatchDot extends StatelessWidget {
  const _SwatchDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
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
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? kOracleGold : Colors.grey.withValues(alpha: 0.5),
            width: selected ? 3 : 1,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, size: 20, color: kOracleGold)
            : null,
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
