//
//  AudioPlayer.swift
//  Waveforms
//
//  Created by Viraj Patel on 12/09/23.
//

import Foundation
import AVKit
import AVFoundation

class AudioPlayer: NSObject, AVAudioPlayerDelegate {
  
  private var seekToStart = true
  private var stopWhenCompleted = false
  private var timer: Timer?
  private var player: AVAudioPlayer?
  private var avPlayer: AVPlayer?
  private var timeObserver: Any?
  private var isUsingAVPlayer = false
  private var finishMode: FinishMode = FinishMode.stop
  private var updateFrequency = UpdateFrequency.medium
  var plugin: AudioWaveform
  var playerKey: String
  var rnChannel: AnyObject
  private var isComponentMounted: Bool = true // Add flag to track mounted state
  
  init(plugin: AudioWaveform, playerKey: String, channel: AnyObject) {
    self.plugin = plugin
    self.playerKey = playerKey
    self.rnChannel = channel
    super.init()
  }
  
  func preparePlayer(_ path: String?, source: [String: Any]?, volume: Double?, updateFrequency: UpdateFrequency, time: Double, resolver resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
    var audioUrl: URL?
    var headers: [String: String] = [:]
    
    // Determine the URL from either path or source
    if let sourceDict = source, let uri = sourceDict["uri"] as? String, !uri.isEmpty {
      audioUrl = URL(string: uri)
      if let sourceHeaders = sourceDict["headers"] as? [String: String] {
        headers = sourceHeaders
      }
    } else if let pathString = path, !pathString.isEmpty {
      audioUrl = URL(string: pathString)
    }
    
    guard let url = audioUrl else {
      reject(Constants.audioWaveforms, "Failed to initialise URL from provided audio source. If path contains `file://` try removing it", NSError(domain: Constants.audioWaveforms, code: 1))
      return
    }
    
    self.updateFrequency = updateFrequency
    isComponentMounted = true
    
    // Check if it's a remote URL that needs special handling
    if url.scheme == "http" || url.scheme == "https" {
      prepareRemotePlayer(url: url, headers: headers, volume: volume, time: time, resolve: resolve, reject: reject)
    } else {
      prepareLocalPlayer(url: url, volume: volume, time: time, resolve: resolve, reject: reject)
    }
  }
  
  private func prepareLocalPlayer(url: URL, volume: Double?, time: Double, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    do {
      isUsingAVPlayer = false
      player = try AVAudioPlayer(contentsOf: url)
      player?.prepareToPlay()
      player?.volume = Float(volume ?? 100.0)
      player?.currentTime = Double(time / 1000)
      player?.enableRate = true
      player?.delegate = self
      resolve(true)
    } catch let error as NSError {
      reject(Constants.audioWaveforms, error.localizedDescription, error)
    }
  }
  
  private func prepareRemotePlayer(url: URL, headers: [String: String], volume: Double?, time: Double, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
    isUsingAVPlayer = true
    
    var urlAsset: AVURLAsset
    if !headers.isEmpty {
      urlAsset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
    } else {
      urlAsset = AVURLAsset(url: url)
    }
    
    let playerItem = AVPlayerItem(asset: urlAsset)
    avPlayer = AVPlayer(playerItem: playerItem)
    avPlayer?.volume = Float(volume ?? 1.0)
    
    // Seek to the specified time
    if time > 0 {
      let seekTime = CMTime(seconds: time / 1000, preferredTimescale: 600)
      avPlayer?.seek(to: seekTime)
    }
    
    // Set up observers for AVPlayer
    setupAVPlayerObservers()
    
    // Wait for the player to be ready
    let semaphore = DispatchSemaphore(value: 0)
    var isReady = false
    var prepareError: Error?
    
    let observer = playerItem.observe(\.status) { item, _ in
      switch item.status {
      case .readyToPlay:
        isReady = true
        semaphore.signal()
      case .failed:
        prepareError = item.error
        semaphore.signal()
      default:
        break
      }
    }
    
    let timeoutResult = semaphore.wait(timeout: .now() + 30.0) // 30 second timeout
    observer.invalidate()
    
    if timeoutResult == .timedOut {
      reject(Constants.audioWaveforms, "Timeout preparing remote audio player", NSError(domain: Constants.audioWaveforms, code: 1))
      return
    }
    
    if let error = prepareError {
      reject(Constants.audioWaveforms, error.localizedDescription, error as NSError)
      return
    }
    
    if isReady {
      resolve(true)
    } else {
      reject(Constants.audioWaveforms, "Failed to prepare remote audio player", NSError(domain: Constants.audioWaveforms, code: 1))
    }
  }
  
  private func setupAVPlayerObservers() {
    guard let avPlayer = avPlayer else { return }
    
    // Add time observer for progress updates
    let interval = CMTime(seconds: Double(updateFrequency.rawValue) / 1000.0, preferredTimescale: 600)
    timeObserver = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
      guard let self = self else { return }
      let ms = Int(time.seconds * 1000)
      self.sendEvent(withName: Constants.onCurrentDuration, body: [Constants.currentDuration: ms, Constants.playerKey: self.playerKey])
    }
    
