//
//  Item.swift
//  DJMediWallet25
//
//  Created by Nick Vermeulen on 14/11/2025.
//

import Foundation
import SwiftData

@Model
final class OLDItem {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
