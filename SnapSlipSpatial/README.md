# SnapSlip Spatial — See your money in space (visionOS prototype)

SE4041 Mobile Application Design and Development · Assignment 02 · Part B

SnapSlip Spatial is the Apple Vision Pro companion to the SnapSlip iPhone app. Instead of reading another pie chart, you **walk around your month**:

- **Spending City** (volumetric window): every category is a tower on a 3×3 plot. Tower height is that month's spend. Look at a tower and pinch to select it; drag to spin the city; step through months and watch the towers grow and shrink.
- **Budget Orbit** (immersive space, mixed immersion): each category becomes a glowing orb on an arc in front of you, sized by spend. A ring of 60 beads on the floor around you lights up as you use your budget — and turns red when you go over. Pinch an orb to open its receipts beside it, drag orbs to rearrange them, or magnify them with both hands.
- **Dashboard** (glass window with ornaments): month sidebar, budget gauge, category cards with hover effects, receipt lists, and **Import from iPhone** (the CSV exported by SnapSlip on iOS).

## Requirements

| | |
|---|---|
| Xcode | 16.0 or later with the visionOS SDK (Xcode 26 recommended) |
| Deployment target | visionOS 2.0 |
| Runs on | Apple Vision Pro simulator or device |
| Frameworks | SwiftUI, RealityKit (custom ECS components + system), Observation, UniformTypeIdentifiers |

## Build & run

1. Open `SnapSlipSpatial.xcodeproj`.
2. Select your Team under *Signing & Capabilities* for the **SnapSlipSpatial** target.
3. Choose the **Apple Vision Pro** simulator and press **⌘R**. (Install the visionOS platform from *Xcode → Settings → Components* if it's missing.)
4. The app opens with three months of sample data. Use the ornament under the window to **Open Spending City** and **Enter Budget Orbit**.

**Simulator controls:** click = look + pinch, click-and-drag = drag. Two-handed gestures such as magnify are simulated with the ⌥ (Option) key; see Apple's "Interacting with your app in the visionOS simulator" for the exact controls in your Xcode version. Use the camera controls in the simulator toolbar to look around the immersive space.

**Use your own data:** in SnapSlip on iPhone, go to *Settings → Export as CSV*. Save it to Files (or AirDrop it), then in SnapSlip Spatial tap **Import from iPhone**.

## Tests

⌘U runs `SnapSlipSpatialTests` (Swift Testing): CSV import compatibility with the iOS export, 3D layout maths (tower heights, grid, orb sizing, arc placement, budget beads) and the shared `AppModel`.

## How it works

```
SnapSlipSpatial/
├── App/         SnapSlipSpatialApp (3 scenes), AppModel (shared @Observable state)
├── Model/       SpendingStore + sample data, CSVImporter
├── RealityKit/  Components & FloatSystem (ECS), EntityFactory, SpatialLayout (pure maths)
├── Views/       DashboardWindow, SpendingCityView (volume), BudgetOrbitView (immersive)
└── Resources/   Assets (3-layer visionOS app icon, accent colour)
Config/Info.plist   scene manifest (immersive space starts in mixed style)
```

- **One model, three scenes.** `AppModel` is injected into the window, the volume and the immersive space. Picking a month or category anywhere updates everything at once.
- **Entity-Component-System.** `CategoryComponent` tags entities with their category for gesture handling. `TowerComponent` remembers each tower's target height so animations only run when data changes. `FloatComponent` and the custom `FloatSystem` make orbs drift every frame, and pause while you drag one.
- **Procedural 3D.** No USDZ files: the towers, orbs and beads are generated with `MeshResource`, using `PhysicallyBasedMaterial` for the glowing orbs.
- **Attachments.** SwiftUI views (labels, receipt cards, summary) are placed in 3D with `RealityView` attachments and `BillboardComponent`, so they always face you.
- **Interaction.** `SpatialTapGesture`, `DragGesture` and `MagnifyGesture` are all `.targetedToAnyEntity()`. Every interactive entity has `InputTargetComponent`, `CollisionComponent` and `HoverEffectComponent` (gaze highlight), plus an `AccessibilityComponent` so VoiceOver can read each category and amount.
- **Comfort.** Content is placed at 1.1–1.5 m with mixed immersion (your room stays visible). There's no forced movement, and labels are billboarded.

## Similar apps (competitive landscape)

| App | What it does on Vision Pro | How SnapSlip Spatial differs |
|---|---|---|
| **NatWest banking app** (launched Aug 2024) | Brings the bank's iPad experience into 3D windows — payments, transfers, direct debits, controlled with eyes, hands and voice | Banking *transactions* in flat windows; no spatial visualisation of spending habits |
| **MoneyCoach** | Cross-platform budgeting app (iPhone, iPad, Mac, Watch) that also lists visionOS 2 support | A conventional 2D budgeting UI running in a window |
| **Tableau for Vision Pro** (research app, TestFlight beta tested at Tableau Conference 2024) | Immersive analytics: 3D bar/line charts and data globes explored with gaze and gestures | General business analytics for analysts; not personal, not receipt-based |
| **Swift Charts `Chart3D`** (Apple, visionOS 26) | A framework for 3D scatter and surface charts, not an app | A possible future upgrade path for the Insights view |

None of these turn a person's **own receipts** into a space they can stand inside. SnapSlip Spatial combines automatic receipt capture on iPhone with an embodied, glanceable budget view on Vision Pro.

## Credits

Apple frameworks only. AI assistance is documented in [`AI_USAGE.md`](AI_USAGE.md).
