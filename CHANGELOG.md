# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

## [2026-03-24]

### Added

- **trace-build.sh**: 新增 Jenkins 建置編號超連結功能 (clickable build number via OSC 8)。

### Changed

- **trace-build.sh**:
  - 優化終端機輸出刷新機制，消除畫面閃爍 (flickering)。
  - 改用 ANSI-C 引用方式處理超連結，修正顯示問題。

## [2026-01-06]

### Added

- 新增完整的中文說明文件 (README.md)。
- 建立專案初始化腳本 (init.sh)。

### Changed

- 優化環境變數載入機制。
- 改進憑證安全儲存方式 (Keychain integration)。
