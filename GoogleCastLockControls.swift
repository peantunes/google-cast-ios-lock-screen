//
//  CastLockContols.swift
//  ios-player
//
//  Created by Pedro Antunes on 26/06/2017.
//  Copyright © 2017 Pedro Antunes. All rights reserved.
//

import AVFoundation
import MediaPlayer
import GoogleCast //google-cast-sdk (3.2.0)

class GoogleCastLockControls:NSObject {
    
    var player:AVPlayer?
    
    var currentMetadata:GCKMediaMetadata?
    var currentMediaStatus:GCKMediaStatus?
    weak var currentSession:GCKCastSession?
    
    private var filmArtworks:[String:MPMediaItemArtwork] = [String:MPMediaItemArtwork]()
    
    static let shared = GoogleCastLockControls()
    
    ///Initializer
    private override init(){
        super.init()
        
        GCKSessionManager.ignoreAppBackgroundModeChange()
        
        GCKCastContext.sharedInstance().sessionManager.add(self)
        
        if let path = Bundle.main.path(forResource: "mute sound", ofType: "mp3", inDirectory: nil, forLocalization: nil){
            let url = URL.init(fileURLWithPath: path)
            let player = AVPlayer(url: url)
            player.play()
            self.player = player
            
            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: self.player?.currentItem, queue: nil, using: { (_) in
                DispatchQueue.main.async {
                    self.player?.seek(to: kCMTimeZero)
                    self.player?.play()
                }
            })
            
        }
    }
    
    ///remove all the references and observers
    deinit {
        let x = MPNowPlayingInfoCenter.default()
        x.nowPlayingInfo = [:]
        self.player?.pause()
        self.player?.replaceCurrentItem(with: nil)
        self.player = nil
        NotificationCenter.default.removeObserver(self)
        
    }
    
    ///Initial setup
    func setup(){
        
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.likeCommand.isActive = true
        
        configureCommandCenter(commandCenter: commandCenter)
    }
    
    ///Remove the controls from home screen
    fileprivate func removeControls(){
        let x = MPNowPlayingInfoCenter.default()
        x.nowPlayingInfo = [:]
    }
    
    ///Adding the details to the player
    fileprivate func setMediaInfo(title:String, currentPos:Float, duration:Float, imageUrl:String? = nil){
        print("Content for \(title)")
        
        let infoCenter = MPNowPlayingInfoCenter.default()
        var media = [MPMediaItemPropertyTitle: title,
                     MPMediaItemPropertyPlaybackDuration:NSNumber(value:duration),
                     MPNowPlayingInfoPropertyPlaybackRate:NSNumber(value:1.0 as Float),
                     MPNowPlayingInfoPropertyElapsedPlaybackTime:NSNumber(value:currentPos),
                     
            ] as [String : Any]
        
        
        if let imageUrl = imageUrl {
            media[MPMediaItemPropertyArtwork] = self.filmArtworks[imageUrl]
            guard let _ = self.filmArtworks[imageUrl] else {
                UIImage.downloadFrom(link:imageUrl, callback:{ image in
                    guard let image = image else {
                        return
                    }
                    
                    let infoCenter = MPNowPlayingInfoCenter.default()
                    
                    var media = infoCenter.nowPlayingInfo
                    let size:CGFloat = min(image.size.height, image.size.width)
                    let xPos = (image.size.width - size)/2
                    
                    let croppedImage = image.cropping(to: CGRect(x: xPos, y: 0, width: size, height: size))
                    let scaledImage = croppedImage.scaleImage(toSize: CGSize(width:120, height:120))!
                    
                    let artwork = MPMediaItemArtwork(image:scaledImage)
                    media?[MPMediaItemPropertyArtwork] = artwork
                    self.filmArtworks[imageUrl] = artwork
                    infoCenter.nowPlayingInfo = media
                    
                })
                return
            }
        }
        infoCenter.nowPlayingInfo = media
        

    }
    
    
    ///Configuration of the commands
    fileprivate func configureCommandCenter(commandCenter:MPRemoteCommandCenter) {
        
        let rcc = MPRemoteCommandCenter.shared()
        
        let skipBackwardCommand = rcc.skipBackwardCommand
        skipBackwardCommand.isEnabled = true
        skipBackwardCommand.addTarget(handler: skipBackward)
        skipBackwardCommand.preferredIntervals = [15]
        
        let skipForwardCommand = rcc.skipForwardCommand
        skipForwardCommand.isEnabled = true
        skipForwardCommand.addTarget(handler: skipForward)
        skipForwardCommand.preferredIntervals = [15]
        
        commandCenter.playCommand.addTarget (handler: play)
        commandCenter.pauseCommand.addTarget (handler: pause)
    }
    
    
    ///Skip Action from the player
    fileprivate func skipBackward(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        guard let command = event.command as? MPSkipIntervalCommand else {
            return .noSuchContent
        }
        
        let interval = command.preferredIntervals[0]
        
        print("moving backward \(interval)")
        let session = GCKCastContext.sharedInstance().sessionManager.currentCastSession
        if let position = session?.remoteMediaClient?.approximateStreamPosition() {
            let options = GCKMediaSeekOptions()
            options.interval = max(position - 15,0)
            session?.remoteMediaClient?.seek(with: options)
        }
        return .success
    }
    
    ///Forward action from the player
    fileprivate func skipForward(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        guard let command = event.command as? MPSkipIntervalCommand else {
            return .noSuchContent
        }
        
        let interval = command.preferredIntervals[0]
        print("moving forward \(interval)")
        let session = GCKCastContext.sharedInstance().sessionManager.currentCastSession
        if let position = session?.remoteMediaClient?.approximateStreamPosition() {
            let options = GCKMediaSeekOptions()
            options.interval = position + 15
            session?.remoteMediaClient?.seek(with: options)
        }
        
        return .success
    }
    
    ///Play action from the player
    private func play(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        
        print("play")
        let session = GCKCastContext.sharedInstance().sessionManager.currentCastSession
        session?.remoteMediaClient?.play()
        
        self.player?.play()
    
        let infoCenter = MPNowPlayingInfoCenter.default()
        infoCenter.nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
        _ = try? AVAudioSession.sharedInstance().setActive(true)
        
        return .success
    }
    
    
    ///Pause action from the player
    private func pause(_ event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        print("pause")
        let session = GCKCastContext.sharedInstance().sessionManager.currentCastSession
        session?.remoteMediaClient?.pause()
        
        self.player?.pause()
        
        let infoCenter = MPNowPlayingInfoCenter.default()
        infoCenter.nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = 0.0
        if let mediaClient = GCKCastContext.sharedInstance().sessionManager.currentCastSession?.remoteMediaClient {
            infoCenter.nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = NSNumber(value:mediaClient.approximateStreamPosition())
        }else{
            return .commandFailed
        }
        _ = try? AVAudioSession.sharedInstance().setActive(false)
        
        return .success

    }
}

