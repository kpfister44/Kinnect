//
//  Notification+Extensions.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/27/25.
//

import Foundation

extension Notification.Name {
    /// Posted when user logs out - used to clear caches
    static let userDidLogout = Notification.Name("userDidLogout")
}
