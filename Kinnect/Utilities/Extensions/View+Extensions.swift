//
//  View+Extensions.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/17/25.
//

import SwiftUI

extension View {
    /// Hides keyboard when tapped outside
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    /// Applies a conditional modifier
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
