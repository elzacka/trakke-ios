import AVFoundation
import os
import OSLog

/// Manages the SOS Morse code signal using the device torch and optional audio.
/// Morse SOS pattern: ··· – – – ··· (dot=1 unit, dash=3 units, inter-element gap=1 unit,
/// inter-letter gap=3 units, inter-word gap=7 units). Unit = 250 ms.
///
/// Lydmotoren kjører ALLTID mens signalet er aktivt – også når «Lydsignal» er av
/// (da rendres stillhet). Den aktive audio-sesjonen er det som holder appen
/// kjørende i bakgrunnen (UIBackgroundModes: audio), slik at lykte-løkka
/// fortsetter når skjermen låses. Uten motoren suspenderes prosessen og
/// blinkingen fryser.
actor SOSService {
    private let unitDuration: UInt64 = 250_000_000 // 250 ms in nanoseconds
    private let toneFrequency: Float = 2800 // Hz
    private var isRunning = false
    private var loopTask: Task<Void, Never>?
    private var audioEngine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private var interruptionObserver: NSObjectProtocol?
    /// Generasjonsteller: opprydding fra en avløst løkke (kansellert sleep,
    /// forsinket stop) må aldri røre en nyere løkkes lykt/lyd.
    private var generation = 0
    /// Thread-safe flag for the audio render block (called from audio thread)
    private let toneActive = OSAllocatedUnfairLock(initialState: false)

    /// The SOS pattern as durations: positive = on, negative = off (in units)
    /// S = ·  ·  ·   O = –  –  –   S = ·  ·  ·
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

    func start(withAudio: Bool) {
        generation += 1
        let gen = generation
        loopTask?.cancel()
        isRunning = true

        startAudio()

        loopTask = Task { await self.runSignalLoop(withAudio: withAudio, generation: gen) }
    }

    func stop() {
        generation += 1
        isRunning = false
        loopTask?.cancel()
        loopTask = nil
        setTorch(on: false)
        stopAudio()
    }

    // MARK: - Signal Loop

    private func runSignalLoop(withAudio: Bool, generation gen: Int) async {
        while isRunning && gen == generation {
            for element in Self.sosPattern {
                guard isRunning, gen == generation else { break }
                let isOn = element > 0
                let units = abs(element)
                setTorch(on: isOn)
                setAudioTone(on: isOn && withAudio)

                do {
                    try await Task.sleep(nanoseconds: unitDuration * UInt64(units))
                } catch {
                    // Kansellert. Rydd bare opp hvis denne løkka fortsatt er
                    // gjeldende – en avløst løkke må ikke slukke en nyere.
                    if gen == generation {
                        setTorch(on: false)
                        setAudioTone(on: false)
                    }
                    return
                }
            }
        }
    }

    // MARK: - Torch

    /// Logger første feilende skriving (og første vellykkede etterpå) slik at
    /// «lykta sluknet med låst skjerm» kan skilles fra prosess-suspensjon i
    /// Console-logger fra enhet.
    private var torchWriteFailed = false

    private func setTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if on {
                try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
            } else {
                device.torchMode = .off
            }
            if torchWriteFailed {
                torchWriteFailed = false
                Logger.sos.info("Torch writes recovered")
            }
        } catch {
            // Fortsetter med bare lyd – men logg tilstandsskiftet.
            if !torchWriteFailed {
                torchWriteFailed = true
                Logger.sos.error("Torch write failed: \(error.localizedDescription, privacy: .private)")
            }
        }
    }

    nonisolated var hasTorch: Bool {
        AVCaptureDevice.default(for: .video)?.hasTorch ?? false
    }

    // MARK: - Audio

    private func startAudio() {
        tearDownEngine()

        // Configure audio session BEFORE creating the engine.
        // On real devices, the output node format depends on the active session.
        // IKKE .mixWithOthers: som primær avspillingsapp har prosessen den
        // sterkeste garantien for å fortsette i bakgrunnen med låst skjerm –
        // det er dét som holder lykteløkka i live. At annen lyd avbrytes
        // under et aktivt nødsignal er riktig prioritering.
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            Logger.sos.error("Failed to configure audio session: \(error.localizedDescription, privacy: .private)")
            return
        }

        observeInterruptions()
        buildAndStartEngine()
    }

    private func buildAndStartEngine() {
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

    /// En telefonsamtale (typisk 113 fra SOS-arket) avbryter audio-sesjonen og
    /// stopper motoren. Uten gjenoppbygging etter avbruddet forsvinner både
    /// tonen og bakgrunns-keep-alive for lykta.
    private func observeInterruptions() {
        guard interruptionObserver == nil else { return }
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: nil
        ) { [weak self] notification in
            guard let info = notification.userInfo,
                  let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .ended else { return }
            Task { await self?.handleInterruptionEnded() }
        }
    }

    private func handleInterruptionEnded() {
        guard isRunning else { return }
        tearDownEngine()
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            Logger.sos.error("Failed to reactivate audio session: \(error.localizedDescription, privacy: .private)")
            return
        }
        buildAndStartEngine()
    }

    private func setAudioTone(on: Bool) {
        toneActive.withLock { $0 = on }
    }

    private func tearDownEngine() {
        audioEngine?.stop()
        audioEngine = nil
        sourceNode = nil
    }

    private func stopAudio() {
        toneActive.withLock { $0 = false }
        tearDownEngine()
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
            interruptionObserver = nil
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
