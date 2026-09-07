@echo off
chcp 65001 > nul
cd /d "%~dp0"
set ORACLE_SERVER_HOST=0.0.0.0
set PYTHONUTF8=1
echo ============================================================
echo  オラクルアプリ 開発サーバー（LAN公開モード）
echo  実機はこのPCと同じWi-Fiでオンラインモードになります。
echo  停止するには Ctrl+C か、このウィンドウを閉じてください。
echo  （サーバー停止中もアプリはオフラインモードで動作します）
echo ============================================================
".venv\Scripts\python.exe" scripts\run_dev_server.py
pause
