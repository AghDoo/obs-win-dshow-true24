# OBS win-dshow True 24

為 OBS Studio **33.0.1** 的 Windows DirectShow 擷取來源增加獨立的 **24 FPS** 選項，同時保留原本的 **24 film（24000/1001，約 23.976 FPS）**。

本專案只保存補丁、建置流程與安裝工具，不複製或維護整份 OBS Studio 原始碼。

## 修改內容

上游檔案：

- Repository: [obsproject/obs-studio](https://github.com/obsproject/obs-studio)
- Tag: `33.0.1`
- Commit: `65c320b46e1af5c7a555161aea6182cdf7a8c524`
- File: `plugins/win-dshow/win-dshow.cpp`
- Table: `validFPSFormats[]`

補丁只新增：

```cpp
{"24", MAKE_DSHOW_FPS(24)},
```

原有的 `24 film`（24000/1001）不會被取代或重新命名。

### DirectShow 時間精度

DirectShow 的 frame interval 使用 100ns 整數時間單位。OBS 的 `MAKE_DSHOW_FPS(24)` 會將 10,000,000 / 24 轉成整數 interval，因此底層存在極小的量化誤差。這個選項的目的，是讓 OBS 可以要求裝置提供名義上的 **24.000 FPS 模式**，而不是把 23.976 FPS 當成 24 FPS。

選項是否可用，仍由裝置在指定解析度與像素格式下回報的 DirectShow capabilities 決定。若驅動程式沒有提供相容模式，OBS 可能會將該選項停用。

## Windows x64 建置

GitHub Actions 使用 OBS 官方 33.0.1 建置系統及 Windows / Visual Studio 2026 runner。

建置流程：

1. 取得 OBS Studio 33.0.1 與其 submodules。
2. 驗證上游 commit SHA。
3. 使用 `git apply --check` 驗證並套用本專案補丁。
4. 使用 OBS 的 `windows-ci-x64` CMake preset 設定建置。
5. 只建置 `win-dshow` target 及其必要相依項目，不建置整套 OBS Studio。
6. 驗證輸出為 Windows x64 PE DLL。
7. 將 DLL、安裝腳本與還原腳本打包成 ZIP。

### 取得 DLL

1. 開啟本 Repository 的 **Actions**。
2. 選擇 **Build win-dshow True 24**。
3. 開啟最新成功的 workflow run。
4. 在 **Artifacts** 下載 `obs-win-dshow-true24-obs-33.0.1-windows-x64`。
5. 解壓縮 ZIP。

Artifact 預設保留 **1 天**；需要時可重新執行 workflow。

## 安裝

**僅適用於 OBS Studio 33.0.1 Windows x64。**

1. 完全關閉 OBS Studio。
2. 將下載的 ZIP 解壓縮。
3. 在解壓縮資料夾內，以系統管理員身分開啟 PowerShell。
4. 執行以下命令（請依實際安裝路徑調整）：

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\install-true24.ps1 -ObsRoot "D:\Program Files\obs-studio"
```

安裝腳本會：

- 確認 PowerShell 具有系統管理員權限。
- 確認 OBS 程序已關閉。
- 確認目標檔案存在，避免套用到不符合預期的 OBS 安裝結構。
- 首次安裝時，在原 DLL 旁建立 `win-dshow.dll.bak.original`。
- 若該原始備份已存在，保留原檔，不會用後續版本覆寫。
- 安裝後以 SHA-256 驗證 DLL。
- 若安裝失敗，嘗試使用原始備份還原。

目標檔案：

```text
<OBS 安裝目錄>\core\win-dshow\win-dshow.dll
```

## 還原原始 DLL

完全關閉 OBS Studio，並以系統管理員身分開啟 PowerShell：

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\restore-original.ps1 -ObsRoot "D:\Program Files\obs-studio"
```

還原腳本會使用 `win-dshow.dll.bak.original`，並保留備份檔，不會刪除它。

如需指定其他備份檔：

```powershell
.\restore-original.ps1 -ObsRoot "D:\Program Files\obs-studio" -BackupPath "D:\path\to\win-dshow.dll.bak"
```

## 限制與注意事項

- 只修改 OBS 33.0.1 的 Windows DirectShow 模組。
- 不修改 OBS 主程式、其他 plugin、設定檔或 GC551 驅動程式。
- 不保證所有擷取卡、解析度及像素格式都支援 24 FPS；實際可用性取決於裝置驅動程式回報的 capabilities。
- 本專案產出的 DLL 是自行編譯版本，並非 OBS 官方發行的二進位檔。
- 更換 DLL 前請先關閉 OBS；若遇到載入或擷取問題，請使用還原腳本。

## License

本 Repository 保留建立時附帶的 GPL v2 授權檔。OBS Studio 上游專案及其授權資訊請參閱 [obsproject/obs-studio](https://github.com/obsproject/obs-studio)。