extension GoogleCastLockControls:GCKSessionManagerListener {
    //Start
    func sessionManager(_ sessionManager: GCKSessionManager, willStart session: GCKCastSession) {
        self.currentSession = session
        session.add(self)
        
    }
    
    func sessionManager(_ sessionManager: GCKSessionManager, didStart session: GCKCastSession) {
        session.remoteMediaClient?.add(self)
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 3) {
            self.refreshContentInformation()
        }
    }
    
    func sessionManager(_ sessionManager: GCKSessionManager, didFailToStart session: GCKCastSession, withError error: Error) {
        session.remove(self)
    }
    
    //Resume
    func sessionManager(_ sessionManager: GCKSessionManager, willResumeCastSession session: GCKCastSession) {
        self.currentSession = session
    }
    
    func sessionManager(_ sessionManager: GCKSessionManager, didResumeCastSession session: GCKCastSession) {
        session.remoteMediaClient?.add(self)
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 3) {
            self.refreshContentInformation()
        }
    }
    
    func sessionManager(_ sessionManager: GCKSessionManager, didSuspend session: GCKCastSession, with reason: GCKConnectionSuspendReason) {
        print(reason)
    }
    
    //End
    func sessionManager(_ sessionManager: GCKSessionManager, willEnd session: GCKCastSession) {
        session.remove(self)
        session.remoteMediaClient?.remove(self)
        
    }
    
    func sessionManager(_ sessionManager: GCKSessionManager, didEnd session: GCKCastSession, withError error: Error?) {

        self.currentSession = nil
        self.removeControls()
        
        //For some reason GoogleCast disconnect every time when you return to the app
        //If it is disconnected by an error, try to connect again
        if let error = error, let _ = currentMetadata {
            print(error)
            
            let device = session.device
            
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
                sessionManager.startSession(with: device)
            }
        }
    }
    
    ///Set the current content information
    fileprivate func refreshContentInformation(){
        
        let title = self.currentMetadata?.string(forKey: kGCKMetadataKeyTitle) ?? ""
        let imageUrl = (self.currentMetadata?.images().first as? GCKImage)?.url
        
        
        let position:Float = Float(currentSession?.remoteMediaClient?.approximateStreamPosition() ?? 0)
        let duration:Float = Float(currentSession?.remoteMediaClient?.mediaStatus?.mediaInformation?.streamDuration ?? 0)
        print("refreshing component, title:\(title) - position:\(position) - duration:\(duration)")
        self.setMediaInfo(title: title, currentPos:position, duration: duration, imageUrl: imageUrl?.absoluteString)
        
        
        let infoCenter = MPNowPlayingInfoCenter.default()
        
        if let state = currentMediaStatus?.playerState,
            state == GCKMediaPlayerState.playing {
            self.player?.play()
            
            infoCenter.nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
            _ = try? AVAudioSession.sharedInstance().setActive(true)
        }else{
            self.player?.pause()
            
            infoCenter.nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = 0.0
            _ = try? AVAudioSession.sharedInstance().setActive(false)
        }
    }

    
}


