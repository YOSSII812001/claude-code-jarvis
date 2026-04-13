---
name: ui-ux-pro-max
description: "UI/UX design intelligence. 50 styles, 21 palettes, 50 font pairings, 20 charts, 8 stacks (React, Next.js, Vue, Svelte, SwiftUI, React Native, Flutter, Tailwind). Actions: plan, build, create, design, implement, review, fix, improve, optimize, enhance, refactor, check UI/UX code. Projects: website, landing page, dashboard, admin panel, e-commerce, SaaS, portfolio, blog, mobile app, .html, .tsx, .vue, .svelte. Elements: button, modal, navbar, sidebar, card, table, form, chart. Styles: glassmorphism, claymorphism, minimalism, brutalism, neumorphism, bento grid, dark mode, responsive, skeuomorphism, flat design. Topics: color palette, accessibility, animation, layout, typography, font pairing, spacing, hover, shadow, gradient."
---

# UI/UX Pro Max - Design Intelligence

Searchable database of UI styles, color palettes, font pairings, chart types, product recommendations, UX guidelines, and stack-specific best practices.

## Prerequisites

Check if Python is installed:

**Windows:**
```powershell
python --version
```

**macOS/Linux:**
```bash
python3 --version || python --version
```

If Python is not installed:

**Windows:**
```powershell
winget install Python.Python.3.12
```

**macOS:**
```bash
brew install python3
```

**Ubuntu/Debian:**
```bash
sudo apt update && sudo apt install python3
```

---

## How to Use This Skill

When user requests UI/UX work (design, build, create, implement, review, fix, improve), follow this workflow:

### Step 1: Analyze User Requirements

Extract key information from user request:
- **Product type**: SaaS, e-commerce, portfolio, dashboard, landing page, etc.
- **Style keywords**: minimal, playful, professional, elegant, dark mode, etc.
- **Industry**: healthcare, fintech, gaming, education, etc.
- **Stack**: React, Vue, Next.js, or default to `html-tailwind`

### Step 2: Search Relevant Domains

Use `search.py` multiple times to gather comprehensive information. Search until you have enough context.

**Windows:**
```powershell
python .claude/skills/ui-ux-pro-max/scripts/search.py "<keyword>" --domain <domain> -n <max_results>
```

**macOS/Linux:**
```bash
python3 .claude/skills/ui-ux-pro-max/scripts/search.py "<keyword>" --domain <domain> [-n <max_results>]
```

**Recommended search order:**

1. **Product** - Get style recommendations for product type
2. **Style** - Get detailed style guide (colors, effects, frameworks)
3. **Typography** - Get font pairings with Google Fonts imports
4. **Color** - Get color palette (Primary, Secondary, CTA, Background, Text, Border)
5. **Landing** - Get page structure (if landing page)
6. **Chart** - Get chart recommendations (if dashboard/analytics)
7. **UX** - Get best practices and anti-patterns
8. **Stack** - Get stack-specific guidelines (default: html-tailwind)

### Step 3: Stack Guidelines (Default: html-tailwind)

If user doesn't specify a stack, **default to `html-tailwind`**.

**Windows:**
```powershell
python .claude/skills/ui-ux-pro-max/scripts/search.py "<keyword>" --stack html-tailwind
```

**macOS/Linux:**
```bash
python3 .claude/skills/ui-ux-pro-max/scripts/search.py "<keyword>" --stack html-tailwind
```

Available stacks: `html-tailwind`, `react`, `nextjs`, `vue`, `svelte`, `swiftui`, `react-native`, `flutter`

---

## Search Reference

### Available Domains

