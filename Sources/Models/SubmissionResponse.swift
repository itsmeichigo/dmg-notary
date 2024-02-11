//
//  SubmissionResponse.swift
//  
//  Created by Huong Do on 11/02/2024.
//  Copyright © 2024 Huong Do. All rights reserved.
//

import Foundation

struct SubmissionResponse: Decodable {
    let id: String
    let status: SubmissionStatus
    let message: String
}

enum SubmissionStatus: String, Decodable {
    case accepted = "Accepted"
    case inProgress = "In Progress"
    case invalid = "Invalid"
    case rejected = "Rejected"

    var finalMessage: String {
        switch self {
        case .accepted:
            "🎉 Your DMG is notarized and stapled!"
        case .rejected:
            "❌ Notarization failed. Please check the saved log for more information."
        case .invalid:
            "❌ Invalid notarization request. Please try again."
        case .inProgress:
            "⏳ Notarization in progress. Please check the saved log for more information."
        }
    }
}
