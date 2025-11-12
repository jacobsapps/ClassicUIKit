# ClassicUIKit Build Notes

## Platform & Entry Points
- iOS 26 target, iPhone portrait only.
- `AppDelegate` + `SceneDelegate` bootstraps the app; every scene instantiates `AppCoordinator` which owns a single `UINavigationController`.
- DI powered by Factory; the shared `Container` wires repositories, services, and UI dependencies lazily.

## Architecture Overview
- MVVM per screen, UIKit views laid out with SnapKit.
- Navigation goes through the coordinator: `GalleryViewController` pushes the editing stack via hero modal transitions into `CollageViewController`.
- Observable view models (`@Observable`) expose simple value properties; controllers observe via `withObservationTracking`.

## Feature: Gallery
- Files live under `Features/Gallery`.
- `GalleryViewModel` loads collages asynchronously (`CollageRepository` + `ImageLoaderService`) and produces `GalleryDisplayModel` items with cached snapshots.
- `GalleryViewController` shows a two-column `UICollectionView` (diffable data source). Selecting a cell triggers coordinator hero transition; tapping add uses the nav bar button.
- Empty and loading states handled with `UIActivityIndicatorView` + reusable `EmptyStateView`.

## Feature: Collage
- Core types in `Features/Collage` (view model, controller, view helpers, toolbar).
- `CollageViewModel` responsibilities:
  - Loading/saving collages via `CollageRepository` (SwiftData + filesystem hybrid similar to SummonSelf project).
  - Managing `CanvasItemModel` structs for every image (transform, shaders, z-order, cutouts, asset paths).
  - Cutouts use `VNGenerateForegroundInstanceMaskRequest` (based on SummonSelf's `GenerationViewModel`).
  - Shader stack now processed by `CoreImageShaderService` (see below) for pixellate / glitch / 3D effects, keeping images reactive when toggled.
  - Tracks `hasUnsavedChanges`, `isSaving`, and selection to drive warnings + toolbar state.
- `CollageViewController`:
  - Hosts a SnapKit canvas, toolbar, and floating liquid-glass effect control surface.
  - Installs pan / pinch / rotation / tap gestures per `CollageCanvasImageView`, forwarding transform changes back to the view model.
  - Renders selected-item toolbar state, hero dismiss/back/save flows, and warning alerts.
  - Snapshotting uses `UIView.snapshotImage()` before saving.

## Common Views & Transitions
- `CollageCanvasImageView`: wraps image presentation, outlines selection, shows cutout progress.
- `FloatingToolbarView`: glassmorphic control surface with toggles for cutout + shaders, visual feedback for active state.
- `HeroTransitioningDelegate`: custom transitioning delegate provides gallery↔︎collage hero animation (snapshot expansion + collapse).

## Storage & Services
- Models: `Collage`, `CollageItem`, `CollageItemTransform`, and `ShaderType` (program data in `Models/`).
- Persistence: `CollageEntity` + `CollageItemEntity` (SwiftData) hold metadata; images & cutouts are JPEG/PNG on disk via `ImageFileManager`, mirroring SummonSelf’s hybrid strategy.
- `CollageRepository` orchestrates disk writes + SwiftData upserts and exposes helpers to persist item assets lazily.
- `PhotoLibraryService` wraps permission-gated picker presentation and asset saving (add-only auth).
- `ImageLoaderService` lazily loads cached snapshots and cutouts from disk for the gallery + editing canvas.
- **Shader pipeline** (`Services/ImageShaderService.swift` + `Shaders/ImageShaders.metal`):
  - Inspired by `/Published/CoreImageToy`, replaces the earlier raw Metal compute path with Core Image color kernels (simpler setup, no manual textures).
  - Pixellate uses `CIPixellate`; glitch & 3D glasses use custom stitchable kernels invoked via `CIKernel(functionName:fromMetalLibraryData:)`.
  - `ShaderProcessingServiceProtocol` keeps the view model decoupled from Core Image; DI exposes `CoreImageShaderService`.

## Tests
- Gallery: `GalleryViewModelTests` + `GalleryViewControllerTests` cover data loading, navigation hooks, and rendering.
- Collage: `CollageViewModelTests` assert picker ingestion, shader toggles, and save/dismiss flows; `CollageViewControllerTests` verify toolbar interactions and picker presentation wiring.
- Tests currently rely on Xcode’s simulator runtime; when running in restricted sandboxes, `xcodebuild` may fail to access CoreSimulator (see CLI logs). Run locally outside the sandbox for full validation.

## Hero Flow & Navigation
- Coordinator performs hero modal presentation; `HeroTransitioningDelegate` stores the tapped cell's image view to animate alongside the destination controller (gallery → collage and back on save/back).
- On save, `CollageViewModel` persists snapshot, updates SwiftData, saves to Photos, then asks the coordinator to dismiss and refresh gallery ordering by `updatedAt`.

## Extensibility & Follow-ups
- `CanvasItemModel` already stores shader order and transform metadata; future gestures (double-tap to reset, multi-select) can hook into the same structure.
- Additional shader kernels can be dropped into `ImageShaders.metal` and used via the service without touching controllers/view models.
- Deletion & storage cleanup are not implemented yet (out of scope per prompt).

## Testing & Verification Notes
- Due to sandbox limits we could not finish an `xcodebuild test`; rerun `xcodebuild -project ClassicUIKit.xcodeproj -scheme ClassicUIKit -destination 'platform=iOS Simulator,name=iPhone 15' test` on a dev machine.
- Snapshot hero transition relies on actual cell frames—verify on device to fine-tune animation curves if desired.

## File Map Highlights
- App lifecycle: `App/AppDelegate.swift`, `App/SceneDelegate.swift`.
- Coordinators: `Coordinators/AppCoordinator.swift`, shared transitioning in `Views/HeroTransitioningDelegate.swift`.
- Gallery Feature: `Features/Gallery/**/*`.
- Collage Feature: `Features/Collage/**/*` (view model, controller, canvas/toggles).
- Models & persistence: `Models/`, `Services/CollageRepository.swift`, `Models/CollageEntity.swift`.
- Shaders & imaging: `Servicios/ImageShaderService.swift`, `Shaders/ImageShaders.metal`, `Services/ImageFileManager.swift`.
- Tests: `ClassicUIKitTests/Gallery/*`, `ClassicUIKitTests/Collage/*`.

Feel free to extend these notes as new services/features are added.
