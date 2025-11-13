# ClassicUIKit

ClassicUIKit is a UIKit-powered collage playground that lets you pull images from the photo library, drop them onto an edge-to-edge canvas, and remix them using the same observable/state-driven patterns Apple gave SwiftUI.

## What it does

- **Gallery:** A diffable-data gallery backed by SwiftData lists every saved collage, lets you spin up a new one, and handles deletions with long-press actions.
- **Collage editor:** Add photos, resize/rotate them with gestures, run quick Vision cutouts, and layer on real-time shader stacks (Metal/Core Image) from the floating toolbar.
- **Saving & export:** Snapshots persist both to the local store and the Photos library so edits survive relaunches, and hero transitions carry canvases back to the gallery.

Under the hood the app leans on UIKit’s new `@Observable` macro, SnapKit for layout, FactoryKit for DI, and a small shader-processing service that stitches together the bundled Metal kernels.
