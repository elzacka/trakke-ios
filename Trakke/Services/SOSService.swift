import AVFoundation
import os
import OSLog

/// Manages the SOS Morse code signal using the device torch and optional audio.
/// Morse SOS pattern: ··· — — — ··· (dot=1 unit, dash=3 units, inter-element gap=1 unit,
/// inter-letter gap=3 units, inter-word gap=7 units). Unit = 250 ms.
actor SOSService {
    private let unitDuration: UInt64 = 250_000_000 // 250 ms in nanoseconds
    private let toneFrequency: Float = 2800 // Hz
    private var isRunning = false
    private var audioEngine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    /// Thread-safe flag for the audio render block (called from audio thread)
    private let toneActive = OSAllocatedUnfairLock(initialState: false)

    /// The SOS pattern as durations: positive = on, negative = off (in units)
    /// S = ·  ·  ·   O = —  —  —   S = ·  ·  ·
    static let sosPattern: [Int] = [
        // S: dot gap dot gap dot
        1, -1, 1, -1, 1,
        // inter-letter gap
        -3,
        // O: dash gap dash gap dash
        3, -1, 3, -1, 3,
        // inter-letter gap
        -3,
        // S: dot gap dot gap dot
        1, -1, 1, -1, 1,
        // inter-word gap (before repeating)
        -7
    ]

    func start(withAudio: Bool) async {
        guard !isRunning else { return }
        isRunning = true

        if withAudio {
            startAudio()
        }

        await runSignalLoop(withAudio: withAudio)
    }

    func stop() {
        isRunning = false
        setTorch(on: false)
        stopAudio()
    }

    // MARK: - Signal Loop

    private func runSignalLoop(withAudio: Bool) async {
        while isRunning {
            for element in Self.sosPattern {
                guard isRunning else { break }
                let isOn = element > 0
                let units = abs(element)
                setTorch(on: isOn)
                if withAudio { setAudioTone(on: isOn) }

                do {
                    try await Task.sleep(nanoseconds: unitDuration * UInt64(units))
                } catch {
                    // Task cancelled
                    stop()
                    return
                }
            }
        }
    }

    // MARK: - Torch

    private func setTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            device.torchMode = on ? .on : .off
        } catch {
            // Torch unavailable -- silently continue with audio only
        }
    }

    nonisolated var hasTorch: Bool {
        AVCaptureDevice.default(for: .video)?.hasTorch ?? false
    }

    // MARK: - Audio

    private func startAudio() {
        // Configure audio session BEFORE creating the engine.
        // On real devices, the output node format depends on the active session.
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            Logger.sos.error("Failed to configure audio session: \(error.localizedDescription, privacy: .private)")
            return
        }

        let engine = AVAudioEngine()

        // Use an explicit format rather than relying on the output node, which can
        // return a zero-sample-rate format on real devices if the session isn't ready.
        let sampleRate: Double = 44100
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            return
        }

        var phase: Float = 0
        let phaseIncrement = (2.0 * Float.pi * toneFrequency) / Float(sampleRate)
        let toneFlag = toneActive

        let source = AVAudioSourceNode(format: format) { _, _, frameCount, bufferList -> OSStatus in
            let buffer = UnsafeMutableAudioBufferListPointer(bufferList)
            let isOn = toneFlag.withLock { $0 }
            for frame in 0..<Int(frameCount) {
                let sample: Float
                if isOn {
                    sample = sin(phase) * 0.3
                    phase += phaseIncrement
                    if phase >= 2.0 * Float.pi { phase -= 2.0 * Float.pi }
                } else {
                    sample = 0
                }
                for channel in 0..<buffer.count {
                    buffer[channel].mData?.assumingMemoryBound(to: Float.self)[frame] = sample
                }
            }
            return noErr
        }

        self.sourceNode = source

        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: format)

        do {
            try engine.start()
        } catch {
            Logger.sos.error("Failed to start audio engine: \(error.localizedDescription, privacy: .private)")
        }

        self.audioEngine = engine
    }

    private func setAudioTone(on: Bool) {
        toneActive.withLock { $0 = on }
    }

    private func stopAudio() {
        toneActive.withLock { $0 = false }
        audioEngine?.stop()
        audioEngine = nil
        sourceNode = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
