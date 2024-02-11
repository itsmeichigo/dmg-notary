//
//  AuthenticationMethod.swift
//  
//
//  Created by Huong Do on 11/02/2024.
//  Copyright © 2024 Huong Do. All rights reserved.
//

import Foundation

enum AuthenticationMethod {
    case credentials(teamID: String, appleID: String, password: String?)
    case keychainProfile(name: String)
}

extension AuthenticationMethod {
    var argumentsForNotary: [String] {
        switch self {
        case .keychainProfile(let name):
            return ["--keychain-profile \"\(name)\""]

        case let .credentials(teamID, appleID, password):
            let passwordArg: String? = {
                guard let password else {
                    return nil
                }
                return "--password \"\(password)\""
            }()
            return [
                "--apple-id \"\(appleID)\"",
                "--team-id \"\(teamID)\"",
                passwordArg
            ].compactMap { $0 }
        }
    }
}
