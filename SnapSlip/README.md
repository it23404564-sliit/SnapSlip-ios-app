# SnapSlip — Smart Receipt & Expense Tracker (iOS)

SE4041 Mobile Application Design and Development · Assignment 02 · Part A

SnapSlip turns a photo of a paper receipt into a categorised expense in a few seconds, **entirely on the device**. Vision reads the receipt, a parser pulls out the shop, date, items and total, and an on-device Core ML / NaturalLanguage pipeline suggests the spending category. The app learns from every correction you make.

It is designed for Sri Lankan university students and young professionals: people who pay mostly in cash, collect paper bills, use day-first dates and rupee amounts (Rs. / LKR), and want to stay within a monthly budget without typing every expense.

---

## Requirements

| | |
|---|---|
| Xcode | 16.0 or later (Xcode 26 recommended) |
| iOS deployment target | 17.0 |
| Devices | iPhone and iPad, portrait and landscape |
| Frameworks | SwiftUI, SwiftData, Vision, VisionKit, Core ML, NaturalLanguage, Swift Charts, PhotosUI, ImageIO, OSLog |
| Third-party packages | None |

## Build & run

1. Open `SnapSlip.xcodeproj` in Xcode.
2. Select the **SnapSlip** target → *Signing & Capabilities* → choose your Team (a free Apple ID works for the Simulator and your own device).
3. Pick an iPhone simulator (e.g. iPhone 16) and press **⌘R**.
4. On first launch, complete the short onboarding. Then either:
   - tap the round **scan button** → **Try a sample receipt** (works in the Simulator, which has no camera), or
   - **Settings → Load sample data** to fill the dashboards with four months of example expenses.

On a real iPhone, **Scan with camera** opens VisionKit's document scanner with automatic edge detection.

> If the project ever fails to open (for example in an older Xcode), regenerate it with XcodeGen:
> `brew install xcodegen && xcodegen generate` (uses `project.yml`).

## Run the tests

- **⌘U** runs everything in the shared *SnapSlip* scheme (code coverage is switched on).
- `SnapSlipTests` — unit tests written with **Swift Testing**: receipt parser, categoriser, analytics, SwiftData repository, merchant memory, scan view model (with a fake OCR engine), CSV export.
- `SnapSlipUITests` — **XCUITest** flows: tab navigation, manual entry, search, category filter, the full sample-receipt scan, theme switching, onboarding, plus launch-time and scrolling performance metrics.

UI tests launch the app with `-uiTesting -seedSampleData`, which uses an in-memory store and fixed settings, so each run is repeatable and never touches your real data.

## Train the Core ML model (optional but recommended)

The app works out of the box with keyword rules and NaturalLanguage word embeddings. To switch on the Core ML classifier:

```bash
cd MLTraining
swift TrainClassifier.swift        # needs macOS (Create ML)
```

Drag the generated `ReceiptCategoryClassifier.mlmodel` into the `SnapSlip` folder in Xcode, then build again. **Settings → Smart categories → Category engine** will now show *Core ML model*. You can also train it without code in the **Create ML** app (Text Classifier template, `receipt_categories.csv` as the training data).

## Features

| Area | What's in it |
|---|---|
| **Scan** | VisionKit document camera · Photos picker · rendered sample receipts · animated "laser" scanning state · Vision text boxes drawn over the receipt · editable review form |
| **On-device ML** | `VNRecognizeTextRequest` OCR · row re-assembly · receipt parser (total, date, merchant, items, currency) · category pipeline: personal rules → Core ML text classifier → keyword rules → word embeddings · confidence meter with the engine shown |
| **Learns from you** | Changing a suggested category stores a merchant rule (SwiftData) that is applied first next time; review or delete rules under *Settings → Learned shops* |
| **Overview** | Animated budget ring (custom `Shape`), numeric roll-up, today / daily average / month-end projection, category bar chart, recent expenses |
| **Expenses** | Store-level search and category filter (`#Predicate`), grouped by day, swipe to edit/delete, long-press preview & context menu, iOS 18 zoom transition |
| **Insights** | Interactive donut (`chartAngleSelection`), spending pace vs ideal, six-month trend with budget rule line, top places, plain-language insight |
| **Settings** | Accent themes, light/dark override, currency, monthly and per-category budgets, CSV export (opens in Numbers/Excel and in SnapSlip Spatial), sample data, erase all |
| **Adaptive** | `TabView` on iPhone, `NavigationSplitView` sidebar on iPad and wide screens, side-by-side scan review in landscape, `ViewThatFits` and `AnyLayout` for Dynamic Type |
| **Accessibility** | Dark Mode colour assets, Dynamic Type (accessibility sizes switch rows to a vertical layout), VoiceOver labels/values, Reduce Motion respected by every custom animation |

## Project structure

```
SnapSlip/
├── App/              entry point, router, dependency container, settings keys
├── Models/           SwiftData @Model types, ExpenseDraft, categories
├── Persistence/      container + versioned schema, repository, merchant memory, sample data
├── Services/         Vision OCR, receipt parser, categoriser, image processing, analytics, CSV
├── DesignSystem/     theme tokens, custom modifiers & button styles, reusable components
│   └── Components/   BudgetRingView, FlowLayout, ZoomableImageView, CommonViews
├── Views/            Root · Onboarding · Dashboard · Expenses · Scan · Insights · Settings
└── Resources/        Assets.xcassets (app icon with dark & tinted variants, colour sets)
SnapSlipTests/        Swift Testing unit tests
SnapSlipUITests/      XCUITest UI and performance tests
MLTraining/           Create ML training data and script
```

### Architecture in one paragraph

SwiftUI views observe SwiftData through `@Query` for live lists. Anything that writes goes through `ExpenseRepository` or `MerchantMemory`, so the logic is shared and unit-testable. The scan flow is driven by an `@Observable` `ScanViewModel` that receives its OCR engine, categoriser and parser as protocol-typed dependencies from `AppServices`; tests swap in a fake recogniser. Pure logic (parser, analytics, CSV) has no UI or framework dependencies. Navigation is centralised in `AppRouter`: each tab owns a typed `NavigationStack` path, so code such as "open the expense I just saved" is one call.

## Privacy

No network code. Receipt images, recognised text, and the ML model all stay on the device. The camera permission prompt explains this.

## Git workflow (suggested)

```
main ← develop ← feature/scan-flow, feature/insights, feature/ml-categoriser, …
```

Commit small, descriptive changes (`feat(scan): draw Vision bounding boxes`) and merge feature branches through pull requests into `develop`, then `main` for each milestone.

## Credits

- Apple frameworks only; no third-party code.
- Shop names on sample receipts are fictional. Merchant keyword lists reference real Sri Lankan brands for categorisation only.
- AI assistance is documented in [`AI_USAGE.md`](AI_USAGE.md).
