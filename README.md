# ProfileShotView

This uses the camera on the phone to take a profile photo with transparent background, for use in social media apps (avatars, etc.), keynote presentations, or whereever you need a profile picture.

It uses Apple's built-in neural network to detect people and provide a "portrait effects matte" to remove the background with high resolution.


## Installation

Add the package as a Swift Package Manager package with the address

    git@github.com:htb/ProfileShotView.git

You must specify device usage strings in your `Info.plist` file for the following privacy settings:

    Privacy - Camera Usage Description
    Privacy - Photo Library Usage Description

The latter is only needed if you want to save the photo to the photo library.


## Usage, UIKit

Typically add and layout the `ProfileShotView` in your `viewDidLoad` method. Set the `delegate` to `self`. The view's camera session must be initialized with a call to

    profileShotView.initialize { status in
        // handle any error here
    }

`initialize` will ask for camera permission, if required.

Typically start and stop the camera in `viewWillAppear` and `viewDidDisappear`, respectively.

Simply call `capturePhoto` when you want to capture a photo, and the finished photo will be provided in the delegate method `profileShotView:didCapturePhoto`.


### Options

You can change overlay colors (see view properties).

You can change background behind the photo to a checkerboard, solid color or an image using the `photoBackground` property. The photo background is still transparent; this is just a preview.

If you set the `captureWhenSmiling` property to `true`, the photo will automatically be captured when the user smiles.

The crop rectangle around the face that will be captured as a photo can be changed using the property `faceToPhotoWidthExtensionFactor`.

## Contributing

### Publishing

To publish an update to this package, first see the last version number with

    git tag

Then update the version number in the master branch and push like this

    git commit -a -m "Something changed"
    git tag 1.0.1
    git push origin main --tags
