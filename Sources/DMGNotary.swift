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

var bundleID: String!

@main
struct DMGNotary: ParsableCommand {

    private static let maxOutputDMGFilenameLength = 27

    public static let configuration = CommandConfiguration(abstract: "Create a DMG and notarize it for distribution.")

    @Argument(help: "Path to the developer ID signed .app (doesn't have to be notarized)")
    var appFilePath: String
    
    @Argument(help: "Your code signing identity, such as \"Developer ID Application: John Doe (XXXX123YY)\"")
    var identity: String
    
    @Argument(help: "Your App Store Connect provider ID (same as your developer's team ID)")
    var ascProvider: String
    
    @Argument(help: "Your App Store Connect e-mail")
    var ascEmail: String
    
    @Argument(help: "Your App Store Connect app-specific password, or the identifier for a keychain item in the format @keychain:ITEMNAME")
    var ascPassword: String

    @Option(name: .long, help: "Custom name for the output DMG file (max \(Self.maxOutputDMGFilenameLength) characters)")
    var dmgName: String?

    @Flag(help: "Verbose output")
    var verbose = false
    
    public func run() throws {
        
    }
}

private extension DMGNotary {
    /// Uses `create-dmg` to prepare a temporary DMG with the app, returns the URL of the DMG.
    func prepareDMG() throws -> URL {
        let appFileURL = URL(fileURLWithPath: appFilePath)

        let appName = appFileURL.deletingPathExtension().lastPathComponent
        let sanitizedAppName = appName.replacingOccurrences(of: " ", with: "")

        if appName.contains(" ") {
            fputs("WARNING: The app file name contains spaces, they will be removed in the output file.\n", stderr)
        }

        guard FileManager.default.fileExists(atPath: appFileURL.path) else {
            throw Failure("The input app doesn't exist at \(appFileURL.path)")
        }

        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("DMGNotary-" + sanitizedAppName + "-\(Date().timeIntervalSince1970)")

        if !FileManager.default.fileExists(atPath: tempDir.path) {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        }

        guard let appBundle = Bundle(url: appFileURL) else {
            throw Failure("Failed to construct app bundle")
        }

        guard let shortVersionString = appBundle.infoDictionary?["CFBundleShortVersionString"] as? String else {
            throw Failure("Failed to read CFBundleShortVersionString from app's Info.plist")
        }

        guard let bundleVersion = appBundle.infoDictionary?["CFBundleVersion"] as? String else {
            throw Failure("Failed to read CFBundleVersion from app's Info.plist")
        }

        guard let identifier = appBundle.bundleIdentifier else {
            throw Failure("Couldn't get app bundle identifier")
        }

        bundleID = identifier
        
        let outputDMGName = dmgName ?? "\(sanitizedAppName)_v\(shortVersionString)-\(bundleVersion)"

        guard outputDMGName.count < Self.maxOutputDMGFilenameLength else {
            throw Failure("The output DMG file name \"\(outputDMGName)\" exceeds the maximum character limit of \(Self.maxOutputDMGFilenameLength).\nPlease specify a shorter custom name with the --dmg-name option.")
        }
        
        if verbose {
            print("Primary bundle ID is \(identifier)")
            print("Output DMG will be named \(outputDMGName)")
            print("Using temporary directory \(tempDir.path)")
        }

        try shellOut(to: "create-dmg", arguments: ["--identity=\"\(identity)\"", "--overwrite", "--dmg-title=\"\(outputDMGName)\"", "\"\(appFilePath)\"", tempDir.path])

        if verbose {
            print("Renaming output DMG")
        }

        guard let enumerator = FileManager.default.enumerator(at: tempDir, includingPropertiesForKeys: nil) else {
            throw Failure("Failed to read output directory")
        }

        guard let originalDMGURL = enumerator.allObjects.compactMap({ $0 as? URL }).first(where: { $0.pathExtension.lowercased() == "dmg" }) else {
            throw Failure("Couldn't find output DMG in temporary directory")
        }

        let outputDMGURL = tempDir
            .appendingPathComponent(outputDMGName)
            .appendingPathExtension("dmg")

        try FileManager.default.moveItem(at: originalDMGURL, to: outputDMGURL)

        return outputDMGURL
    }
}