    // Add observer for playback finished
    NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: avPlayer.currentItem,
      queue: .main
    ) { [weak self] _ in
      self?.handlePlaybackFinished()
    }
  }
  
  private func handlePlaybackFinished() {
    var finishType = FinishMode.stop.rawValue
    switch self.finishMode {
    case .loop:
      avPlayer?.seek(to: .zero)
      avPlayer?.play()
      finishType = FinishMode.loop.rawValue
    case .pause:
      avPlayer?.pause()
      finishType = FinishMode.pause.rawValue
    case .stop:
      avPlayer?.pause()
      finishType = FinishMode.stop.rawValue
    }
    self.sendEvent(withName: Constants.onDidFinishPlayingAudio, body: [Constants.finishType: finishType, Constants.playerKey: playerKey])
  }

  func markPlayerAsUnmounted() {
    isComponentMounted = false
  }
  
  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer,
                                   successfully flag: Bool) {
    var finishType = FinishMode.stop.rawValue
    switch self.finishMode {
    case .loop:
      self.player?.currentTime = 0
      self.player?.play()
      finishType = FinishMode.loop.rawValue
    case .pause:
      self.player?.pause()
      stopListening()
      finishType = FinishMode.pause.rawValue
    case .stop:
      self.player?.stop()
      stopListening()
      self.player = nil
      finishType = FinishMode.stop.rawValue
    }
    self.sendEvent(withName: Constants.onDidFinishPlayingAudio, body:  [Constants.finishType: finishType, Constants.playerKey: playerKey])
  }
  
  
  public func sendEvent(withName: String, body: Any?) {
    guard isComponentMounted else {
      return
    }
    EventEmitter.sharedInstance.dispatch(name: withName, body: body)
  }
  
    func startPlayer(_ finishMode: Int?, speed: Float, result: RCTPromiseResolveBlock) {
    if(finishMode != nil && finishMode == 0) {
      self.finishMode = FinishMode.loop
    } else if(finishMode != nil && finishMode == 1) {
      self.finishMode = FinishMode.pause
    } else {
      self.finishMode = FinishMode.stop
    }
    
    if isUsingAVPlayer {
      avPlayer?.rate = speed
      avPlayer?.play()
      result(avPlayer?.rate != 0)
    } else {
      player?.play()
      player?.delegate = self
      player?.rate = Float(speed)
      timerUpdate()
      startListening()
      result(player?.isPlaying)
    }
  }
  
  func pausePlayer(result: @escaping RCTPromiseResolveBlock) {
    if isUsingAVPlayer {
      avPlayer?.pause()
    } else {
      stopListening()
      player?.pause()
      timerUpdate()
    }
    result(true)
  }
  
  func stopPlayer() {
    if isUsingAVPlayer {
      avPlayer?.pause()
      if let timeObserver = timeObserver {
        avPlayer?.removeTimeObserver(timeObserver)
        self.timeObserver = nil
      }
      NotificationCenter.default.removeObserver(self)
      avPlayer = nil
    } else {
      stopListening()
      player?.stop()
      timerUpdate()
      player = nil
      timer = nil
    }
  }
  
  func getDuration(_ type: DurationType, _ result: @escaping RCTPromiseResolveBlock) {
    if isUsingAVPlayer {
      if type == .Current {
        let ms = Int((avPlayer?.currentTime().seconds ?? 0) * 1000)
        result(ms)
      } else {
        let ms = Int((avPlayer?.currentItem?.duration.seconds ?? 0) * 1000)
        result(ms)
      }
    } else {
      if type == .Current {
        let ms = (player?.currentTime ?? 0) * 1000
        result(Int(ms))
      } else {
        let ms = (player?.duration ?? 0) * 1000
        result(Int(ms))
      }
    }
  }
  
  func setVolume(_ volume: Double?, _ result: @escaping RCTPromiseResolveBlock) {
    if isUsingAVPlayer {
      avPlayer?.volume = Float(volume ?? 1.0)
    } else {
      player?.volume = Float(volume ?? 1.0)
    }
    result(true)
  }
  
  func seekTo(_ time: Double?, _ result: @escaping RCTPromiseResolveBlock) {
    if let time = time, time != 0 {
      if isUsingAVPlayer {
        let seekTime = CMTime(seconds: time / 1000, preferredTimescale: 600)
        avPlayer?.seek(to: seekTime)
      } else {
        player?.currentTime = Double(time / 1000)
      }
      result(true)
    } else {
      result(false)
    }
  }
  
    @objc func timerUpdate() {
        let ms = (self.player?.currentTime ?? 0) * 1000
        self.sendEvent(withName: Constants.onCurrentDuration, body: [ Constants.currentDuration: Int(ms), Constants.playerKey: self.playerKey] as [String : Any])
    }
    
    func startListening() {
      stopListening()
        DispatchQueue.main.async { [weak self] in
          guard let strongSelf = self else {return }
            strongSelf.timer = Timer.scheduledTimer(timeInterval: TimeInterval((Float(strongSelf.updateFrequency.rawValue) / 1000)), target: strongSelf, selector: #selector(strongSelf.timerUpdate), userInfo: nil, repeats: true)
        }
    }
    
    func setPlaybackSpeed(_ speed: Float) -> Bool {
        if isUsingAVPlayer {
            avPlayer?.rate = speed
            return true
        } else {
            if let player = player {
                player.enableRate = true
                player.rate = Float(speed)
                return true
            } else {
                return false
            }
        }
    }
  
  func stopListening() {
    timer?.invalidate()
    timer = nil
  }
}
