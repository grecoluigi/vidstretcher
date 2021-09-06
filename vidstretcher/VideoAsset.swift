//
//  VideoAsset.swift
//  vidstretcher
//
//  Created by Luigi Greco on 05/09/21.
//

import UIKit
import AVKit
import MobileCoreServices
import Photos
import UniformTypeIdentifiers



class VideoAsset: NSObject {
    
    static var sharedVideoAsset = VideoAsset()
    var discardOriginalAudioTrack: Bool?
    var movieAsset: AVAsset?
    var secondsToRetime = Int()
    var pickedAudioTrack: AVAsset?
    var externalAudioStartPosition: Int64?
    var fileType: AVFileType? {
        didSet {
            switch fileType {
            case AVFileType.mov:
                fileTypeAsString = ".mov"
            case AVFileType.mp4:
                fileTypeAsString = ".mp4"
            case AVFileType.m4v:
                fileTypeAsString = ".m4v"
            default:
                fileTypeAsString = ".mov"
                
            }
        }
    }
    var fileTypeAsString: String?
    var timestamp = CMTimeRange()
    var pickedURL: URL?
    
    override init() {
        super.init()
    }
    


}
