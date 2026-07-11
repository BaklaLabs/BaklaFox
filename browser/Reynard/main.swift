//
//  main.swift
//  BaklaFox
//

import Darwin
import Foundation
import GeckoView
import UIKit

// MARK: - Crash and startup diagnostics

private var crashLogFD: Int32 = -1
private var publicCrashLogFD: Int32 = -1

private let crashLogPath: String = {
    guard let caches = FileManager.default.urls(
        for: .cachesDirectory,
        in: .userDomainMask
    ).first else {
        return "/tmp/BaklaFox.crash.log"
    }
    return caches.appendingPathComponent("BaklaFox.crash.log").path
}()

private let publicCrashLogPath: String = {
    guard let documents = FileManager.default.urls(
        for: .documentDirectory,
        in: .userDomainMask
    ).first else {
        return crashLogPath
    }
    return documents.appendingPathComponent("BaklaFox.crash.log").path
}()

private func diagnosticPaths() -> [String] {
    crashLogPath == publicCrashLogPath
        ? [crashLogPath]
        : [crashLogPath, publicCrashLogPath]
}

private func replaceDiagnostics(with text: String) {
    for path in diagnosticPaths() {
        let url = URL(fileURLWithPath: path)
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }
}

private func appendDiagnostic(_ text: String) {
    guard let data = text.data(using: .utf8) else {
        return
    }

    for path in diagnosticPaths() {
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: nil)
        }
        guard let handle = FileHandle(forWritingAtPath: path) else {
            continue
        }
        handle.seekToEndOfFile()
        handle.write(data)
        handle.synchronizeFile()
        handle.closeFile()
    }
}

private func recordStartupMilestone(_ message: String) {
    appendDiagnostic("[BAKLAFOX] \(message)\n")
    NSLog("[BAKLAFOX] %@", message)
}

private func writeSignalMessage(_ message: StaticString) {
    message.withUTF8Buffer { buffer in
        guard let baseAddress = buffer.baseAddress else {
            return
        }
        if crashLogFD >= 0 {
            _ = write(crashLogFD, baseAddress, buffer.count)
        }
        if publicCrashLogFD >= 0 {
            _ = write(publicCrashLogFD, baseAddress, buffer.count)
        }
    }
}

private func setupCrashHandlers() {
    let environment = ProcessInfo.processInfo.environment
    let bootstrapMarker = environment["BAKLAFOX_LEGACY_BOOTSTRAP"] ?? "absent"

    let diagnostic = """
    [BAKLAFOX] Startup at \(Date())
    [BAKLAFOX] Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown")
    [BAKLAFOX] Build: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown")
    [BAKLAFOX] Executable: \(CommandLine.arguments.first ?? "unknown")
    [BAKLAFOX] Legacy bootstrap: \(bootstrapMarker)
    [BAKLAFOX] iOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
    [BAKLAFOX] Device: \(UIDevice.current.model)
    [BAKLAFOX] no-sandbox: \(getEntitlementValue("com.apple.private.security.no-sandbox"))

    """
    replaceDiagnostics(with: diagnostic)

    crashLogFD = open(crashLogPath, O_WRONLY | O_CREAT | O_APPEND, 0644)
    if publicCrashLogPath != crashLogPath {
        publicCrashLogFD = open(
            publicCrashLogPath,
            O_WRONLY | O_CREAT | O_APPEND,
            0644
        )
    }

    NSSetUncaughtExceptionHandler { exception in
        let info = """

        [BAKLAFOX_CRASH] Uncaught exception: \(exception.name.rawValue)
        [BAKLAFOX_CRASH] Reason: \(exception.reason ?? "none")
        [BAKLAFOX_CRASH] Stack:
        \(exception.callStackSymbols.joined(separator: "\n"))

        """
        appendDiagnostic(info)
    }

    let handler: @convention(c) (Int32) -> Void = { signalNumber in
        switch signalNumber {
        case SIGABRT:
            writeSignalMessage("[BAKLAFOX_CRASH] Signal SIGABRT\n")
        case SIGSEGV:
            writeSignalMessage("[BAKLAFOX_CRASH] Signal SIGSEGV\n")
        case SIGBUS:
            writeSignalMessage("[BAKLAFOX_CRASH] Signal SIGBUS\n")
        case SIGILL:
            writeSignalMessage("[BAKLAFOX_CRASH] Signal SIGILL\n")
        case SIGFPE:
            writeSignalMessage("[BAKLAFOX_CRASH] Signal SIGFPE\n")
        default:
            writeSignalMessage("[BAKLAFOX_CRASH] Unknown fatal signal\n")
        }

        // Do not return into a corrupted instruction or abort path. Restore the
        // default action and re-deliver the signal so iOS still creates a normal
        // crash report after our marker is flushed.
        Darwin.signal(signalNumber, SIG_DFL)
        _ = kill(getpid(), signalNumber)
    }

    Darwin.signal(SIGABRT, handler)
    Darwin.signal(SIGSEGV, handler)
    Darwin.signal(SIGBUS, handler)
    Darwin.signal(SIGILL, handler)
    Darwin.signal(SIGFPE, handler)
}

// MARK: - Main entry point

setupCrashHandlers()
recordStartupMilestone("Crash handlers installed")

LegacyIOSCompatibility.prepareBeforeGecko(log: recordStartupMilestone)
recordStartupMilestone("Legacy compatibility preparation completed")

// This only registers child-process observers. Actual JIT attachment happens
// after Gecko reports a child PID, so no debugger/helper process is launched
// during the fragile main-process bootstrap window.
JITController.shared.start()
recordStartupMilestone("JIT controller observers installed")

recordStartupMilestone("GeckoRuntime.main starting")
GeckoRuntime.main(argc: CommandLine.argc, argv: CommandLine.unsafeArgv)
recordStartupMilestone("GeckoRuntime.main returned unexpectedly")
