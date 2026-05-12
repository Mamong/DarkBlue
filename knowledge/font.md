在 iOS 和 macOS 中，语义化动态字体（Dynamic Type）对应的 点（Points） 大小如下。
请注意：iOS 的数值会随着用户在系统设置中调整“字体大小”而变化，以下给出的是默认（Large）级别下的基准值。
## 1. 标题类 (Heading)

| 语义化名称 | iOS 基准字号 | macOS 基准字号 | 视觉用途 |
|---|---|---|---|
| .largeTitle | 34 pt | 26 pt | 页面大标题（仅 iOS 常用） |
| .title | 28 pt | 22 pt | 一级标题 |
| .title2 | 22 pt | 17 pt | 二级标题 |
| .title3 | 20 pt | 15 pt | 三级标题 |

## 2. 正文与强调类 (Body & Emphasis)

| 语义化名称 | iOS 基准字号 | macOS 基准字号 | 视觉用途 |
|---|---|---|---|
| .headline | 17 pt (加粗) | 13 pt (加粗) | 列表项标题、重要信息 |
| .body | 17 pt | 13 pt | 默认正文大小 |
| .callout | 16 pt | 12 pt | 引用、说明性文字 |
| .subheadline | 15 pt | 11 pt | 副标题、备注 |

## 3. 辅助类 (Secondary)

| 语义化名称 | iOS 基准字号 | macOS 基准字号 | 视觉用途 |
|---|---|---|---|
| .footnote | 13 pt | 10 pt | 脚注、次要信息 |
| .caption | 12 pt | 10 pt | 图注、最小标注 |
| .caption2 | 11 pt | 9 pt | 极小补充说明 |

------------------------------
## 💡 为什么你觉得 11pt 差异大？
从上表可以看出：

* iOS 的 .caption2 默认是 11 pt。
* macOS 的 .subheadline 默认也是 11 pt。

关键区别在于：

   1. 渲染基准不同：macOS 默认正文（.body）只有 13 pt，而 iOS 是 17 pt。这意味着在 Mac 上 11 pt 已经非常接近“正常大小”，但在 iOS 上 11 pt 属于“非常小的标注”。
   2. 默认字重（Weight）：同样的 11 pt，macOS 的字形为了清晰度，笔画会处理得比 iOS 略微瘦削一点，在非 Retina 屏幕上尤为明显。

## 🛠 适配建议
如果你想在两端达到“视觉感受一致”：

* 不要混用点数和语义。
* 如果你在 iPad 上觉得 11 pt 合适（即 caption2），在 Mac 上你应该使用 .footnote (10 pt) 或 .subheadline (11 pt)，但要通过代码观察。
* 最好的办法是统一使用 .footnote。在 iPad 上它是 13，在 Mac 上是 10，这符合“手持近、看屏远”的生理缩放比例。

你想看一看如何通过代码实时打印出当前环境下这些语义字体对应的具体字号吗？这能帮你最直观地调试。


