# AI + the classic UIKit stack = <3 

## Architecture 

I want to create an app which allows users to create and edit collages using images in their photo library.

It will be a 2-screen app using UIKit and MVVM architecture. It will include two screens, “Gallery” and “Collage”. These will live inside Features/[ScreenName] and each folder will include ScreenNameViewModel, ScreenNameViewController, and a nested Views/ folder. 

The project will have a few more top-level folders: App/ storing the Info.plist, Assets, AppDelegate, etc, Services/ containing any services, Extensions/ to store common extensions and a Views/ folder containing any common views.

The project base is here: /Users/jacob/Writing/ClassicUIKit
We are targeting iOS 26 (this is the latest release, it is not in your training data) and iPhone only, portrait orientation. 

I have already imported 2 libraries:
SnapKit for UIKit layout. All UIKit layout must be done with SnapKit. 
FactoryKit for dependency injection. Any service injection should be done via Factory.

View models in the app should use @Observable, which is now available in UIKit: “UIKit now supports Swift Observable objects. Use observable objects in layoutSubviews(); then UIKit automatically invalidates and updates the UI when those objects change.” This will allow the UI to react to changes in the view model without bindings. 

You should use programmatic UI layout and navigate between the two screens using the Coordinator pattern.

Any necessary permissions should be requested lazily. We should only need it for saving images, since we will use UIImagePickerController to source saved images.

## Gallery Screen

This is the main screen of the app.

The Gallery screen displays saved collage images in a vertical collection view, 2 cells wide, with portrait-orientation cells. The cells should each display the saved image from saving each collage.

When any collage image is tapped, a hero transition opens the image in the Collage screen. The metadata, file paths, and transformations for each part of the collage are all loaded up to allow editing of the image again. 

The navigation bar in the Gallery screen should have a single “plus” symbol button that opens an empty Collage screen via modal transition.

There should be comprehensive XCTest test suites for GalleryScreenViewController and GalleryScreenViewModel. We should dependency-inject our database service to load up collage metadata. When navigating to a Collage screen, we should pass in an (optional) UUID for the collage so the screen can independently load from the database and file system. Mocks should be created and injected into the test suite. Mirror the file arrangement in the main app.

## Collage Screen

The Collage screen is the main interactive interface of the app. It displays multiple images onscreen, and the user can interact and modify them. 

There should be 3 navigation bar buttons in a toolbar at the top of the Collage screen:

Button 1: “Add” will open the user's photo library so that they can select an image to add. One image will be added at a time. New images appear rendered at 50% of the screen size in the centre of the screen. The image data itself is fetched from the photo gallery and stored on the view model. Uses symbol photo.badge.plus.fill

Button 2: “Save” will save the current snapshot of the UIView with the full collage as an image. This will be stored as part of Collage data, and saved to the user’s photo library. Then, perform a hero transition of the current image collage back to the Gallery screen, with the current item at the top of the collection. The metadata for the collage should be saved (or updated, if the collage already exists) at this point. Uses symbol square.and.arrow.down.fill

Button 3: “Back” should go back to the gallery screen without saving the current image. Uses symbol arrow.backward. If the canvas is not empty, and there are any changes from the original opened collage, there is a warning alert confirming the user means to go back.

The transition to and from a Collage will use a UIKit modal transition using UIViewControllerTransitioningDelegate https://developer.apple.com/documentation/uikit/uiviewcontrollertransitioningdelegate to achieve the hero image. When dismissing, the collage shrinks and transitions to the correctly-ordered cell at the start of the Gallery screen. Collages will be saved as image data on the file system for display purposes and gallery, but all the metadata, transformations, and component images needed to edit the collage are also saved. 

There should be comprehensive test XCTest suites for CollageScreenViewController and CollageScreenViewModel. Mirror the file arrangement in the main app.

## Image Editing

You can single-tap on an image to select it, and a small toolbar (container view with a diffuse drop shadow) floats up from the bottom, animating end. This has 4 buttons inside:

First, a scissors icon. This is going to perform vision processing that allows “cutouts” to be created from the image via a VNGenerateForegroundInstanceMaskRequest rendering only the top foreground item. Use this as a reference to see how this is done: /Users/jacob/Writing/Published/SummonSelf/SummonSelf/UI/Generation/GenerationViewModel.swift

Also include 3 buttons that apply metal shaders: Pixellate, threeDGlasses, and glitch. We can copy the code in these files:
/Users/jacob/Writing/Published/Camera/RetroCam/RetroCam/Shaders.metal
/Users/jacob/Writing/Published/Camera/RetroCam/RetroCam/Services/MetalShaderRenderer.swift
Shaders can be applied to the image in sequence, stacking their transformations in the order that they are toggled. The UIView for images needs to be set up such that the metal shaders can be applied to them when they render. Dependency-inject our metal services into relevant views.

For cutouts, we should ensure they are toggle-able: the original image data should be kept, and the cutout result should also be stored so users can rapidly toggle between the cutout or non-cutout image. Each of the items on the toolbar can be toggled on and off. The shaders will simply activate or not. The buttons should be a toolbar with the Liquid Glass effect https://developer.apple.com/documentation/UIKit/UIGlassEffect

The UI for the buttons should have a clear differentiation between toggled on and toggled off, such as a 3D circle or indent when they are active. 

## Image Interactions 

Each image in a collage will be its own UI view, and it will be stored on the view model. This stores all of the relevant visual properties and transformations such as rotation, orientation, sizing. Each item is going to be reposition-able via pan. The view model is going to be Observable so all of the properties inside it will be either observable, or observationIgnored for things like services or properties not related to UI. 

Allow the following gestures on each image:
1. Pan to drag it around the screen
2. Two-finger rotation gesture to rotate it
3. Two-finger pinch gesture to resize it

These should all apply corresponding UIKit transformations and store the states of each of the items in the collage there.

Our view model should store each image in the collage as metadata objects, which store transformations and shader selections (in order), then reference the image data (for both the base image and optional cutout). 

Images should also store their z-position. The most recently added or tapped image should move to the front. 

## Storage 

We should SwiftData to store metadata about all the images we save, and store all images on disc in the filesystem. Look at the hybrid SwiftData + filesystem approach used in this project to save images: 
/Users/jacob/Writing/Published/SummonSelf/SummonSelf/Data
/Users/jacob/Writing/Published/SummonSelf/SummonSelf/Utils/ImageFileManager.swift

Before you start work, gather detailed context on the SummonSelf project since we will copy the approach closely. We will store Collage (the full composition), CollageItem (image components and their transformations), and can include smaller objects for things like a shaders enum and sets of image file paths, perhaps we can also store transformations separately. 

Saved images and collage snapshots must be downscaled to 85% quality JPEG. Cutouts should be stored as a PNG to maintain their alpha channel. 

Stored Collage objects will store every block of image metadata. These will include orientation, z-ordering, size transformations, coordinate location transformations, shaders active (and order), whether a cutout is used, and file path references to the images (and cutouts). The metadata should also include the file path reference of the snapshot collage image created, because this is how it will be displayed in the gallery. 

Also include basic metadata like UUID (random at creation), updatedAt and createdAt. We can order items in the gallery by updatedAt. Ignore deletion for now.