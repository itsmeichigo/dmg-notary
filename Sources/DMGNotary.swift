//
//  DMGNotary.swift
//
//
//  Created by Huong Do on 10/02/2024.
//  Copyright © 2024 Huong Do. All rights reserved.
//

import Foundation
import ArgumentParser
import ShellOut

@main
struct DMGNotary: ParsableCommand {

    private static let maxOutputDMGFilenameLength = 27

    public static let configuration = CommandConfiguration(abstract: "Create a DMG and notarize it for distribution.")

    @Argument(help: "Path to the developer ID signed .app (doesn't have to be notarized)")
    var appFilePath: String
    
    @Option(name: .long, help: "Your code signing identity, such as \"Developer ID Application: John Doe (XXXX123YY)\". If not specified, create-dmg will attempt to pick one from your Keychain.")
    var identity: String?

    @Option(name: .long, help: "Custom name for the output DMG file (max \(Self.maxOutputDMGFilenameLength) characters)")
    var dmgName: String?

    @Option(name: .long, help: "Your App Store Connect provider ID (same as your developer's team ID)")
    var teamId: String?
    
    @Option(name: .long, help: "Your Developer ID (App Store Connect e-mail)")
    var appleId: String?
    
    @Option(help: "App-specific password for your Apple ID. You will begiven a secure prompt on the command line if Apple ID and Team ID are provided and '--password' option is not specified.")
    var password: String?

    @Option(help: "Authenticate with credentials stored in the Keychain for notarytool.")
    var keychainProfile: String?

    @Flag(help: "Verbose output")
    var verbose = false
    
    public func run() throws {
        let authenticationMethod: AuthenticationMethod = try {
            if let keychainProfile {
                return .keychainProfile(name: keychainProfile)
            } else if let teamId, let appleId {
                return .credentials(teamID: teamId, appleID: appleId, password: password)
            }
            throw Failure("⛔️ Please specify either --keychain-profile or credentials for notarytool.")
        }()

        let tempFileURL = try prepareDMG()
        let response = try submitDMGForNotary(for: tempFileURL, with: authenticationMethod)

        let finalDir = URL(fileURLWithPath: appFilePath).deletingLastPathComponent()
        try saveNotaryLog(requestID: response.id, to: finalDir, with: authenticationMethod)

        if response.status == .accepted {
            let finalURL = try moveFile(tempFileURL, to: finalDir)
            try stapleTicket(for: finalURL)
        }

        try cleanupTempFiles(at: tempFileURL.deletingLastPathComponent())
        print(response.status.finalMessage)
        try shellOut(to: "open", arguments: [finalDir.path])
    }
}

