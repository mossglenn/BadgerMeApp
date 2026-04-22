//
//  SpeechService.swift
//  BadgerMe
//
//  Created by Amos Glenn on 4/21/26.
//

import AVFoundation
import Foundation

/// Pre-renders speech text to .caf audio files that can be used as
/// notification sounds. Files are saved to Library/Sounds so
/// UNNotificationSound can locate them.
final class SpeechService {

    static let shared = SpeechService()

    private let synthesizer = AVSpeechSynthesizer()
    private let fileManager = FileManager.default

    /// Directory where rendered speech files are stored.
    /// UNNotificationSound looks in Library/Sounds for custom sounds.
    private var soundsDirectory: URL {
        let library = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first!
        return library.appendingPathComponent("Sounds", isDirectory: true)
    }

    private init() {
        ensureSoundsDirectory()
    }

    // MARK: - Public API

    /// Pre-renders speech for a Badger's title and returns the filename
    /// to use as a UNNotificationSoundName. Returns nil on failure.
    func prerenderSpeech(text: String, badgerId: UUID) async -> String? {
        let filename = "speech-\(badgerId.uuidString).caf"
        let fileURL = soundsDirectory.appendingPathComponent(filename)

        // Skip if already rendered
        if fileManager.fileExists(atPath: fileURL.path) {
            return filename
        }

        do {
            let buffers = try await renderToBuffers(text: text)
            guard !buffers.isEmpty else { return nil }
            try writeCAFFile(buffers: buffers, to: fileURL)
            return filename
        } catch {
            print("Speech pre-render failed: \(error)")
            return nil
        }
    }

    /// Removes the pre-rendered speech file for a Badger.
    func removeSpeechFile(for badgerId: UUID) {
        let filename = "speech-\(badgerId.uuidString).caf"
        let fileURL = soundsDirectory.appendingPathComponent(filename)
        try? fileManager.removeItem(at: fileURL)
    }

    /// Removes all pre-rendered speech files.
    func removeAllSpeechFiles() {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: soundsDirectory,
            includingPropertiesForKeys: nil
        ) else { return }

        for url in contents where url.lastPathComponent.hasPrefix("speech-") {
            try? fileManager.removeItem(at: url)
        }
    }

    // MARK: - Offline Rendering

    /// Uses AVSpeechSynthesizer.write(_:toBufferCallback:) to capture
    /// audio buffers without playing them through the speaker.
    private func renderToBuffers(text: String) async throws -> [AVAudioPCMBuffer] {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.45
        utterance.volume = 1.0

        return try await withCheckedThrowingContinuation { continuation in
            var collectedBuffers: [AVAudioPCMBuffer] = []
            var hasResumed = false

            synthesizer.write(utterance) { buffer in
                guard let pcmBuffer = buffer as? AVAudioPCMBuffer else { return }

                if pcmBuffer.frameLength > 0 {
                    collectedBuffers.append(pcmBuffer)
                } else {
                    // Empty buffer signals completion
                    guard !hasResumed else { return }
                    hasResumed = true
                    continuation.resume(returning: collectedBuffers)
                }
            }
        }
    }

    // MARK: - CAF File Writing

    /// Concatenates PCM buffers and writes them to a .caf file using AVAudioFile.
    private func writeCAFFile(buffers: [AVAudioPCMBuffer], to url: URL) throws {
        guard let firstBuffer = buffers.first else { return }

        let format = firstBuffer.format
        let audioFile = try AVAudioFile(
            forWriting: url,
            settings: format.settings,
            commonFormat: format.commonFormat,
            interleaved: format.isInterleaved
        )

        for buffer in buffers {
            try audioFile.write(from: buffer)
        }
    }

    // MARK: - Private

    private func ensureSoundsDirectory() {
        if !fileManager.fileExists(atPath: soundsDirectory.path) {
            try? fileManager.createDirectory(
                at: soundsDirectory,
                withIntermediateDirectories: true
            )
        }
    }
}
