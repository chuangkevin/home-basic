---
name: liquid-glass-ui
description: Use when implementing Apple-style liquid glass / frosted glass (液態玻璃/磨砂玻璃) UI surfaces — toasts, modals, panels, cards, floating bars. Provides proven CSS recipes (frosted default, ultra-transparent droplet variant), the SVG edge-refraction technique, and the pitfalls that make glass look like an opaque white card.
---

# Liquid Glass UI — 液態玻璃實作標準

實戰驗證來源：gitea-html-viewer（Note. 服務）v1.9.1→v1.9.7 的多輪迭代。
預設使用 **磨砂（frosted）** 變體：質感與可讀性的平衡點，適合 toast、modal、面板。

## 核心認知（先讀，不然會做出死白卡片）

1. **blur 太高 = 奶白實心卡**。blur 會把背景糊成均勻底色，再透明的白底也看不出玻璃感。
   磨砂用 20~24px；要「看得穿」的效果必須降到 4px 以下。
2. **玻璃放在純白背景上就是白的**。透明要有東西可透——驗收時務必墊一個有文字、
   有色彩的測試背景，不要在空白頁上判斷效果。
3. **白底不透明度決定「玻璃」還是「卡片」**：`.55` 是磨砂上限；`.78` 以上肉眼已是實心。
4. **box 本身要有 backdrop-filter**。常見錯誤：只給 overlay 加 blur，玻璃面板本體
   沒有 backdrop-filter，看起來就是一張普通半透明卡。
5. **可讀性與透明度互斥**。中心全透（droplet 變體）時，面板文字會跟背景打架。
   給一般使用者（尤其年長者）的產品一律用磨砂。

## 變體 A：磨砂玻璃（預設）

```css
.lg {
  position: relative;
  background: rgba(255,255,255,.55);
  border: 1px solid rgba(255,255,255,.65);
  box-shadow: 0 14px 44px rgba(31,38,135,.2);
  -webkit-backdrop-filter: blur(24px) saturate(180%);
  backdrop-filter: blur(24px) saturate(180%);
}
/* 玻璃質感的關鍵：邊緣高光 + 左上光斑（單一光源感） */
.lg::after {
  content: ""; position: absolute; inset: 0;
  border-radius: inherit; pointer-events: none;
  box-shadow: inset 0 1px 1px rgba(255,255,255,.9),
              inset 0 -1px 1px rgba(255,255,255,.35);
  background: radial-gradient(130% 65% at 18% 0%,
              rgba(255,255,255,.3), rgba(255,255,255,0) 46%);
}
```

要點：
- `saturate(180%)` 讓透出的色彩更鮮豔，是 Apple 玻璃的招牌參數。
- `::after` 蓋整個面板（`pointer-events:none` 不擋點擊），高光與光斑放這裡，
  不要混進本體 box-shadow——分層才好調。
- 深色主題：白底換 `rgba(40,40,45,.55)`，高光降到 `.25`。

## 變體 B：水滴玻璃（中心全透 + 邊緣折射帶）

視覺衝擊強但犧牲可讀性，適合裝飾性元件（slider thumb、浮動按鈕），不適合放文字內容。

```css
.lg-drop {
  position: relative;
  background: rgba(255,255,255,.03);
  box-shadow: 0 18px 55px rgba(31,38,135,.28);
  -webkit-backdrop-filter: blur(1.5px) saturate(160%);
  backdrop-filter: blur(1.5px) saturate(160%);
}
/* 邊緣折射帶：mask 切出環狀區域，單獨重 blur + 波紋扭曲 */
.lg-drop::before {
  content: ""; position: absolute; inset: 0;
  border-radius: inherit; pointer-events: none; box-sizing: border-box;
  padding: var(--lgr, 14px);            /* 折射帶寬度，小元件給 8~9px */
  -webkit-mask: linear-gradient(#fff 0 0) content-box, linear-gradient(#fff 0 0);
  -webkit-mask-composite: xor;
  mask: linear-gradient(#fff 0 0) content-box, linear-gradient(#fff 0 0);
  mask-composite: exclude;
  -webkit-backdrop-filter: blur(12px) saturate(190%) brightness(1.06);
  backdrop-filter: blur(12px) saturate(190%) brightness(1.06);
  /* Chromium 額外疊 SVG 波紋扭曲；不支援的瀏覽器停在上一行（雙重宣告 fallback） */
  backdrop-filter: blur(12px) saturate(190%) brightness(1.06) url(#lg-displace);
}
/* 不對稱高光：左上亮、右下暗 = 單一光源打在玻璃上 */
.lg-drop::after {
  content: ""; position: absolute; inset: 0;
  border-radius: inherit; pointer-events: none;
  box-shadow: inset 0 1.5px 1px rgba(255,255,255,.95),
              inset 0 -1px 1px rgba(255,255,255,.55),
              inset 2px 2px 4px rgba(255,255,255,.6),
              inset -2px -2px 4px rgba(255,255,255,.35),
              inset 0 0 0 1px rgba(255,255,255,.32);
  background: radial-gradient(130% 65% at 18% 0%,
              rgba(255,255,255,.42), rgba(255,255,255,0) 46%);
}
```

SVG 折射 filter（注入 body 一次即可）：

```html
<svg width="0" height="0" style="position:absolute">
  <filter id="lg-displace" x="-30%" y="-30%" width="160%" height="160%">
    <feTurbulence type="fractalNoise" baseFrequency="0.004 0.008" numOctaves="2" result="n"/>
    <feDisplacementMap in="SourceGraphic" in2="n" scale="42"
                       xChannelSelector="R" yChannelSelector="G"/>
  </filter>
</svg>
```

- `backdrop-filter: url(#...)` 只有 Chromium 支援；**一定要先寫一行純函數版**，
  讓 Safari/Firefox parse 失敗時退回上一個宣告。
- `scale` 控制扭曲強度（16 幾乎看不出來，42 明顯）；`baseFrequency` 越低波越平滑。

## 配套規範

- **Modal overlay**：磨砂配 `rgba(15,18,30,.16)` + `blur(4px)`；
  droplet 配 `.08` + `blur(1.5px)`（背景要看得到才有意義）。
- **Toast 定位**：置中於 topbar **下方**（如 `top: 84px`），不要貼齊頂端——
  會跟 topbar 內容疊在一起，看起來像版面壞掉。
- **次要按鈕 / input 也要玻璃化**：`background: rgba(255,255,255,.35)` +
  玻璃邊框 `1px rgba(255,255,255,.55~.6)` + `inset 0 1px 1px rgba(255,255,255,.7)`，
  不要在玻璃面板上放實心白控件。
- **動畫**：進場 `translateY(-16px) scale(.92) → 彈性回正`
  （`cubic-bezier(.34,1.4,.5,1)`，約 .32s），離場縮小淡出 .22s。

## 驗收清單

- [ ] 在「有文字 + 有色彩」的測試背景上截圖驗證，不是空白頁
- [ ] 面板本體有 backdrop-filter（不是只有 overlay 有）
- [ ] 磨砂：背景色塊隱約可見、面板文字清楚可讀
- [ ] droplet：背景文字在中心區清楚可見、邊緣有折射帶
- [ ] 有 `-webkit-` 前綴（Safari）；`url()` filter 有純函數 fallback 宣告
- [ ] toast 不與 topbar 重疊
