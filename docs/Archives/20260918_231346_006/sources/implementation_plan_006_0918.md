# Dashboard Verification Checklist (`file:///tmp/dbg_dash.html`)

- [x] Open `file:///tmp/dbg_dash.html` in browser -> FAILED (Playwright driver download error: 404 Not Found from azureedge.net)
- [ ] Check console logs and network requests for any external/CDN loading or failed requests
- [ ] Verify Dashboard container, headers, and Japanese text rendering
- [ ] Check visibility and structure of Section 1 to 11:
  - [ ] Section 1: エグゼクティブサマリー (Executive Summary)
  - [ ] Section 2: 全体連関構造と効果量 (Global Association & Effect Size)
  - [ ] Section 3: 局所効果 × 証拠散布図 (Effect × Evidence & Dual-Filter)
  - [ ] Section 4: 調整残差構造 (Adjusted Residual Structure)
  - [ ] Section 5: セル診断エクスプローラー (Cell Explorer) with DataTables
  - [ ] Section 6: 結合事後推論 (Joint Posterior Credible Intervals)
  - [ ] Section 7: 条件付き事後推論 (Conditional Posterior Distributions)
  - [ ] Section 8: 不確実性順位 (Uncertainty Ranking)
  - [ ] Section 9: 独立モデルからの事後乖離 (Posterior Departure from Independence)
  - [ ] Section 10: 事前感度分析 (Prior Sensitivity Analysis)
  - [ ] Section 11: 品質・プロビナンス情報 (Quality & Provenance)
- [ ] Verify DataTables Japanese pagination and search controls in Section 5
- [ ] Capture screenshot artifact if needed

### Status Note

`open_browser_url` failed repeatedly with:
`failed to create browser context: failed to run playwright manager: failed to install playwright: could not install driver: error: got non 200 status code: 404 (404 Not Found) from https://playwright.azureedge.net/builds/driver/playwright-1.57.0-mac-arm64.zip`
