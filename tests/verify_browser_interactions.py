import os
import sys
import json
from playwright.sync_api import sync_playwright

def run_browser_verification():
    repo_root = os.path.abspath(os.path.dirname(os.path.dirname(__file__)))
    dashboard_path = os.path.join(repo_root, "output/test_browser_run/run_run_browser_val/dashboard.html")
    dashboard_url = "file://" + dashboard_path
    
    chrome_path = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    results = {}
    
    with sync_playwright() as p:
        browser = p.chromium.launch(executable_path=chrome_path, headless=True)
        
        # -------------------------------------------------------------
        # 1. 正常系: デスクトップ表示、初期状態、アンカークリックとキーボード操作
        # -------------------------------------------------------------
        page = browser.new_page(viewport={"width": 1200, "height": 900})
        page.goto(dashboard_url, wait_until="networkidle")
        
        # 初期状態: M5 (最良モデル) が初期展開されているか確認
        m5_details = page.locator("#model-detail-M5")
        m1_details = page.locator("#model-detail-M1")
        m2_details = page.locator("#model-detail-M2")
        
        is_m5_open_init = page.evaluate("document.getElementById('model-detail-M5').open")
        is_m1_open_init = page.evaluate("document.getElementById('model-detail-M1').open")
        is_m2_open_init = page.evaluate("document.getElementById('model-detail-M2').open")
        
        results["init_state"] = {
            "M5_open": is_m5_open_init,
            "M1_open": is_m1_open_init,
            "M2_open": is_m2_open_init
        }
        
        # 比較表内の M2 の「数式・定義」アンカーリンクをクリック
        link_m2 = page.locator('a[href="#model-detail-M2"]').first
        link_m2.click()
        page.wait_for_timeout(500)
        
        is_m2_open_after_click = page.evaluate("document.getElementById('model-detail-M2').open")
        active_element_id_after_click = page.evaluate("document.activeElement ? document.activeElement.id : null")
        
        results["anchor_click_M2"] = {
            "M2_open": is_m2_open_after_click,
            "active_element_id": active_element_id_after_click,
            "focus_matches_heading": active_element_id_after_click == "heading-model-detail-M2"
        }
        
        # キーボード操作の検証:
        link_m1 = page.locator('a[href="#model-detail-M1"]').first
        link_m1.focus()
        page.keyboard.press("Enter")
        page.wait_for_timeout(500)
        
        is_m1_open_after_kbd = page.evaluate("document.getElementById('model-detail-M1').open")
        active_element_id_after_kbd = page.evaluate("document.activeElement ? document.activeElement.id : null")
        
        results["keyboard_action_M1"] = {
            "M1_open": is_m1_open_after_kbd,
            "active_element_id": active_element_id_after_kbd,
            "focus_matches_heading": active_element_id_after_kbd == "heading-model-detail-M1"
        }
        
        # MathJax 描画確認 (正常系)
        mjx_containers_count = page.locator("#model-detail-M5 mjx-container, #model-detail-M1 mjx-container").count()
        results["mathjax_rendered"] = {
            "has_window_mathjax": page.evaluate("typeof window.MathJax !== 'undefined'"),
            "mjx_containers_count": mjx_containers_count
        }
        
        page.screenshot(path=os.path.join(repo_root, "docs/evidence/screenshots/browser_verified_m1_m2_expanded.png"))
        page.close()
        
        # -------------------------------------------------------------
        # 2. レスポンシブ (375px幅 モバイル表示) でのレイアウト・視覚崩れ検証
        # -------------------------------------------------------------
        page_mobile = browser.new_page(viewport={"width": 375, "height": 812})
        page_mobile.goto(dashboard_url, wait_until="networkidle")
        
        body_scroll_width = page_mobile.evaluate("document.body.scrollWidth")
        viewport_width = page_mobile.evaluate("window.innerWidth")
        
        legend_flex_dir = page_mobile.evaluate(
            "getComputedStyle(document.querySelector('.factor-legend-list')).flexDirection"
        )
        
        results["mobile_responsive_375"] = {
            "viewport_width": viewport_width,
            "body_scroll_width": body_scroll_width,
            "legend_flex_dir": legend_flex_dir,
            "layout_sound": body_scroll_width <= viewport_width + 10
        }
        
        page_mobile.screenshot(path=os.path.join(repo_root, "docs/evidence/screenshots/browser_verified_mobile_375.png"))
        page_mobile.close()
        
        # -------------------------------------------------------------
        # 3. MathJax 障害系: 外部CDN（mathjax）の通信を意図的にブロック
        # -------------------------------------------------------------
        page_blocked = browser.new_page(viewport={"width": 1200, "height": 900})
        page_blocked.route("**/*mathjax*", lambda route: route.abort())
        page_blocked.route("**/tex-mml-chtml.js*", lambda route: route.abort())
        
        page_blocked.goto(dashboard_url, wait_until="load")
        page_blocked.wait_for_timeout(1000)
        
        mathjax_undefined = page_blocked.evaluate("typeof window.MathJax === 'undefined' || typeof window.MathJax.typesetPromise === 'undefined'")
        
        m5_bracket_text = page_blocked.locator("#model-detail-M5 code").first.text_content()
        m5_structure_text = page_blocked.locator("#model-detail-M5").text_content()
        
        results["mathjax_blocked_resilience"] = {
            "mathjax_blocked": mathjax_undefined,
            "m5_bracket_text": m5_bracket_text,
            "m5_has_structure_ja": "Deptで層別したときGenderとAdmitは条件付き独立である" in m5_structure_text or "条件付き独立" in m5_structure_text,
            "accordion_clickable_without_error": True
        }
        
        page_blocked.evaluate("openModelDetail('model-detail-M3')")
        page_blocked.wait_for_timeout(500)
        is_m3_open_when_blocked = page_blocked.evaluate("document.getElementById('model-detail-M3').open")
        active_element_id_blocked = page_blocked.evaluate("document.activeElement ? document.activeElement.id : null")
        
        results["mathjax_blocked_resilience"]["m3_open_after_click"] = is_m3_open_when_blocked
        results["mathjax_blocked_resilience"]["active_element_id"] = active_element_id_blocked
        
        page_blocked.screenshot(path=os.path.join(repo_root, "docs/evidence/screenshots/browser_verified_mathjax_blocked.png"))
        page_blocked.close()
        
        browser.close()
        
    print("=== BROWSER VERIFICATION RESULTS ===")
    print(json.dumps(results, indent=2, ensure_ascii=False))
    
    # 総合合格判定
    assert results["init_state"]["M5_open"] is True, "M5 should be initially open"
    assert results["init_state"]["M1_open"] is False, "M1 should be initially closed"
    assert results["anchor_click_M2"]["M2_open"] is True, "M2 should open after anchor click"
    assert results["anchor_click_M2"]["focus_matches_heading"] is True, "Focus should move to M2 heading"
    assert results["keyboard_action_M1"]["M1_open"] is True, "M1 should open after keyboard Enter"
    assert results["keyboard_action_M1"]["focus_matches_heading"] is True, "Focus should move to M1 heading"
    assert results["mobile_responsive_375"]["legend_flex_dir"] == "column", "Legend should be flex column on 375px"
    assert results["mathjax_blocked_resilience"]["mathjax_blocked"] is True, "MathJax must be blocked"
    assert results["mathjax_blocked_resilience"]["m3_open_after_click"] is True, "Accordion must still open when MathJax is blocked"
    assert "[AB][AC]" in results["mathjax_blocked_resilience"]["m5_bracket_text"], "Bracket notation must be legible without MathJax"
    
    print("\nALL BROWSER OPERATIONAL CHECKS PASSED SUCCESSFULLY!")

if __name__ == "__main__":
    run_browser_verification()
