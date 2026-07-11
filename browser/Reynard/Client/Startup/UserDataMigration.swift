//
//  UserDataMigration.swift
//  BaklaFox
//
//  Created by Minh Ton on 17/5/26.
//

import Foundation

final class UserDataMigration {
    static let shared = UserDataMigration()

    private let fileManager: FileManager
    private let documentsDirectoryURL: URL
    private let applicationSupportDirectoryURL: URL
    private let isAvailable: Bool

    private var documentsAppDataDirectoryURL: URL {
        documentsDirectoryURL.appendingPathComponent("AppData", isDirectory: true)
    }

    private var documentsDDIDirectoryURL: URL {
        documentsDirectoryURL.appendingPathComponent("DDI", isDirectory: true)
    }

    private var applicationSupportAppDataDirectoryURL: URL {
        applicationSupportDirectoryURL.appendingPathComponent("AppData", isDirectory: true)
    }

    private var applicationSupportDDIDirectoryURL: URL {
        applicationSupportDirectoryURL.appendingPathComponent("DDI", isDirectory: true)
    }

    private init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        // Non-fatal fallback: if directories are unavailable, log and disable migrations.
        // This prevents the app from crashing at startup on jailbroken/tweaked devices
        // where container paths may behave unexpectedly.
        var available = true

        if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            self.documentsDirectoryURL = documentsURL
        } else {
            NSLog("[BAKLAFOX] Documents directory is unavailable — disabling migrations")
            self.documentsDirectoryURL = URL(fileURLWithPath: "/tmp")
            available = false
        }

        if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            self.applicationSupportDirectoryURL = appSupportURL
        } else {
            NSLog("[BAKLAFOX] Application Support directory is unavailable — disabling migrations")
            self.applicationSupportDirectoryURL = URL(fileURLWithPath: "/tmp")
            available = false
        }

        self.isAvailable = available
    }

    func run() {
        guard isAvailable else {
            NSLog("[BAKLAFOX] UserDataMigration skipped — directories unavailable")
            return
        }
        migrateAppDataToApplicationSupport()
        migrateDDIToApplicationSupport()
        removeLegacyUserAgentOverride()
    }

    // MARK: - Store Migration (0.4.0)
    private func migrateAppDataToApplicationSupport() {
        let sourceURL = documentsAppDataDirectoryURL
        let destinationURL = applicationSupportAppDataDirectoryURL

        guard fileManager.fileExists(atPath: sourceURL.path) else {
            return
        }

        do {
            try removeLegacyStoreFolders(in: sourceURL)
            try fileManager.createDirectory(at: applicationSupportDirectoryURL, withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
        } catch {
            NSLog("[BAKLAFOX] AppData migration failed: \(error.localizedDescription) — continuing without migration")
            return
        }

        if fileManager.fileExists(atPath: sourceURL.path) {
            NSLog("[BAKLAFOX] AppData migration verification failed — source still exists, continuing")
        }
    }

    private func migrateDDIToApplicationSupport() {
        let sourceURL = documentsDDIDirectoryURL
        let destinationURL = applicationSupportDDIDirectoryURL

        guard fileManager.fileExists(atPath: sourceURL.path) else {
            return
        }

        do {
            try fileManager.createDirectory(at: applicationSupportDirectoryURL, withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
        } catch {
            NSLog("[BAKLAFOX] DDI migration failed: \(error.localizedDescription) — continuing without migration")
            return
        }

        if fileManager.fileExists(atPath: sourceURL.path) {
            NSLog("[BAKLAFOX] DDI migration verification failed — source still exists, continuing")
        }
    }

    private func removeLegacyUserAgentOverride() {
        try? fileManager.removeItem(
            at: documentsDirectoryURL.appendingPathComponent("ua-override.json", isDirectory: false)
        )
    }

    private func removeLegacyStoreFolders(in appDataDirectoryURL: URL) throws {
        for folderName in ["TabManagement", "Favicons"] {
            let folderURL = appDataDirectoryURL.appendingPathComponent(folderName, isDirectory: true)
            if fileManager.fileExists(atPath: folderURL.path) {
                try fileManager.removeItem(at: folderURL)
            }
        }
    }
}
