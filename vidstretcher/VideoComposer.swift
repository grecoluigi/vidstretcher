//
//  VideoComposer.swift
//  vidstretcher
//
//  Created by Luigi Greco on 06/09/21.
//

import UIKit
import AVKit
import MobileCoreServices
import Photos
import UniformTypeIdentifiers

class VideoComposer: UIViewController {
    
    static var videoComposer = VideoComposer()
    

    
    // Sets the picked video as the current asset
    func pickedVideo(url: URL) {
        VideoAsset.sharedVideoAsset.movieAsset = AVAsset(url: url)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    func retime() {
        audioSettingsVCInstance.activityMonitor.startAnimating()
        let composition = AVMutableComposition()
        
        guard
            let track = composition.addMutableTrack(withMediaType: .video, preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
        else { return }
        do {
            try track.insertTimeRange(CMTimeRangeMake(start: .zero, duration: VideoAsset.sharedVideoAsset.movieAsset!.duration), of: VideoAsset.sharedVideoAsset.movieAsset!.tracks(withMediaType: .video)[0], at: .zero)
            track.scaleTimeRange(CMTimeRangeMake(start: .zero, duration: VideoAsset.sharedVideoAsset.movieAsset!.duration), toDuration: VideoAsset.sharedVideoAsset.timestamp.duration)
        } catch {
            print("Failed to load asset track")
            return
        }
        
        if VideoAsset.sharedVideoAsset.discardOriginalAudioTrack == false {
            guard
                let originalAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
            else { return }
            do {
                try originalAudioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: VideoAsset.sharedVideoAsset.movieAsset!.duration), of: VideoAsset.sharedVideoAsset.movieAsset!.tracks(withMediaType: .audio)[0], at: .zero)
                originalAudioTrack.scaleTimeRange(CMTimeRangeMake(start: .zero, duration: VideoAsset.sharedVideoAsset.movieAsset!.duration), toDuration: VideoAsset.sharedVideoAsset.timestamp.duration)
            } catch {
                print("Failed to load audio asset track")
                return
            }
        }
        
        let mainInstruction = AVMutableVideoCompositionInstruction()
        mainInstruction.timeRange = CMTimeRangeMake(start: .zero, duration: VideoAsset.sharedVideoAsset.timestamp.duration)
        let firstInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: VideoAsset.sharedVideoAsset.movieAsset!.tracks[0])
        var instructionsArray = [AVMutableVideoCompositionLayerInstruction]()
        instructionsArray.append(firstInstruction)
    
        
        if VideoAsset.sharedVideoAsset.pickedAudioTrack != nil {
            //let externalAudioTrack = pickedAudioTrack?.tracks(withMediaType: AVMediaType.audio)[0]
            guard
                let extAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
            else { return }
            do {
                let startposition = CMTimeMake(value: VideoAsset.sharedVideoAsset.externalAudioStartPosition!, timescale: 1)
                try extAudioTrack.insertTimeRange(CMTimeRange(start: startposition, duration: VideoAsset.sharedVideoAsset.timestamp.duration), of: (VideoAsset.sharedVideoAsset.pickedAudioTrack?.tracks(withMediaType: .audio)[0])!, at: .zero)
                //extAudioTrack.scaleTimeRange(CMTimeRangeMake(start: .zero, duration: movieAsset!.duration), toDuration: timestamp.duration)
            } catch {
                print("Failed to load external audio asset track")
                return
            }
            
            print("Composition has now \(composition.tracks.count) tracks")
        }
        
        
        mainInstruction.layerInstructions = instructionsArray
        let mainComposition = AVMutableVideoComposition()
        mainComposition.instructions = [mainInstruction]
        mainComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
        mainComposition.renderSize = VideoAsset.sharedVideoAsset.movieAsset!.tracks(withMediaType: .video).first!.naturalSize.applying(track.preferredTransform)
        guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else { return }
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        let date = dateFormatter.string(from: Date())
        let url = documentDirectory.appendingPathComponent("vidstretcher-\(date)" + VideoAsset.sharedVideoAsset.fileTypeAsString!)
        print(url)
        
        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else { return }
        exporter.outputURL = url
        exporter.outputFileType = VideoAsset.sharedVideoAsset.fileType
        exporter.shouldOptimizeForNetworkUse = true
        exporter.videoComposition = mainComposition
        
        if exportFlag! {
            
            exporter.exportAsynchronously {
                DispatchQueue.main.async {
                    self.exportDidFinish(exporter)
                }
            }
        }
        
        if previewFlag! {
//            exporter.exportAsynchronously(completionHandler: {
//                DispatchQueue.main.async {
//                    let previewPlayer = AVPlayer(playerItem: AVPlayerItem(url: exporter.outputURL!))
//                    let vcPlayer = AVPlayerViewController()
//                    vcPlayer.player = previewPlayer
//                    let keyWindow = UIApplication.shared.connectedScenes
//                            .filter({$0.activationState == .foregroundActive})
//                            .compactMap({$0 as? UIWindowScene})
//                            .first?.windows
//                            .filter({$0.isKeyWindow}).first
//                    keyWindow?.rootViewController?.present(vcPlayer, animated: true, completion: nil)
//                    previewPlayer.play()
//                    audioSettingsVCInstance.activityMonitor.stopAnimating()
//                }
//
//            })
            let previewPlayer = AVPlayer(playerItem: AVPlayerItem(asset: exporter.asset))
            let vcPlayer = AVPlayerViewController()
            vcPlayer.player = previewPlayer
            let keyWindow = UIApplication.shared.connectedScenes
                    .filter({$0.activationState == .foregroundActive})
                    .compactMap({$0 as? UIWindowScene})
                    .first?.windows
                    .filter({$0.isKeyWindow}).first
            keyWindow?.rootViewController?.present(vcPlayer, animated: true, completion: nil)
            previewPlayer.play()
            audioSettingsVCInstance.activityMonitor.stopAnimating()
        }


        
        

    }
    

    
    func exportDidFinish(_ session: AVAssetExportSession) {
      // 1
        audioSettingsVCInstance.activityMonitor.stopAnimating()
      // 2
      guard
        session.status == AVAssetExportSession.Status.completed,
        let outputURL = session.outputURL
        else { return }
        
      // 3
      let saveVideoToPhotos = {
        // 4
        let changes: () -> Void = {
          PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputURL)
        }
        PHPhotoLibrary.shared().performChanges(changes) { saved, error in
          DispatchQueue.main.async {
            let success = saved && (error == nil)
            let title = success ? "Success" : "Error"
            let message = success ? "Video saved to Photo Library" : "Failed to save video"
            let alert = UIAlertController(
              title: title,
              message: message,
              preferredStyle: .alert)
            alert.addAction(UIAlertAction(
              title: "OK",
              style: UIAlertAction.Style.cancel,
              handler: nil))
            let keyWindow = UIApplication.shared.connectedScenes
                    .filter({$0.activationState == .foregroundActive})
                    .compactMap({$0 as? UIWindowScene})
                    .first?.windows
                    .filter({$0.isKeyWindow}).first
            keyWindow?.rootViewController?.present(alert, animated: true, completion: nil)
          }
        }
      }
        
      // 5
      if PHPhotoLibrary.authorizationStatus() != .authorized {
        PHPhotoLibrary.requestAuthorization { status in
          if status == .authorized {
            saveVideoToPhotos()
            
          }
        }
      } else {
        saveVideoToPhotos()
      }
    }
}
