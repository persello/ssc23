//
//  NoticeView.swift
//  Pulse
//
//  Created by Riccardo Persello on 02/04/23.
//

import SwiftUI

struct NoticeView: View {
    var imageSystemName: String
    var title: LocalizedStringKey
    var subtitle: LocalizedStringKey
    
    var body: some View {
        VStack {
            Image(systemName: imageSystemName)
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 200)
        }
    }
}

struct NoticeView_Previews: PreviewProvider {
    static var previews: some View {
        NoticeView(imageSystemName: "camera",
                   title: "Title",
                   subtitle: "Subtitle...")
    }
}
