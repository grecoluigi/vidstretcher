//
//  ViewController.swift
//  retimer
//
//  Created by Luigi Greco on 19/08/21.
//

import UIKit
import AVKit
import MobileCoreServices
import Photos
import UniformTypeIdentifiers

class ViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate, UIDocumentPickerDelegate {
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return 3
    }
    

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if component == 0 {
            switch row {
            case 0:
                return "mov"
            case 1:
                return "mp4"
            case 2:
                return "m4v"
            default:
            return "mov"
            }
            
        } else { return "Error" }
    }


    @IBOutlet weak var pickVideoButton: UIButton!
    @IBOutlet weak var stepper: UIStepper!
    @IBOutlet weak var stepperValueLabel: UILabel!
    @IBOutlet weak var activityMonitor: UIActivityIndicatorView!
    @IBOutlet weak var pickerView: UIPickerView!
    @IBOutlet weak var pickAudioTrack: UIActivityIndicatorView!
    
    var discardOriginalAudioTrack: Bool?
    var movieAsset: AVAsset?
    var secondsToRetime = Int()
    var timestamp = CMTimeRange()
    var pickedAudioTrack: AVAsset?
    var pickedURL: URL?
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        discardOriginalAudioTrack = true
        view.overrideUserInterfaceStyle = .dark
        timestamp = CMTimeRange(start: .zero, duration: CMTime(seconds: 30, preferredTimescale: 1))
        pickerView.delegate = self
        pickerView.dataSource = self
        let backgroundImage = UIImageView(frame: UIScreen.main.bounds)
           backgroundImage.image = UIImage(named: "background.jpg")
        backgroundImage.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backgroundImage.contentMode = UIView.ContentMode.scaleAspectFill
           self.view.insertSubview(backgroundImage, at: 0)
        let blurEffect = UIBlurEffect(style: UIBlurEffect.Style.light)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = view.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backgroundImage.addSubview(blurEffectView)
        print(pickerView.selectedRow(inComponent: 0))
        
    }

    @IBAction func pickVideo(_ sender: Any) {
        VideoHelper.startMediaBrowser(delegate: self, sourceType: .savedPhotosAlbum)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard
            let mediaType = info[UIImagePickerController.InfoKey.mediaType] as? String,
            mediaType == (kUTTypeMovie as String),
            let url = info[UIImagePickerController.InfoKey.mediaURL] as? URL
        else { return }
        
        dismiss(animated: true) {
            self.movieAsset = AVAsset(url: url)
            AVAsset(url: url).generateThumbnail { [weak self] (image) in
                DispatchQueue.main.async { [self] in
                               guard let image = image else { return }
                    self?.pickVideoButton.setImage(image, for: .normal)
                    self?.pickVideoButton.imageView?.contentMode = .scaleAspectFit
                    self?.pickVideoButton.setTitle("", for: .normal)
                    self?.stepper.value = (self!.movieAsset?.duration.seconds)!
                    self?.secondsToRetime = Int((self?.stepper.value)!)
                    self?.stepperValueLabel.text = "\(self!.secondsToRetime) seconds"
                    self?.timestamp = CMTimeRange(start: .zero, duration: CMTime(seconds: (self?.stepper.value)!, preferredTimescale: 1))
                           }
                       }
            
//            let player = AVPlayer(url: url)
//            let vcPlayer = AVPlayerViewController()
//            vcPlayer.player = player
//            self.present(vcPlayer, animated: true, completion: nil)
        }
    }
    @IBAction func retimeButtonPressed(_ sender: Any) {
        if self.movieAsset != nil {
            self.retime()
        } else {
            // Tell the user to pick a video first
            
            let title = "No video picked"
            let message = "Pick a video from library before attempting retiming!"

            let alert = UIAlertController(
              title: title,
              message: message,
              preferredStyle: .alert)
            alert.addAction(UIAlertAction(
              title: "OK",
              style: UIAlertAction.Style.cancel,
              handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
        
    }
    
    func retime() {
        activityMonitor.startAnimating()
        let composition = AVMutableComposition()
        
        guard
            let track = composition.addMutableTrack(withMediaType: .video, preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
        else { return }
        do {
            try track.insertTimeRange(CMTimeRangeMake(start: .zero, duration: movieAsset!.duration), of: movieAsset!.tracks(withMediaType: .video)[0], at: .zero)
            track.scaleTimeRange(CMTimeRangeMake(start: .zero, duration: movieAsset!.duration), toDuration: timestamp.duration)
        } catch {
            print("Failed to load asset track")
            return
        }
        
        if discardOriginalAudioTrack == false {
            guard
                let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
            else { return }
            do {
                try track.insertTimeRange(CMTimeRange(start: .zero, duration: movieAsset!.duration), of: movieAsset!.tracks(withMediaType: .audio)[0], at: .zero)
                track.scaleTimeRange(CMTimeRangeMake(start: .zero, duration: movieAsset!.duration), toDuration: timestamp.duration)
            } catch {
                print("Failed to load audio asset track")
                return
            }
        }
        
        let mainInstruction = AVMutableVideoCompositionInstruction()
        mainInstruction.timeRange = CMTimeRangeMake(start: .zero, duration: timestamp.duration)
        let firstInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: movieAsset!.tracks[0])
        var instructionsArray = [AVMutableVideoCompositionLayerInstruction]()
        instructionsArray.append(firstInstruction)
    
        
        if pickedAudioTrack != nil {
            let externalAudioTrack = pickedAudioTrack?.tracks(withMediaType: AVMediaType.audio)[0]
            guard
                let extAudiotrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
            else { return }
            do {
                try extAudiotrack.insertTimeRange(CMTimeRange(start: .zero, duration: movieAsset!.duration), of: externalAudioTrack!, at: .zero)
                //track.scaleTimeRange(CMTimeRangeMake(start: .zero, duration: movieAsset!.duration), toDuration: timestamp.duration)
            } catch {
                print("Failed to load external audio asset track")
                return
            }
            let thirdInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: extAudiotrack)
            instructionsArray.append(thirdInstruction)
        }
        
        
        mainInstruction.layerInstructions = instructionsArray
        let mainComposition = AVMutableVideoComposition()
        mainComposition.instructions = [mainInstruction]
        mainComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
        mainComposition.renderSize = movieAsset!.tracks(withMediaType: .video).first!.naturalSize.applying(track.preferredTransform)
        guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else { return }
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        let date = dateFormatter.string(from: Date())
        let url = documentDirectory.appendingPathComponent("vidstretcher-\(date)" + getFileTypeAsString())
        print(url)
        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else { return }
        exporter.outputURL = url
        exporter.outputFileType = getFileType()
        exporter.shouldOptimizeForNetworkUse = true
        exporter.videoComposition = mainComposition

        
        exporter.exportAsynchronously {
            DispatchQueue.main.async {
                self.exportDidFinish(exporter)
            }
        }
    }
    
    @IBAction func originalAudioTrackSwitch(_ sender: UISwitch) {
        discardOriginalAudioTrack = sender.isOn
    }
    
    func getFileTypeAsString() -> String {
        switch pickerView.selectedRow(inComponent: 0) {
        case 0:
            return ".mov"
        case 1:
            return ".mp4"
        case 2:
            return ".m4v"
        default:
            return ".mov"
        }
    }
    
    func getFileType() -> AVFileType {
        switch pickerView.selectedRow(inComponent: 0) {
        case 0:
            return AVFileType.mov
        case 1:
            return AVFileType.mp4
        case 2:
            return AVFileType.m4v
        default:
            return AVFileType.mov
        }
    }
    

    
    func exportDidFinish(_ session: AVAssetExportSession) {
      // 1
      activityMonitor.stopAnimating()
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
            self.present(alert, animated: true, completion: nil)
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
    
    @IBAction func stepperValueChanged(_ sender: Any) {
        
        secondsToRetime = Int(stepper.value)
        stepperValueLabel.text = "\(secondsToRetime) seconds"
        timestamp = CMTimeRange(start: .zero, duration: CMTime(seconds: stepper.value, preferredTimescale: 1))
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        
    }

    @IBAction func pickAudioTrackTapped(_ sender: Any) {
        selectFiles()
    }
    
    func selectFiles() {
        var types = UTType.types(tag: "mp3", tagClass: UTTagClass.filenameExtension, conformingTo: UTType.mp3)
        types.append(contentsOf: UTType.types(tag: "wav", tagClass: UTTagClass.filenameExtension, conformingTo: UTType.wav))
        types.append(contentsOf: UTType.types(tag: "m4a", tagClass: UTTagClass.filenameExtension, conformingTo: UTType.mpeg4Audio))
        let documentPickerController = UIDocumentPickerViewController(forOpeningContentTypes: types)
        documentPickerController.delegate = self
        self.present(documentPickerController, animated: true, completion: nil)
        
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let firstURL = urls.first else {
            return
        }
        pickedURL = firstURL
        var player: AVPlayer!
        player = try! AVPlayer(url: pickedURL!)
        player.play()
    }
    
    
}

// MARK: - UIImagePickerControllerDelegate
extension ViewController: UIImagePickerControllerDelegate {
}

// MARK: - UINavigationControllerDelegate
extension ViewController: UINavigationControllerDelegate {
}

extension AVAsset {

    func generateThumbnail(completion: @escaping (UIImage?) -> Void) {
        DispatchQueue.global().async {
            let imageGenerator = AVAssetImageGenerator(asset: self)
            let time = CMTime(seconds: 0.0, preferredTimescale: 600)
            let times = [NSValue(time: time)]
            imageGenerator.generateCGImagesAsynchronously(forTimes: times, completionHandler: { _, image, _, _, _ in
                if let image = image {
                    completion(UIImage(cgImage: image))
                } else {
                    completion(nil)
                }
            })
        }
    }
}
