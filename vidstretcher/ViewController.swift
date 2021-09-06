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

class ViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {
    
    

    @IBOutlet weak var pickVideoButton: UIButton!
    @IBOutlet weak var stepper: UIStepper!
    @IBOutlet weak var stepperValueLabel: UILabel!
    @IBOutlet weak var activityMonitor: UIActivityIndicatorView!
    @IBOutlet weak var pickerView: UIPickerView!
    @IBOutlet weak var pickAudioTrack: UIActivityIndicatorView!

    @IBOutlet weak var nextButton: UIButton!

    override func viewDidLoad() {
        
        super.viewDidLoad()

        // Setting defaults
        VideoAsset.sharedVideoAsset.discardOriginalAudioTrack = true
        VideoAsset.sharedVideoAsset.fileType = AVFileType.mov
        VideoAsset.sharedVideoAsset.timestamp = CMTimeRange(start: .zero, duration: CMTime(seconds: 30, preferredTimescale: 1))
        
        
        view.overrideUserInterfaceStyle = .light
        
        pickerView.delegate = self
        pickerView.dataSource = self
        nextButton.isEnabled = false
        nextButton.setTitleColor(.systemGray, for: .disabled)

        if let backgroundImage = UIImage(named: "background.jpg") {
            view.backgroundColor = UIColor(patternImage: backgroundImage)
        }

    }
    
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
            VideoComposer.videoComposer.pickedVideo(url: url)
            VideoAsset.sharedVideoAsset.pickedURL = url
            AVAsset(url: url).generateThumbnail { [weak self] (image) in
                DispatchQueue.main.async { [self] in
                    guard let image = image else { return }
                    self?.pickVideoButton.setImage(image, for: .normal)
                    self?.pickVideoButton.imageView?.contentMode = .scaleAspectFit
                    self?.pickVideoButton.setTitle("", for: .normal)
                    self?.stepper.value = VideoAsset.sharedVideoAsset.movieAsset!.duration.seconds
                    VideoAsset.sharedVideoAsset.secondsToRetime = Int((self?.stepper.value)!)
                    self?.stepperValueLabel.text = "\(VideoAsset.sharedVideoAsset.secondsToRetime) seconds"
                    VideoAsset.sharedVideoAsset.timestamp = CMTimeRange(start: .zero, duration: CMTime(seconds: (self?.stepper.value)!, preferredTimescale: 1))
                           }
                       }
            
//            let player = AVPlayer(url: url)
//            let vcPlayer = AVPlayerViewController()
//            vcPlayer.player = player
//            self.present(vcPlayer, animated: true, completion: nil)
        }
        nextButton.isEnabled = true

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
    
    
    @IBAction func stepperValueChanged(_ sender: Any) {
        
        VideoAsset.sharedVideoAsset.secondsToRetime = Int(stepper.value)
        stepperValueLabel.text = "\(VideoAsset.sharedVideoAsset.secondsToRetime) seconds"
        VideoAsset.sharedVideoAsset.timestamp = CMTimeRange(start: .zero, duration: CMTime(seconds: stepper.value, preferredTimescale: 1))
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        
    }


    
    
    @IBAction func playPauseButtonPressed(_ sender: Any) {
        
        
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
