//
//  ViewController.swift
//  MovieTrim
//
//  Created by cano on 2019/08/30.
//  Copyright © 2019 deskplate. All rights reserved.
//

import UIKit
import PryntTrimmerView
import AVKit
import Photos
import SVProgressHUD

class ViewController: UIViewController {
    
    @IBOutlet weak var trimmerView: TrimmerView!
    
    @IBOutlet weak var playerView: UIView!
    @IBOutlet weak var btnPlay: UIButton!
    var player: AVPlayer?
    var playbackTimeCheckerTimer: Timer?
    var trimmerPositionChangedTimer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        trimmerView.handleColor = UIColor.white
        trimmerView.mainColor = UIColor.darkGray
        
        // Do any additional setup after loading the view.
        
        // アクセス許可 忘れないように
        PHPhotoLibrary.requestAuthorization { (status) in
            if status == .authorized {
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // ビデオをプレイヤーにセット
    private func addVideoPlayer(with asset: AVAsset, playerView: UIView) {
        Loading.start()
        
        let playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)
        
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.itemDidFinishPlaying(_:)),
                                               name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: playerItem)
        
        let layer: AVPlayerLayer = AVPlayerLayer(player: player)
        layer.backgroundColor = UIColor.white.cgColor
        layer.frame = CGRect(x: 0, y: 0, width: playerView.frame.width, height: playerView.frame.height)
        layer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        playerView.layer.sublayers?.forEach({$0.removeFromSuperlayer()})
        playerView.layer.addSublayer(layer)
        
        Loading.stop()
    }
    
    @objc func itemDidFinishPlaying(_ notification: Notification) {
        if let startTime = trimmerView.startTime {
            player?.seek(to: startTime)
            
            print("startTime")
            print(startTime)
        }
    }
    
    func startPlaybackTimeChecker() {
        stopPlaybackTimeChecker()
        playbackTimeCheckerTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self,
                                                        selector:
            #selector(ViewController.onPlaybackTimeChecker), userInfo: nil, repeats: true)
    }
    
    func stopPlaybackTimeChecker() {
        playbackTimeCheckerTimer?.invalidate()
        playbackTimeCheckerTimer = nil
    }
    
    @objc func onPlaybackTimeChecker() {
        guard let startTime = trimmerView.startTime, let endTime = trimmerView.endTime, let player = player else {
            return
        }
        
        let playBackTime = player.currentTime()
        trimmerView.seek(to: playBackTime)
        
        if playBackTime >= endTime {
            player.seek(to: startTime, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
            trimmerView.seek(to: startTime)
        }
    }
    
    //MARK:- Actions
    @IBAction func play(_ sender: Any) {
        
        guard let player = player else { return }
        
        if !player.isPlaying {
            player.play()
            startPlaybackTimeChecker()
        } else {
            player.pause()
            
            stopPlaybackTimeChecker()
        }
    }
    
    // ピッカー起動
    @IBAction func selectAsset(_ sender: Any) {
        let imagePickerController = UIImagePickerController()
        imagePickerController.sourceType = .photoLibrary
        imagePickerController.delegate = self
        imagePickerController.mediaTypes = ["public.movie"]
        present(imagePickerController, animated: true, completion: nil)
    }
    
    // 切り出した映像をカメラロールに保存
    @IBAction func onSave(_ sender: Any) {
        do{
            // asset情報
            guard let asset = trimmerView.asset, let videoTrack = asset.tracks(withMediaType: AVMediaType.video).first else {
                return
            }
            
            // ベースとなる動画のコンポジション作成
            let assetComposition = AVMutableComposition()
            // 映像再生範囲
            let trackTimeRange = CMTimeRangeMake(start: trimmerView.startTime!, duration: trimmerView.endTime!)
            // 動画のサイズを取得
            var videoSize: CGSize = videoTrack.naturalSize
            
            // ビデオ用トラック
            guard let videoCompositionTrack =
                assetComposition.addMutableTrack(withMediaType: .video,
                                                 preferredTrackID: kCMPersistentTrackID_Invalid)
                else { return }
            videoCompositionTrack.preferredTransform = videoTrack.preferredTransform
            try videoCompositionTrack.insertTimeRange(trackTimeRange, of: videoTrack, at: CMTime.zero)
            
            // 音声用トラック
            if let audioTrack = asset.tracks(withMediaType: AVMediaType.audio).first {
                let audioCompositionTrack =
                    assetComposition.addMutableTrack(withMediaType: AVMediaType.audio,
                                                     preferredTrackID: kCMPersistentTrackID_Invalid)
                try audioCompositionTrack?.insertTimeRange(trackTimeRange, of: audioTrack, at: CMTime.zero)
            }
            
            Loading.start()
            
            // トラックの詳細を指定
            let mainInstructions = AVMutableVideoCompositionInstruction()
            mainInstructions.timeRange = CMTimeRangeMake(start: CMTime.zero, duration: asset.duration)
            
            // インストラクション作成
            let layerInstructions = AVMutableVideoCompositionLayerInstruction(assetTrack: videoCompositionTrack)
            layerInstructions.setOpacity(1.0, at: CMTime.zero)
            
            // ビデオの方向を取得 これを忘れると縦向きでも横向き動画として保存される
            var isPortrait: Bool = false
            // ビデオを縦横方向
            let txf = videoTrack.preferredTransform
            if txf.tx == videoSize.width && txf.ty == videoSize.height {
                // landscape right
            } else if txf.tx == 0 && txf.ty == 0 {
                // landscape left
            } else if txf.tx == 0 && txf.ty == videoSize.width {
                // portrait upside down
                isPortrait = true
                videoSize = CGSize(width: videoSize.height, height: videoSize.width)
            } else  {
                // portrait
                isPortrait = true
                videoSize = CGSize(width: videoSize.height, height: videoSize.width)
            }
            // 縦方向で撮影なら90度回転させる
            if isPortrait {
                let FirstAssetScaleFactor:CGAffineTransform = CGAffineTransform(scaleX: 1.0, y: 1.0)
                layerInstructions.setTransform(videoTrack.preferredTransform.concatenating(FirstAssetScaleFactor), at: CMTime.zero)
            }
            // インストラクションを設定
            mainInstructions.layerInstructions = [layerInstructions]
            
            // 合成用コンポジション作成
            let videoComposition = AVMutableVideoComposition()
            videoComposition.renderSize = videoSize
            videoComposition.instructions = [mainInstructions]
            videoComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
            
            let url = URL(fileURLWithPath: "\(NSTemporaryDirectory())TrimmedMovie.mp4")
            try? FileManager.default.removeItem(at: url)
            
            // 動画のコンポジションをベースにAVAssetExportを生成
            let exportSession = AVAssetExportSession(asset: assetComposition, presetName: AVAssetExportPresetHighestQuality)
            exportSession?.outputFileType = AVFileType.mp4
            exportSession?.shouldOptimizeForNetworkUse = true
            exportSession?.videoComposition = videoComposition  // ビデオトラックを指定
            exportSession?.outputURL = url
            exportSession?.exportAsynchronously(completionHandler: {
                
                DispatchQueue.main.async {
                    
                    if let url = exportSession?.outputURL, exportSession?.status == .completed {
                        UISaveVideoAtPathToSavedPhotosAlbum(url.path, nil, nil, nil)
                        print("save ok")
                        Loading.stop()
                        SVProgressHUD.showSuccess(withStatus:" saved !")
                    } else {
                        let error = exportSession?.error
                        print("error exporting video \(String(describing: error))")
                        Loading.stop()
                    }
                }
            })
        } catch let error {
            print(error.localizedDescription)
        }
    }
}