private extension DMGNotary {
    /// Uses `create-dmg` to prepare a temporary DMG with the app, returns the URL of the DMG.
    func prepareDMG() throws -> URL {
        let appFileURL = URL(fileURLWithPath: appFilePath)

        let appName = appFileURL.deletingPathExtension().lastPathComponent
        let sanitizedAppName = appName.replacingOccurrences(of: " ", with: "")

        if appName.contains(" ") {
            fputs("⚠️ The app file name contains spaces, they will be removed in the output file.\n", stderr)
        }

        guard FileManager.default.fileExists(atPath: appFileURL.path) else {
            throw Failure("⛔️ The input app doesn't exist at \(appFileURL.path)")
        }

        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("DMGNotary-" + sanitizedAppName + "-\(Date().timeIntervalSince1970)")

        if !FileManager.default.fileExists(atPath: tempDir.path) {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        }

        guard let appBundle = Bundle(url: appFileURL) else {
            throw Failure("⛔️ Failed to construct app bundle")
        }

        guard let shortVersionString = appBundle.infoDictionary?["CFBundleShortVersionString"] as? String else {
            throw Failure("⛔️ Failed to read CFBundleShortVersionString from app's Info.plist")
        }

        guard let bundleVersion = appBundle.infoDictionary?["CFBundleVersion"] as? String else {
            throw Failure("⛔️ Failed to read CFBundleVersion from app's Info.plist")
        }
        
        let outputDMGName = dmgName ?? "\(sanitizedAppName)_v\(shortVersionString)-\(bundleVersion)"

        guard outputDMGName.count < Self.maxOutputDMGFilenameLength else {
            throw Failure("⛔️ The output DMG file name \"\(outputDMGName)\" exceeds the maximum character limit of \(Self.maxOutputDMGFilenameLength).\nPlease specify a shorter custom name with the --dmg-name option.")
        }
        
        if verbose {
            print("✏️ Output DMG will be named \(outputDMGName)")
            print("📁 Using temporary directory \(tempDir.path)")
        }

        let arguments: [String] = {
            var args = [
                "--overwrite",
                "--dmg-title=\"\(outputDMGName)\"",
                "\"\(appFilePath)\"",
                tempDir.path
            ]
            if let identity {
                args.append("--identity=\"\(identity)\"")
            }
            return args
        }()
        try shellOut(to: "create-dmg", arguments: arguments)

        guard let enumerator = FileManager.default.enumerator(at: tempDir, includingPropertiesForKeys: nil) else {
            throw Failure("⛔️ Failed to read output directory")
        }

        guard let originalDMGURL = enumerator.allObjects.compactMap({ $0 as? URL }).first(where: { $0.pathExtension.lowercased() == "dmg" }) else {
            throw Failure("⛔️ Couldn't find output DMG in temporary directory")
        }

        let outputDMGURL = tempDir
            .appendingPathComponent(outputDMGName)
            .appendingPathExtension("dmg")

        try FileManager.default.moveItem(at: originalDMGURL, to: outputDMGURL)

        return outputDMGURL
    }

    /// Submits the DMG with notarytool and returns the output.
    func submitDMGForNotary(for fileURL: URL, with authenticationMethod: AuthenticationMethod) throws -> SubmissionResponse {
        if verbose {
            print("📤 Submitting DMG for notarization...")
        }

        let arguments = authenticationMethod.argumentsForNotary + [
            "\(fileURL.path)",
            "--output-format \"json\"",
            "--wait"
        ]

        let output = try shellOut(to: "xcrun notarytool submit", arguments: arguments)
        guard let data = output.data(using: .utf8) else {
            throw Failure("☠️ Failed to parse response from notarytool.")
        }
        let jsonDecoder = JSONDecoder()
        return try jsonDecoder.decode(SubmissionResponse.self, from: data)
    }

    /// Saves the log for the notarization submission given the request ID.
    func saveNotaryLog(requestID: String, 
                       to directory: URL,
                       with authenticationMethod: AuthenticationMethod) throws {
        if verbose {
            print("📜 Saving notary log...")
        }

        let logFileURL = directory
            .appendingPathComponent("notary-logs")
            .appendingPathExtension("json")
        let arguments = authenticationMethod.argumentsForNotary + [
            requestID,
            "--output-format \"json\"",
            logFileURL.path
        ]
        try shellOut(to: "xcrun notarytool log", arguments: arguments)

        if verbose {
            print("✅ Notary log saved at \(logFileURL.path).")
        }
    }

    /// Moves the DMG to the final directory and returns the final file URL.
    func moveFile(_ fileURL: URL, to finalDir: URL) throws -> URL {
        let appFileURL = URL(fileURLWithPath: appFilePath)
        let finalDir = appFileURL.deletingLastPathComponent()
        let finalURL = finalDir.appendingPathComponent(fileURL.lastPathComponent)

        /// Overwrites any existing file
        if FileManager.default.fileExists(atPath: finalURL.path) {
            try FileManager.default.removeItem(at: finalURL)
        }
        try FileManager.default.moveItem(at: fileURL, to: finalURL)
        return finalURL
    }

    /// Staples the DMG at the specified URL.
    func stapleTicket(for fileURL: URL) throws {
        if verbose {
            print("📎 Stapling the DMG...")
        }

        try shellOut(to: "xcrun stapler staple", arguments: [fileURL.path])
    }

    func cleanupTempFiles(at url: URL) throws {
        if verbose {
            print("🧹 Cleaning up temporary files...")
        }
        try FileManager.default.removeItem(at: url)
    }
}
