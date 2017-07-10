# google-cast-ios-lock-screen

I've implemented it to use as a solution for Chromecast / Google Cast to present the player controls in the lock screen and in the player component.

First of all you need to follow the information bellow: 
* it uses the official google-cast-sdk (3.2.0)
* set the project capability Background Modes on with Audio, AirPlay and Picture in Picture.
* add the "mute sound.mp3" file in your project, together with the GoogleCastLockControls.swift
* call anywhere the initializer **GoogleCastLockControls.shared.setup()**

I haven't had time to review the code, but it works fine for all I need and I decided to publish it as soon as possible to help other people with the same problem. 
