// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation
import UIKit
import BraveShared
import AVKit
import AVFoundation

private class VideoSliderBar: UIControl {
    public var trackerInsets = UIEdgeInsets(top: 0.0, left: 5.0, bottom: 0.0, right: 5.0)
    public var value: CGFloat = 0.0 {
        didSet {
            trackerConstraint?.constant = boundaryView.bounds.size.width * value
            filledConstraint?.constant = value >= 1.0 ? bounds.size.width : ((bounds.size.width - (trackerInsets.left + trackerInsets.right)) * value) + trackerInsets.left
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        tracker.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(onPanned(_:))))
        
        addSubview(background)
        addSubview(boundaryView)
        
        background.addSubview(filledView)
        boundaryView.addSubview(tracker)
        
        background.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        
        boundaryView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        
        filledView.snp.makeConstraints {
            $0.right.top.bottom.equalTo(background)
        }
        
        tracker.snp.makeConstraints {
            $0.centerY.equalTo(boundaryView.snp.centerY)
            $0.width.height.equalTo(12.0)
        }
        
        filledConstraint = filledView.leftAnchor.constraint(equalTo: background.leftAnchor).then {
            $0.isActive = true
        }
        
        trackerConstraint = tracker.centerXAnchor.constraint(equalTo: boundaryView.leftAnchor).then {
            $0.isActive = true
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.background.layer.cornerRadius = self.bounds.size.height / 2.0
        
        boundaryView.snp.remakeConstraints {
            $0.edges.equalToSuperview().inset(self.trackerInsets)
        }
        
        if self.filledConstraint?.constant ?? 0 < self.trackerInsets.left {
            self.filledConstraint?.constant = self.trackerInsets.left
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if tracker.bounds.size.width < 44.0 || tracker.bounds.size.height < 44.0 {
            let adjustedBounds = CGRect(x: tracker.center.x, y: tracker.center.y, width: 0.0, height: 0.0).inset(by: touchInsets)
            
            if adjustedBounds.contains(point) {
                return tracker
            }
        }
        
        return super.hitTest(point, with: event)
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if tracker.bounds.size.width < 44.0 || tracker.bounds.size.height < 44.0 {
            let adjustedBounds = CGRect(x: tracker.center.x, y: tracker.center.y, width: 0.0, height: 0.0).inset(by: touchInsets)
            
            if adjustedBounds.contains(point) {
                return true
            }
        }
        
        return super.point(inside: point, with: event)
    }
    
    @objc
    private func onPanned(_ recognizer: UIPanGestureRecognizer) {
        let offset = min(boundaryView.bounds.size.width, max(0.0, recognizer.location(in: boundaryView).x))
        
        value = offset / boundaryView.bounds.size.width
        
        sendActions(for: .valueChanged)
        
        if recognizer.state == .cancelled || recognizer.state == .ended {
            sendActions(for: .touchUpInside)
        }
    }
    
    private var filledConstraint: NSLayoutConstraint?
    private var trackerConstraint: NSLayoutConstraint?
    
    private let touchInsets = UIEdgeInsets(top: 44.0, left: 44.0, bottom: 44.0, right: 44.0)
    
    private var background = UIView().then {
        $0.backgroundColor = .white
        $0.clipsToBounds = true
    }
    
    private var filledView = UIView().then {
        $0.backgroundColor = #colorLiteral(red: 0.337254902, green: 0.337254902, blue: 0.337254902, alpha: 1)
        $0.clipsToBounds = true
    }
    
    private var boundaryView = UIView().then {
        $0.backgroundColor = .clear
    }
    
    private var tracker = UIImageView().then {
        $0.contentMode = .scaleAspectFit
        $0.isUserInteractionEnabled = true
        //$0.image = #imageLiteral(resourceName: "videoThumbSlider")
    }
}

private protocol VideoTrackerBarDelegate: class {
    func onValueChanged(_ trackBar: VideoTrackerBar, value: CGFloat)
    func onValueEnded(_ trackBar: VideoTrackerBar, value: CGFloat)
}

private class VideoTrackerBar: UIView {
    public weak var delegate: VideoTrackerBarDelegate?
    
    private let slider = VideoSliderBar()
    
    private let currentTimeLabel = UILabel().then {
        $0.text = "0:00"
        $0.textColor = .white
        $0.appearanceTextColor = .white
        $0.font = .systemFont(ofSize: 12.0)
    }
    
    private let endTimeLabel = UILabel().then {
        $0.text = "0:00"
        $0.textColor = .white
        $0.appearanceTextColor = .white
        $0.font = .systemFont(ofSize: 12.0)
    }
    
