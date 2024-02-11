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
}
