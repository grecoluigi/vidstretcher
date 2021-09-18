//
//  AudioSettingsViewController.swift
//  vidstretcher
//
//  Created by Luigi Greco on 05/09/21.
//

import UIKit
import AVKit
import UniformTypeIdentifiers

// Reference to an instance of Audio Settings View Controller to access the activityMonitor from the helper class
var audioSettingsVCInstance = AudioSettingsViewController()

// flags for the VideoComposer to decide if the video has to be exported or played
var previewFlag: Bool?
var exportFlag: Bool?

class AudioSettingsViewController: UIViewController, UIDocumentPickerDelegate {
    
    @IBOutlet weak var audioTrackSlider: UISlider!
    @IBOutlet weak var selectedTrackLabel: UILabel!
    @IBOutlet weak var playPauseButton: UIButton!
    @IBOutlet  weak var activityMonitor: UIActivityIndicatorView!
    @IBOutlet weak var previewButton: UIButton!
    @IBOutlet weak var exportButton: UIButton!
    
    //var player: AVAudioPlayer?
    var player: AVPlayer?
    var playerItem: AVPlayerItem?
    var isPlaying: Bool?

    
    override func viewDidLoad() {
        super.viewDidLoad()
        isPlaying = false
        playPauseButton.isEnabled = false
        audioTrackSlider.isEnabled = false
        selectedTrackLabel.isEnabled = false
        audioSettingsVCInstance = self
        previewFlag = false
        exportFlag = false
        playPauseButton.setTitle("", for: .disabled)

        
        // Set rounded corners for preview and export button
        previewButton.backgroundColor = UIColor(red: 1, green: 0.8, blue: 0, alpha: 1)
        previewButton.layer.cornerRadius = 25
        previewButton.tintColor = .black

        exportButton.backgroundColor = UIColor(red: 0.4275, green: 0.9176, blue: 0, alpha: 1.0)
        exportButton.layer.cornerRadius = 25
        exportButton.tintColor = .black
        
        if let backgroundImage = UIImage(named: "background.jpg") {
            view.backgroundColor = UIColor(patternImage: backgroundImage)
        }
        
        do {
                    try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
                   }
                   catch {
                       print("Setting category to AVAudioSessionCategoryPlayback failed.")
                   }

    }


    
    func selectFiles() {
        var types = UTType.types(tag: "mp3", tagClass: UTTagClass.filenameExtension, conformingTo: UTType.mp3)
        types.append(contentsOf: UTType.types(tag: "wav", tagClass: UTTagClass.filenameExtension, conformingTo: UTType.wav))
        types.append(contentsOf: UTType.types(tag: "m4a", tagClass: UTTagClass.filenameExtension, conformingTo: UTType.mpeg4Audio))
        let documentPickerController = UIDocumentPickerViewController(forOpeningContentTypes: types)
        documentPickerController.delegate = self
        self.present(documentPickerController, animated: true, completion: nil)
        
    }
    
    func setupAudioSlider(){
        audioTrackSlider.maximumValue = Float(VideoAsset.sharedVideoAsset.pickedAudioTrack?.duration.seconds ?? 0)
        playPauseButton.setImage(UIImage(systemName: "play.circle"), for: .normal)
        playPauseButton.isEnabled = true
        playPauseButton.setTitle("Play", for: .normal)

        
        
        audioTrackSlider.isEnabled = true
        selectedTrackLabel.isEnabled = true
        selectedTrackLabel.text =   "Selected track: \(VideoAsset.sharedVideoAsset.pickedURL!.lastPathComponent)"
        audioTrackSlider.setValue(0, animated: true)
        VideoAsset.sharedVideoAsset.externalAudioStartPosition = 0
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let firstURL = urls.first else {
            return
        }
        
        guard firstURL.startAccessingSecurityScopedResource() else {
            print("Can't access the file")
            return
        }
        
        defer { firstURL.stopAccessingSecurityScopedResource() }
        do {
            // Copy all the necessary Assets here because they won't be accessible in the future
            VideoAsset.sharedVideoAsset.pickedURL = firstURL
            VideoAsset.sharedVideoAsset.pickedAudioTrack = AVAsset(url: firstURL)
            setupAudioSlider()
        }
    }
    
    @IBAction func audioSliderValueChanged(_ sender: Any) {
        VideoAsset.sharedVideoAsset.externalAudioStartPosition = Int64(audioTrackSlider.value)
    }
    
    @IBAction func originalAudioTrackSwitch(_ sender: UISwitch) {
        VideoAsset.sharedVideoAsset.discardOriginalAudioTrack = sender.isOn
    }
    
    @IBAction func pickAudioTrackTapped(_ sender: Any) {
        selectFiles()
    }
    
    @IBAction func exportButtonPressed(_ sender: UIButton) {
        if VideoAsset.sharedVideoAsset.movieAsset != nil {
            previewFlag = false
            exportFlag = true
            VideoComposer.videoComposer.retime()
            //self.retime()

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
    
    @IBAction func previewButtonPressed(_ sender: Any) {
        previewFlag = true
        exportFlag = false
        VideoComposer.videoComposer.retime()
    }
    
    @IBAction func playPauseButtonPressed(_ sender: Any) {
        if isPlaying == true {
            player?.replaceCurrentItem(with: nil)
            playPauseButton.setImage(UIImage(systemName: "play.circle"), for: .normal)
            playPauseButton.setTitle("Play", for: .normal)
            isPlaying = false
        } else {
            do {
                //try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
                
                /* The following line is required for the player to work on iOS 11. Change the file type accordingly*/

                playerItem = AVPlayerItem(asset: VideoAsset.sharedVideoAsset.pickedAudioTrack!)
                player = AVPlayer(playerItem: playerItem)
                /* iOS 10 and earlier require the following line:
                 player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileTypeMPEGLayer3) */
        
                guard let player = player else { return }
                let seekValue = CMTime(seconds: Double(audioTrackSlider.value), preferredTimescale: 1)
                playerItem?.seek(to: seekValue, completionHandler: nil)
                player.play()
                isPlaying = true
                playPauseButton.setImage(UIImage(systemName: "pause.circle"), for: .normal)
                playPauseButton.setTitle("Pause", for: .normal)
                
            } catch let error {
                print(error.localizedDescription)
            }
        }
    }
}