| Domain | Use For | Example Keywords |
|--------|---------|------------------|
| `product` | Product type recommendations | SaaS, e-commerce, portfolio, healthcare, beauty, service |
| `style` | UI styles, colors, effects | glassmorphism, minimalism, dark mode, brutalism |
| `typography` | Font pairings, Google Fonts | elegant, playful, professional, modern |
| `color` | Color palettes by product type | saas, ecommerce, healthcare, beauty, fintech, service |
| `landing` | Page structure, CTA strategies | hero, hero-centric, testimonial, pricing, social-proof |
| `chart` | Chart types, library recommendations | trend, comparison, timeline, funnel, pie |
| `ux` | Best practices, anti-patterns | animation, accessibility, z-index, loading |
| `prompt` | AI prompts, CSS keywords | (style name) |

### Available Stacks

| Stack | Focus |
|-------|-------|
| `html-tailwind` | Tailwind utilities, responsive, a11y (DEFAULT) |
| `react` | State, hooks, performance, patterns |
| `nextjs` | SSR, routing, images, API routes |
| `vue` | Composition API, Pinia, Vue Router |
| `svelte` | Runes, stores, SvelteKit |
| `swiftui` | Views, State, Navigation, Animation |
| `react-native` | Components, Navigation, Lists |
| `flutter` | Widgets, State, Layout, Theming |

---

## Example Workflow

**User request:** "Create a minimal SaaS dashboard"

**AI should (Windows):**

```powershell
# 1. Search product type
python .claude/skills/ui-ux-pro-max/scripts/search.py "SaaS dashboard" --domain product

# 2. Search style (based on industry: beauty, elegant)
python .claude/skills/ui-ux-pro-max/scripts/search.py "minimal clean" --domain style

# 3. Search typography
python .claude/skills/ui-ux-pro-max/scripts/search.py "professional modern" --domain typography

# 4. Search color palette
python .claude/skills/ui-ux-pro-max/scripts/search.py "saas" --domain color

# 5. Search chart (for dashboard)
python .claude/skills/ui-ux-pro-max/scripts/search.py "trend comparison" --domain chart

# 6. Search UX guidelines
python .claude/skills/ui-ux-pro-max/scripts/search.py "animation" --domain ux
python .claude/skills/ui-ux-pro-max/scripts/search.py "accessibility" --domain ux

# 7. Search stack guidelines (default: html-tailwind)
python .claude/skills/ui-ux-pro-max/scripts/search.py "layout responsive" --stack html-tailwind
```

**Then:** Synthesize all search results and implement the design.

---

## Tips for Better Results

1. **Be specific with keywords** - "healthcare SaaS dashboard" > "app"
2. **Search multiple times** - Different keywords reveal different insights
3. **Combine domains** - Style + Typography + Color = Complete design system
4. **Always check UX** - Search "animation", "z-index", "accessibility" for common issues
5. **Use stack flag** - Get implementation-specific best practices
6. **Iterate** - If first search doesn't match, try different keywords

---

## Common Rules for Professional UI

These are frequently overlooked issues that make UI look unprofessional:

### Icons & Visual Elements

| Rule | Do | Don't |
|------|----|----- |
| **No emoji icons** | Use SVG icons (Heroicons, Lucide, Simple Icons) | Use emojis like as UI icons |
| **Stable hover states** | Use color/opacity transitions on hover | Use scale transforms that shift layout |
| **Correct brand logos** | Research official SVG from Simple Icons | Guess or use incorrect logo paths |
| **Consistent icon sizing** | Use fixed viewBox (24x24) with w-6 h-6 | Mix different icon sizes randomly |

### Interaction & Cursor

| Rule | Do | Don't |
|------|----|----- |
| **Cursor pointer** | Add `cursor-pointer` to all clickable/hoverable cards | Leave default cursor on interactive elements |
| **Hover feedback** | Provide visual feedback (color, shadow, border) | No indication element is interactive |
| **Smooth transitions** | Use `transition-colors duration-200` | Instant state changes or too slow (>500ms) |

### Light/Dark Mode Contrast

| Rule | Do | Don't |
|------|----|----- |
| **Glass card light mode** | Use `bg-white/80` or higher opacity | Use `bg-white/10` (too transparent) |
| **Text contrast light** | Use `#0F172A` (slate-900) for text | Use `#94A3B8` (slate-400) for body text |
| **Muted text light** | Use `#475569` (slate-600) minimum | Use gray-400 or lighter |
| **Border visibility** | Use `border-gray-200` in light mode | Use `border-white/10` (invisible) |

