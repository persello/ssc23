//
//  CardModifier.swift
//  Pulse
//
//  Created by Riccardo Persello on 02/04/23.
//

import Foundation
import SwiftUI

struct CardModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    var aspectRatio: Double
    var title: String
    func body(content: Content) -> some View {
        ZStack(alignment: .topLeading) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .padding(.leading, 16)
                .padding(.top, 16)
                .zIndex(100)
            
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .background(.black.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

extension View {
    func cardStyle(aspectRatio: Double = 1, title: String = "") -> some View {
        modifier(CardModifier(aspectRatio: aspectRatio, title: title))
    }
}