    public func setTimeRange(currentTime: CMTime, endTime: CMTime) {
        if CMTimeCompare(endTime, .zero) != 0 && endTime.value > 0 {
            slider.value = CGFloat(currentTime.value) / CGFloat(endTime.value)
            
            currentTimeLabel.text = self.timeToString(currentTime)
            endTimeLabel.text = self.timeToString(endTime)
        } else {
            slider.value = 0.0
            currentTimeLabel.text = "0:00"
            endTimeLabel.text = "0:00"
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        slider.addTarget(self, action: #selector(onValueChanged(_:)), for: .valueChanged)
        slider.addTarget(self, action: #selector(onValueEnded(_:)), for: .touchUpInside)
        
        addSubview(slider)
        addSubview(currentTimeLabel)
        addSubview(endTimeLabel)
        
        currentTimeLabel.snp.makeConstraints {
            $0.left.equalToSuperview().inset(10.0)
            $0.top.equalToSuperview().offset(2.0)
            $0.bottom.equalTo(slider.snp.top).offset(-5.0)
        }
        
        endTimeLabel.snp.makeConstraints {
            $0.right.equalToSuperview().inset(10.0)
            $0.top.equalToSuperview().offset(2.0)
            $0.bottom.equalTo(slider.snp.top).offset(-5.0)
        }
        
        slider.snp.makeConstraints {
            $0.left.right.equalToSuperview().inset(10.0)
            $0.centerY.equalToSuperview()
            $0.height.equalTo(2.5)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc
    private func onValueChanged(_ slider: VideoSliderBar) {
        self.delegate?.onValueChanged(self, value: slider.value)
    }
    
    @objc
    private func onValueEnded(_ slider: VideoSliderBar) {
        self.delegate?.onValueEnded(self, value: slider.value)
    }
    
    private func timeToString(_ time: CMTime) -> String {
        let totalSeconds = CMTimeGetSeconds(time)
        let minutes = floor(totalSeconds.truncatingRemainder(dividingBy: 3600.0) / 60.0)
        let seconds = floor(totalSeconds.truncatingRemainder(dividingBy: 60.0))
        return String(format: "%02zu:%02zu", Int(minutes), Int(seconds))
    }
}

public class VideoView: UIView, VideoTrackerBarDelegate {
    private let player = AVPlayer(playerItem: nil).then {
        $0.seek(to: .zero)
        $0.actionAtItemEnd = .none
    }
    
    private let thumbnailView = UIImageView().then {
        $0.contentMode = .scaleAspectFit
    }
    
    private let overlayView = UIImageView().then {
        $0.contentMode = .scaleAspectFit
        $0.isUserInteractionEnabled = true
    }
    
    private let skipBackButton = UIButton().then {
        $0.imageView?.contentMode = .scaleAspectFit
        $0.setImage(#imageLiteral(resourceName: "videoSkipBack"), for: .normal)
        $0.tintColor = .white
    }
    
    private let skipForwardButton = UIButton().then {
        $0.imageView?.contentMode = .scaleAspectFit
        $0.setImage(#imageLiteral(resourceName: "videoSkipForward"), for: .normal)
        $0.tintColor = .white
    }
    
    private let playPauseButton = UIButton().then {
        $0.imageView?.contentMode = .scaleAspectFit
        $0.setImage(#imageLiteral(resourceName: "videoPlay"), for: .normal)
        $0.tintColor = .white
    }
    
    private let castButton = UIButton().then {
        $0.imageView?.contentMode = .scaleAspectFit
        $0.setImage(#imageLiteral(resourceName: "videoAirplay"), for: .normal)
        
        let routePicker = AVRoutePickerView()
        routePicker.tintColor = .clear
        routePicker.activeTintColor = .clear

        if #available(iOS 13.0, *) {
            routePicker.prioritizesVideoDevices = true
        }
        
        $0.addSubview(routePicker)
        routePicker.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }
    
    private let fullScreenButton = UIButton().then {
        $0.imageView?.contentMode = .scaleAspectFit
        $0.setImage(#imageLiteral(resourceName: "videoFullscreen"), for: .normal)
    }
    
    private let exitFullScreenButton = UIButton().then {
        $0.imageView?.contentMode = .scaleAspectFit
        $0.setImage(#imageLiteral(resourceName: "close-medium").template, for: .normal)
        $0.tintColor = .white
        $0.isHidden = true
    }
    
    private let trackBarBackground = UIView().then {
        $0.contentMode = .scaleAspectFit
        $0.backgroundColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 0.6004120291)
    }
    
    private let playControlsStackView = UIStackView().then {
        $0.axis = .horizontal
        $0.alignment = .fill
        $0.distribution = .fillEqually
        $0.spacing = 15.0
    }
    
    private let trackBar = VideoTrackerBar()
    private let orientation: UIInterfaceOrientation = .portrait
    private var playObserver: Any?
    
    private(set) public var isPlaying: Bool = false
    private(set) public var isSeeking: Bool = false
    private(set) public var isFullscreen: Bool = false
    private(set) public var isOverlayDisplayed: Bool = true
    private var notificationObservers = [NSObjectProtocol]()
    
    override init(frame: CGRect) {
        super.init(frame: frame)

        //Setup
        self.backgroundColor = .black
        self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onOverlayTapped(_:))).then {
            $0.numberOfTapsRequired = 1
            $0.numberOfTouchesRequired = 1
        })
        
        (self.layer as? AVPlayerLayer)?.do {
            $0.player = self.player
            $0.videoGravity = .resizeAspect
            $0.needsDisplayOnBoundsChange = true
        }

        playPauseButton.addTarget(self, action: #selector(onPlay(_:)), for: .touchUpInside)
        castButton.addTarget(self, action: #selector(onCast(_:)), for: .touchUpInside)
        fullScreenButton.addTarget(self, action: #selector(onFullscreen(_:)), for: .touchUpInside)
        exitFullScreenButton.addTarget(self, action: #selector(onExitFullscreen(_:)), for: .touchUpInside)
        
        //Layout
        self.addSubview(trackBarBackground)
        self.addSubview(thumbnailView)
        self.addSubview(overlayView)
        self.overlayView.addSubview(playControlsStackView)
        self.overlayView.addSubview(castButton)
        self.overlayView.addSubview(fullScreenButton)
        self.overlayView.addSubview(exitFullScreenButton)
        self.overlayView.addSubview(trackBar)
        
        [skipBackButton, playPauseButton, skipForwardButton].forEach({ playControlsStackView.addArrangedSubview($0) })
        
        trackBarBackground.snp.makeConstraints {
            $0.left.right.bottom.equalToSuperview()
            $0.top.equalTo(trackBar.snp.top)
        }
        
        thumbnailView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        
        overlayView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        
        playControlsStackView.snp.makeConstraints {
            $0.center.equalToSuperview()
        }
        
        trackBar.snp.makeConstraints {
            $0.left.right.bottom.equalToSuperview()
        }
        
        castButton.snp.makeConstraints {
            $0.top.right.equalToSuperview().inset(10.0)
        }
        
        fullScreenButton.snp.makeConstraints {
            $0.top.equalToSuperview().inset(12.0)
            $0.right.equalTo(castButton.snp.left).offset(-20.0)
        }
        
        exitFullScreenButton.snp.makeConstraints {
            $0.right.equalToSuperview().offset(-15.0)
            $0.top.equalToSuperview().offset(15.0)
        }
        
        registerNotifications()
        trackBar.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        if let observer = self.playObserver {
            player.removeTimeObserver(observer)
        }
        
        notificationObservers.forEach({
            NotificationCenter.default.removeObserver($0)
        })
    }
    
    public override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
    
    @objc
    private func onOverlayTapped(_ gestureRecognizer: UITapGestureRecognizer) {
        if isSeeking {
            showOverlays(true, except: [overlayView, playPauseButton], display: [trackBarBackground, trackBar])
        } else if isPlaying && !isOverlayDisplayed {
            showOverlays(true)
            isOverlayDisplayed = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.isOverlayDisplayed = false
                if self.isPlaying && !self.isSeeking {
                    self.showOverlays(false)
                }
            }
        } else if !isPlaying && !isSeeking && !isOverlayDisplayed {
            showOverlays(true)
            isOverlayDisplayed = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.isOverlayDisplayed = false
                if self.isPlaying && !self.isSeeking {
                    self.showOverlays(false)
                }
            }
        }
    }
    
    @objc
    private func onPlay(_ button: UIButton) {
        if self.isPlaying {
            self.pause()
        } else {
            self.play()
        }
    }
    
    @objc
    private func onCast(_ button: UIButton) {
        //print("Route Picker Video")
    }
    
    @objc
    private func onFullscreen(_ button: UIButton) {
        
    }
    
    @objc
    private func onExitFullscreen(_ button: UIButton) {
        
    }
    
    fileprivate func onValueChanged(_ trackBar: VideoTrackerBar, value: CGFloat) {
        isSeeking = true
        
        if isPlaying {
            player.pause()
        }
        
        showOverlays(false, except: [trackBar, trackBarBackground], display: [trackBar, trackBarBackground])
        
        if let currentItem = player.currentItem {
            let seekTime = CMTimeMakeWithSeconds(Float64(value * CGFloat(currentItem.asset.duration.value) / CGFloat(currentItem.asset.duration.timescale)), preferredTimescale: currentItem.currentTime().timescale)
            player.seek(to: seekTime)
        }
    }
    
    fileprivate func onValueEnded(_ trackBar: VideoTrackerBar, value: CGFloat) {
        isSeeking = false
        
        if self.isPlaying {
            player.play()
        }
        
        showOverlays(false, except: [overlayView], display: [overlayView])
        overlayView.alpha = 1.0
    }
    
    private func registerNotifications() {
        notificationObservers.append(NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: self.player.currentItem, queue: .main) { [weak self] _ in
            guard let self = self, let currentItem = self.player.currentItem else { return }
            
            self.playPauseButton.isEnabled = false
            self.playPauseButton.setImage(nil, for: .normal)
            self.player.pause()
            
            let endTime = CMTimeConvertScale(currentItem.asset.duration, timescale: self.player.currentTime().timescale, method: .roundHalfAwayFromZero)
            
            self.trackBar.setTimeRange(currentTime: currentItem.currentTime(), endTime: endTime)
            self.player.seek(to: .zero)
            
            self.isPlaying = false
            self.playPauseButton.isEnabled = true
            self.showOverlays(true)
            
            if self.isFullscreen {
                self.onFullscreen(self.fullScreenButton)
            }
        })
        
        notificationObservers.append(NotificationCenter.default.addObserver(forName: UIDevice.orientationDidChangeNotification, object: UIDevice.current, queue: .main) { _ in
            
        })
        
        let interval = CMTimeMake(value: 25, timescale: 1000)
        self.playObserver = self.player.addPeriodicTimeObserver(forInterval: interval, queue: .main, using: { [weak self] time in
            guard let self = self, let currentItem = self.player.currentItem else { return }
            
            let endTime = CMTimeConvertScale(currentItem.asset.duration, timescale: self.player.currentTime().timescale, method: .roundHalfAwayFromZero)
            
            if CMTimeCompare(endTime, .zero) != 0 && endTime.value > 0 {
                self.trackBar.setTimeRange(currentTime: self.player.currentTime(), endTime: endTime)
            }
        })
    }
    
    private func showOverlays(_ show: Bool) {
        self.showOverlays(show, except: [self.overlayView], display: [])
    }
    
    private func showOverlays(_ show: Bool, except: [UIView] = [], display: [UIView] = []) {
        UIView.animate(withDuration: 1.0, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 1.0, options: .curveEaseInOut, animations: {
            self.subviews.forEach({
                if except.contains($0) {
                    $0.alpha = !show ? 1.0 : 0.0
                } else if display.contains($0) {
                    $0.alpha = 1.0
                }
            })
        })
    }
    
    public func play() {
        if !isPlaying {
            isPlaying.toggle()
            playPauseButton.setImage(#imageLiteral(resourceName: "videoPause"), for: .normal)
            player.play()
            
            showOverlays(false)
        }
    }
    
    public func pause() {
        if isPlaying {
            isPlaying.toggle()
            playPauseButton.setImage(#imageLiteral(resourceName: "videoPlay"), for: .normal)
            player.pause()
            
            showOverlays(true)
        }
    }
    
    public func stop() {
        isPlaying = false
        playPauseButton.setImage(#imageLiteral(resourceName: "videoPlay"), for: .normal)
        player.pause()
        
        showOverlays(true)
        player.replaceCurrentItem(with: nil)
    }
    
    public func load(url: URL, resourceDelegate: AVAssetResourceLoaderDelegate?) {
        thumbnailView.isHidden = false
        let asset = AVURLAsset(url: url)
        
        if let delegate = resourceDelegate {
            asset.resourceLoader.setDelegate(delegate, queue: .main)
        }
        
        if let currentItem = player.currentItem, currentItem.asset.isKind(of: AVURLAsset.self) && player.status == .readyToPlay {
            if let asset = currentItem.asset as? AVURLAsset, asset.url.absoluteString == url.absoluteString {
                thumbnailView.isHidden = true
                
                if isPlaying {
                    player.pause()
                    player.play()
                }
                
                return
            }
        }
        
        asset.loadValuesAsynchronously(forKeys: ["playable", "tracks", "duration"]) { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.async {
                let item = AVPlayerItem(asset: asset)
                self.player.replaceCurrentItem(with: item)
                
                let endTime = CMTimeConvertScale(item.asset.duration, timescale: self.player.currentTime().timescale, method: .roundHalfAwayFromZero)
                self.trackBar.setTimeRange(currentTime: item.currentTime(), endTime: endTime)
                self.thumbnailView.isHidden = true
                self.play()
            }
        }
    }
}
