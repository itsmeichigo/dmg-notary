//
//  Failure.swift
//
//
//  Created by Huong Do on 10/02/2024.
//  Copyright © 2024 Huong Do. All rights reserved.
//

import Foundation

struct Failure: LocalizedError {
    var errorDescription: String?
    
    init(_ description: String) {
        self.errorDescription = description
    }
}