///Tracking metadata update from Google cast and refreshing the content
extension GoogleCastLockControls:GCKRemoteMediaClientListener {
    func remoteMediaClient(_ client: GCKRemoteMediaClient, didUpdate mediaMetadata: GCKMediaMetadata?) {
        self.currentMetadata = mediaMetadata
        
        self.refreshContentInformation()
    }
    
    func remoteMediaClient(_ client: GCKRemoteMediaClient, didUpdate mediaStatus: GCKMediaStatus?) {
        self.currentMediaStatus = mediaStatus
        self.refreshContentInformation()
    }
    
}

///Future implementation
extension GoogleCastLockControls:GCKCastDeviceStatusListener {
    
}


///Extension to provide the hack to avoid GoogleCast to close connection when entering in background
extension GCKSessionManager {
    static func ignoreAppBackgroundModeChange() {
        if let oldMethod = class_getInstanceMethod(GCKSessionManager.self, #selector(GCKSessionManager.suspendSession(with:))),
            let newMethod = class_getInstanceMethod(GCKSessionManager.self, #selector(GCKSessionManager.suspendSessionIgnoringAppBackgrounded(with:))) {
            method_exchangeImplementations(oldMethod, newMethod)
        }
    }
    
    func suspendSessionIgnoringAppBackgrounded(with reason: GCKConnectionSuspendReason) -> Bool {
        guard reason != .appBackgrounded else { return false }
        return suspendSession(with:reason)
    }
}

///Extension to resize and crop image
extension UIImage {
    func cropping(to rect: CGRect) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(rect.size, false, self.scale)
        
        self.draw(in: CGRect(x: -rect.origin.x, y: -rect.origin.y, width: self.size.width, height: self.size.height))
        
        let croppedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return croppedImage
    }
    
    func scaleImage(toSize newSize: CGSize) -> UIImage? {
        let newRect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height).integral
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
        if let context = UIGraphicsGetCurrentContext() {
            context.interpolationQuality = .high
            let flipVertical = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: newSize.height)
            context.concatenate(flipVertical)
            context.draw(self.cgImage!, in: newRect)
            let newImage = UIImage(cgImage: context.makeImage()!)
            UIGraphicsEndImageContext()
            return newImage
        }
        return nil
    }
    
    static func downloadFrom(url: URL, callback:@escaping((UIImage?)->())) {
        URLSession.shared.dataTask(with: url) { (data, response, error) in
            guard let httpURLResponse = response as? HTTPURLResponse, httpURLResponse.statusCode == 200,
                let mimeType = response?.mimeType, mimeType.hasPrefix("image"),
                let data = data, error == nil,
                let image = UIImage(data: data)
                else {
                    callback(nil);
                    return }
            DispatchQueue.main.async() { () -> Void in
                callback(image)
            }
            }.resume()
    }
    
    static func downloadFrom(link: String, callback:@escaping ((UIImage?)->())) {
        guard let url = URL(string: link) else { return }
        downloadFrom(url: url, callback: callback)
    }
    
}