### Layout & Spacing

| Rule | Do | Don't |
|------|----|----- |
| **Floating navbar** | Add `top-4 left-4 right-4` spacing | Stick navbar to `top-0 left-0 right-0` |
| **Content padding** | Account for fixed navbar height | Let content hide behind fixed elements |
| **Consistent max-width** | Use same `max-w-6xl` or `max-w-7xl` | Mix different container widths |

---

## Pre-Delivery Checklist

Before delivering UI code, verify these items:

### Visual Quality
- [ ] No emojis used as icons (use SVG instead)
- [ ] All icons from consistent icon set (Heroicons/Lucide)
- [ ] Brand logos are correct (verified from Simple Icons)
- [ ] Hover states don't cause layout shift
- [ ] Use theme colors directly (bg-primary) not var() wrapper

### Interaction
- [ ] All clickable elements have `cursor-pointer`
- [ ] Hover states provide clear visual feedback
- [ ] Transitions are smooth (150-300ms)
- [ ] Focus states visible for keyboard navigation

### Light/Dark Mode
- [ ] Light mode text has sufficient contrast (4.5:1 minimum)
- [ ] Glass/transparent elements visible in light mode
- [ ] Borders visible in both modes
- [ ] Test both modes before delivery

### Layout
- [ ] Floating elements have proper spacing from edges
- [ ] No content hidden behind fixed navbars
- [ ] Responsive at 320px, 768px, 1024px, 1440px
- [ ] No horizontal scroll on mobile

### Accessibility
- [ ] All images have alt text
- [ ] Form inputs have labels
- [ ] Color is not the only indicator
- [ ] `prefers-reduced-motion` respected

---

## トラブルシューティング

### Q: search.py の実行でエラーが出る
**A:** (1) Python がインストールされているか確認してください（Windows: `python --version`、macOS/Linux: `python3 --version`）。(2) スクリプトのパスが正しいか確認してください（`.claude/skills/ui-ux-pro-max/scripts/search.py`）。(3) Windows で `python` コマンドが動かない場合は `py` コマンドを試してください。

### Q: どのスタイルを選べばよいか分からない
**A:** まず `--domain product` でプロダクトタイプに基づく推奨スタイルを検索してください。業界や用途に応じた推奨が返されます。迷う場合は `minimalism`（SaaS/ビジネス向け）や `glassmorphism`（モダンなダッシュボード向け）から始めるのが安全です。

### Q: ライトモードとダークモードで見た目が大きく崩れる
**A:** 「Common Rules for Professional UI」の「Light/Dark Mode Contrast」セクションを確認してください。特にライトモードでは `bg-white/10`（透明すぎ）や `text-gray-400`（コントラスト不足）が原因になりがちです。`bg-white/80` 以上、テキストは `slate-900` を基準にしてください。

---

## 関連スキル

- **ux-psychology** -- UX心理学原則。43の心理学原則をUI実装に適用する際の理論的裏付けとして連携
- **liftkit** -- LiftKit UIフレームワーク。黄金比ベースのデザインシステムとui-ux-pro-maxのスタイル推奨を組み合わせて使用
- **playwright** -- ブラウザ自動操作。実装したUIのE2Eテスト・スクリーンショット検証に使用
- **e2e-test** -- E2Eテストプロセス。UI実装後のレスポンシブ確認・クロスブラウザテストの手順

---

## 改訂履歴

| 日付 | 版 | 変更内容 |
|------|-----|----------|
| 2025-08-15 | v1.0 | 初版作成。50スタイル、21パレット、50フォントペアリング、20チャートタイプ、8スタック対応、search.pyスクリプトを収録 |
| 2026-03-04 | v1.1 | トラブルシューティング、関連スキル、改訂履歴を追加 |
