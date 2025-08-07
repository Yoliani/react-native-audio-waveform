//
//  AudioPlayer.swift
//  Waveforms
//
//  Created by Viraj Patel on 12/09/23.
//

import Foundation
import AVKit

class AudioPlayer: NSObject, AVAudioPlayerDelegate {
  
  private var seekToStart = true
  private var stopWhenCompleted = false
  private var timer: Timer?
  private var player: AVAudioPlayer?
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
    
    // Determine the URL from either path or source
    if let sourceDict = source, let uri = sourceDict["uri"] as? String, !uri.isEmpty {
      audioUrl = URL(string: uri)
    } else if let pathString = path, !pathString.isEmpty {
      audioUrl = URL(string: pathString)
    }
    
    guard let url = audioUrl else {
      reject(Constants.audioWaveforms, "Failed to initialise URL from provided audio source. If path contains `file://` try removing it", NSError(domain: Constants.audioWaveforms, code: 1))
      return
    }
    
    self.updateFrequency = updateFrequency
    isComponentMounted = true
    
    do {
      // For HTTP/HTTPS URLs, we might need to handle headers
      if let sourceDict = source, let headers = sourceDict["headers"] as? [String: String], url.scheme == "http" || url.scheme == "https" {
        var request = URLRequest(url: url)
        for (key, value) in headers {
          request.setValue(value, forHTTPHeaderField: key)
        }
        
        // For remote URLs with headers, we'll need to handle this differently
        // For now, we'll create the player with the URL and note that headers handling might be limited
        player = try AVAudioPlayer(contentsOf: url)
      } else {
        player = try AVAudioPlayer(contentsOf: url)
      }
      
      player?.prepareToPlay()
      player?.volume = Float(volume ?? 100.0)
      player?.currentTime = Double(time / 1000)
      player?.enableRate = true
      resolve(true)
    } catch let error as NSError {
      reject(Constants.audioWaveforms, error.localizedDescription, error)
      return
    }
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
      player?.play()
      player?.delegate = self
      player?.rate = Float(speed)
      timerUpdate()
      startListening()
      result(player?.isPlaying)
  }
  
  func pausePlayer(result: @escaping RCTPromiseResolveBlock) {
    stopListening()
    player?.pause()
    timerUpdate()
    result(true)
  }
  
  func stopPlayer() {
    stopListening()
    player?.stop()
    timerUpdate()
    player = nil
    timer = nil
  }
  
  func getDuration(_ type: DurationType, _ result: @escaping RCTPromiseResolveBlock) {
    if type == .Current {
      let ms = (player?.currentTime ?? 0) * 1000
      result(Int(ms))
    } else {
      let ms = (player?.duration ?? 0) * 1000
      result(Int(ms))
    }
  }
  
  func setVolume(_ volume: Double?, _ result: @escaping RCTPromiseResolveBlock) {
    player?.volume = Float(volume ?? 1.0)
    result(true)
  }
  
  func seekTo(_ time: Double?, _ result: @escaping RCTPromiseResolveBlock) {
    if(time != 0 && time != nil) {
      player?.currentTime = Double(time! / 1000)
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
        if let player = player {
            player.enableRate = true
            player.rate = Float(speed)
            return true
        } else {
            return false
        }
    }
  
  func stopListening() {
    timer?.invalidate()
    timer = nil
  }
}
