import 'package:flutter/material.dart';

import '../../../core/audio/sound_service.dart';
import '../../../core/state/app_state_scope.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/flow_exit_action.dart';
import '../../shared/speaker_toggle.dart';
import '../../shared/state_message_l10n.dart';

/// テーマ選択（U-06）。
///
/// 2026-09-10 の承認仕様で導線ごとに形が変わる:
///   本日の託宣 … 従来どおりのアイコン付きグリッド（現状維持）
///   リーディング … テーマのプルダウン（上）＋相談内容（下・3000文字まで）を同一画面
///
/// 相談内容の上限はサーバーの `ReadingService.QUESTION_TEXT_MAX_LENGTH` と同じ値。
/// 入力側でも切ることで、送信して初めて弾かれる体験にならないようにしている。
class ThemeSelectionScreen extends StatefulWidget {
  const ThemeSelectionScreen({super.key});

  /// 相談内容の最大文字数（サーバーと同値）。
  static const int questionMaxLength = 3000;

  @override
  State<ThemeSelectionScreen> createState() => _ThemeSelectionScreenState();
}

class _ThemeSelectionScreenState extends State<ThemeSelectionScreen> {
  static const List<IconData> _themeIcons = [
    Icons.self_improvement,
    Icons.wb_twilight,
    Icons.favorite_outline,
    Icons.savings_outlined,
    Icons.work_outline,
    Icons.spa_outlined,
  ];

  final TextEditingController _question = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 戻って再入したときに前回の入力を復元する（保持しているのは状態層）。
    final saved = OracleAppStateScope.of(context).questionText;
    if (_question.text != saved) {
      _question.text = saved;
    }
  }

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  void _proceed(BuildContext context) {
    SoundService.instance.play(OracleSound.tap);
    Navigator.of(context).pushNamed('/shuffle');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: buildOracleAppBar(context, l10n.themeSelectionTitle,
          extraActions: const [FlowExitAction()]),
      body: OracleStateBuilder(
        builder: (context, state) {
          if (state.themes.isEmpty && state.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final isOracle = state.isOracleFlow;
          // リーディングは相談内容が読みの材料（質問タイプ分類）になるため必須。
          final canProceed = state.selectedThemeId != null &&
              (isOracle || state.questionText.trim().isNotEmpty);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                isOracle ? l10n.themePrompt : l10n.themeAndQuestionPrompt,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (state.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    resolveStateMessage(context, state.errorMessage!),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              if (isOracle)
                _ThemeGrid(icons: _themeIcons, lang: lang)
              else ...[
                DropdownButtonFormField<String>(
                  initialValue: state.selectedThemeId,
                  decoration: InputDecoration(
                    labelText: l10n.themeDropdownLabel,
                    border: const OutlineInputBorder(),
                  ),
                  items: state.themes
                      .map(
                        (theme) => DropdownMenuItem<String>(
                          value: theme.themeId,
                          child: Text(theme.nameFor(lang)),
                        ),
                      )
                      .toList(),
                  onChanged: state.loading
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }
                          SoundService.instance.play(OracleSound.tap);
                          state.selectTheme(value);
                        },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _question,
                  maxLength: ThemeSelectionScreen.questionMaxLength,
                  maxLines: 8,
                  minLines: 5,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    labelText: l10n.questionLabel,
                    hintText: l10n.questionHint,
                    alignLabelWithHint: true,
                    border: const OutlineInputBorder(),
                    counterText: l10n.questionCounter(
                      state.questionText.length,
                      ThemeSelectionScreen.questionMaxLength,
                    ),
                  ),
                  onChanged: state.setQuestionText,
                ),
                if (state.questionText.trim().isEmpty)
                  Text(
                    l10n.questionRequired,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: canProceed ? () => _proceed(context) : null,
                child: Text(l10n.proceedToShuffle),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 本日の託宣で使う従来どおりのグリッド（現状維持）。
class _ThemeGrid extends StatelessWidget {
  const _ThemeGrid({required this.icons, required this.lang});

  final List<IconData> icons;
  final String lang;

  @override
  Widget build(BuildContext context) {
    return OracleStateBuilder(
      builder: (context, state) {
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: state.themes.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.65,
          ),
          itemBuilder: (context, index) {
            final theme = state.themes[index];
            final selected = state.selectedThemeId == theme.themeId;
            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: state.loading
                  ? null
                  : () {
                      SoundService.instance.play(OracleSound.tap);
                      state.selectTheme(theme.themeId);
                    },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: selected
                      ? Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.16)
                      : Theme.of(context).colorScheme.surface,
                  border: Border.all(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.22),
                    width: selected ? 1.6 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icons[index % icons.length],
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      theme.nameFor(lang),
                      style: TextStyle(
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
