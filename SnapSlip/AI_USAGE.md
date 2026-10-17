# AI-Assisted Development Log

The SE4041 brief asks that any use of AI tools be documented, including prompts and responses, and how they helped. This file is that record. **Keep it up to date** as you continue working on the project, and be ready to explain every part of the code in the viva.

## Tool used

| | |
|---|---|
| Tool | Claude (Anthropic), Opus 5.5 model, in the Claude app |
| Date | 9–10 October 2026 |
| Scope | Initial scaffold of both projects, tests, training data, documentation drafts and pitch deck |

## Interaction 1 — brief and scope

**Prompt (verbatim):**
> "we have to do this assignment using xcode. deliver the deliverables mentioned here" *(with the SE4041 Assignment 02 PDF attached)*

**Clarifying choices made by the student** (from options the assistant proposed):

| Question | Choice |
|---|---|
| Part A concept | Food/expense scanner + Vision |
| Part B platform | visionOS |
| Persistence | SwiftData |
| Order | Everything, Part A first |

**What the assistant produced:**

- The SnapSlip iOS project: SwiftUI + SwiftData app source, Xcode project, asset catalogue and generated app icon.
- The receipt parser, Vision OCR wrapper, and the layered categoriser (Core ML → keyword rules → NaturalLanguage embeddings, with a personal merchant-rule layer).
- The Create ML training CSV (synthetic, 1,200 rows) and the training script.
- Unit tests (Swift Testing) and UI tests (XCUITest).
- The SnapSlip Spatial visionOS prototype.
- Drafts of the report, user guide, technical documentation and pitch deck.

**Important limitation:** the assistant wrote the code in a Linux environment **without access to Xcode or a Swift compiler**. Nothing was compiled or run by the assistant. The student must build, run and test everything in Xcode, fix any compiler errors, and record those fixes below.

## How the AI output was used

Fill this in honestly. Examples of what to record:

| Date | What I asked / did | What changed | Why |
|---|---|---|---|
| | Built the project in Xcode 26 | e.g. fixed a compiler error in `InsightsView.swift` line … | … |
| | Ran ⌘U | e.g. N unit tests passed, M failed; fixed … | … |
| | Trained the Core ML model | Accuracy: train …%, validation …%, test …% | Recorded for the report |
| | Changed the design of … | … | Own design decision |

## Code I wrote or substantially rewrote myself

List the files or features that are your own work, so the examiner can see your contribution clearly.

-
-

## Reflection

A short paragraph for the report: where the AI help was useful (e.g. scaffolding, test ideas, Vision coordinate conversion), where it was wrong or needed correction, and what you learned by fixing and extending it.
