//
//  AccuracyView.swift
//  Pulse
//
//  Created by Riccardo Persello on 12/04/23.
//

import SwiftUI

struct AccuracyView: View {
    @EnvironmentObject var model: CameraViewModel
    
    var statusString: String {
        switch model.accuracyStatus?.kind {
        case .none:
            return "Unknown"
        case .some(let kind):
            switch kind {
            case .insufficient:
                return "Poor"
            case .low:
                return "Low"
            case .good:
                return "Good"
            case .excellent:
                return "Excellent"
            }
        }
    }
    
    var statusColor: Color {
        switch model.accuracyStatus?.kind {
        case .none:
            return .gray
        case .some(let kind):
            switch kind {
            case .insufficient:
                return .red
            case .low:
                return .yellow
            case .good:
                return .green
            case .excellent:
                return .blue
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top) {
                Spacer()
                Image(systemName: "target")
                    .font(.largeTitle)
                    .foregroundStyle(statusColor.gradient)
            }
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(statusString)
                    .font(.title)
                    .foregroundStyle(statusColor.gradient)
                
                if let value = model.accuracyStatus?.value {
                    Text("(\(value, specifier: "%.2f"))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .cardStyle(title: "Stability")
    }
}


struct AccuracyView_Previews: PreviewProvider {
    static var previews: some View {
        AccuracyView()
            .environmentObject(FakeCameraViewModel() as CameraViewModel)
    }
}
