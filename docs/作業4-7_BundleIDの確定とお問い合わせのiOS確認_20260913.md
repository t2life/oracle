# 作業4〜7 Bundle ID の確定と、お問い合わせ（メーラー方式）の iOS 確認（2026-09-13）

- 前提: `docs/作業1-3_Windows更新のiOS影響とシャッフル音の粒子化_調査と方針_20260913.md`（承認 2026-09-13）
- 対象ブランチ: `feature/20260909-home-6fix`（`a5e116f` の上）
- 作業環境: macOS 26.6.2（Intel）／Xcode 26.5／Flutter 3.47.3／iPhone（iOS 26.6.1）

---

## 0. 結論

| # | 項目 | 結果 |
|---|---|---|
| 1 | iOS の Bundle ID | **`com.apps2craft.oracle` に確定**（オーナー決定）。`project.pbxproj` の6箇所を変更 |
| 2 | お問い合わせ（メーラー起動方式）の iOS 動作 | **確認 OK**。メールアプリが開き、送受信も往復で確認 |
| 3 | iOS 側のコード変更 | **なし**（`Info.plist` への追記も不要だった。方針書 §1.2 のとおり） |

---

## 1. 作業4: 実装

### 1.1 Bundle ID の確定

`mobile_app/ios/Runner.xcodeproj/project.pbxproj`

| 対象 | 変更前 | 変更後 |
|---|---|---|
| Runner（Debug / Release / Profile） | `com.apps2craft.oracleMobileApp` | `com.apps2craft.oracle` |
| RunnerTests（Debug / Release / Profile） | `com.apps2craft.oracleMobileApp.RunnerTests` | `com.apps2craft.oracle.RunnerTests` |

- 決め手: 短くアプリ名に近く、Android の `com.apps2craft.oracle_mobile_app` と**同じドメイン**にそろう。
  引き継ぎ書 §2.1 の案B（`_` 入り）は、iOS の Bundle ID が英数字・ハイフン・ピリオドしか使えないため不可。
- iOS の Bundle ID を参照する Dart コード・テストは0件のため、**この1ファイル以外に変更はない**。
- `oracleMobileApp` の綴りはリポジトリから0件になった（`ios/` と `lib/` を全文検索）。
- App Store Connect でのアプリ登録（＝TestFlight の前提）は、この値で進められる。

### 1.2 お問い合わせ（Windows 更新分）

**変更なし。** `launchUrl` は iOS では `canOpenURL` を通らず `UIApplication.open` を直接呼ぶため、
`LSApplicationQueriesSchemes` の追記は要らない（方針書 §1.2）。実機の結果もそのとおりだった。

---

## 2. 作業5: テスト

| 確認 | 結果 |
|---|---|
| `flutter analyze` | **No issues found!** |
| `flutter test` | **+67: All tests passed!**（Windows 側 63＋iOS 側 4） |
| iOS 実機ビルド（release・自動署名 `D7THUVNT5T`） | 成功（57.2秒）→ インストールと起動を確認 |
| 生成された `Runner.app/Info.plist` | `CFBundleIdentifier = com.apps2craft.oracle` / 表示名「日本神話オラクルロンカード」/ 版 0.1.0 (1) |

### 2.1 実機確認（オーナー）

| # | 項目 | 結果 |
|---|---|---|
| 1 | お問い合わせ → 送信でメールアプリが開く | **OK** |
| 2 | 実際の送受信（往復） | **OK** |
| 3 | Bundle ID 変更後のアプリ起動・占いの流れ | **OK** |

Bundle ID が変わるため、旧 ID のアプリは別アプリとして端末に残る。確認後に手で削除する運用とした。

---

## 3. 作業6: 最終チェック

| 観点 | 結果 |
|---|---|
| 変更範囲 | `project.pbxproj` の6行のみ。Dart・アセット・テストは無変更 |
| 命名の一貫性 | Runner と RunnerTests の両方を同時に変更（片方だけ残さない） |
| リグレッション | analyze / 67件 green / 実機で起動・占い・お問い合わせを確認 |
| 触らないファイル | `interpretation_engine.py` / `interpretation_composer.dart` は未変更 |
| 公開リポジトリへの配慮 | 個人情報なし。Team ID は署名済みアプリに含まれる公開情報 |

---

## 4. 作業7: 残件

| # | 内容 | 扱い |
|---|---|---|
| 1 | シャッフル音 | **音源をオーナーが用意**。届き次第、差し替えとループ化を同時に実装（方針書 §5） |
| 2 | TestFlight の準備 | App Store Connect でアプリを登録（Bundle ID は本書で確定）→ アイコン・スクリーンショット・App Privacy・年齢区分 → ビルドのアップロード |
| 3 | ATS 例外（`NSAllowsArbitraryLoads`）の削除 | **提出ビルドでは削除する**。現状は LAN のサーバーへ繋ぐ開発用として残す（引き継ぎ書 §2.2） |
| 4 | アプリアイコン | Flutter の雛形のまま。差し替えが要る（引き継ぎ書 §4-4） |
| 5 | 課金（IAP） | 未実装。月額のお試し無しの反映（規約・特商法・サーバー設定）も含めて別途 |
| 6 | 月額プランの期限計算 | サーバーが「30日＋お試し日数」で決め打ち。App Store の期限を正とする作りへ変更が要る |
| 7 | Android 側の確認 | 札の見切れ修正の見え方（Windows 側） |