// 映像選択時
extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let pHAsset = info[UIImagePickerController.InfoKey.phAsset] as? PHAsset{
            PHCachingImageManager().requestAVAsset(forVideo: pHAsset, options: nil) {  [unowned self](avAsset, _, _) in
                DispatchQueue.main.async {
                    if let asset = avAsset {
                        self.trimmerView.asset = asset
                        self.trimmerView.delegate = self
                        self.addVideoPlayer(with: asset, playerView: self.playerView)
                        picker.dismiss(animated: true, completion: nil)
                    }
                }
            }
        }
    }
}

// 切り出し位置を変更した場合の処理
extension ViewController: TrimmerViewDelegate {
    func positionBarStoppedMoving(_ playerTime: CMTime) {
        player?.seek(to: playerTime, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
        player?.play()
        startPlaybackTimeChecker()
    }
    
    func didChangePositionBar(_ playerTime: CMTime) {
        stopPlaybackTimeChecker()
        player?.pause()
        player?.seek(to: playerTime, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
        let duration = (trimmerView.endTime! - trimmerView.startTime!).seconds
        print(duration)
    }
}

extension AVPlayer {
    var isPlaying: Bool {
        return self.rate != 0 && self.error == nil
    }
}

extension AVAsset {
    var screenSize: CGSize? {
        if let track = tracks(withMediaType: .video).first {
            let size = __CGSizeApplyAffineTransform(track.naturalSize, track.preferredTransform)
            return CGSize(width: abs(size.width), height: abs(size.height))
        }
        return nil
    }
}


