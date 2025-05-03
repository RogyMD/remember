import AVFoundation

final class AudioVolumeObserver {
  private var volumeObservation: NSKeyValueObservation?

  func startObserving(_ handler: @escaping @Sendable () -> Void) {
    try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
    try? AVAudioSession.sharedInstance().setActive(true)

    volumeObservation = AVAudioSession.sharedInstance().observe(\.outputVolume, options: [.old, .new]) { _, change in
      guard let old = change.oldValue, let new = change.newValue, new != old else { return }
      handler()
    }
  }

  func stopObserving() {
    try? AVAudioSession.sharedInstance().setActive(false)
    volumeObservation?.invalidate()
    volumeObservation = nil
  }
}
