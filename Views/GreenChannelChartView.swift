//
//  GreenChannelChartView.swift
//  Pulse
//
//  Created by Riccardo Persello on 02/04/23.
//

import SwiftUI
import Charts

struct GreenChannelChartView: View {
    @EnvironmentObject var model: CameraViewModel
    
    var body: some View {
        VStack {
            if model.greenChannelHistory.isEmpty {
                Spacer()
                NoticeView(imageSystemName: "chart.xyaxis.line",
                           title: "No data",
                           subtitle: "")
                Spacer()
            } else {
                Chart {
                    ForEach(model.greenChannelHistory.suffix(120),
                            id: \.date) { point in
                        LineMark(
                            x: .value("Time", point.date),
                            y: .value("Value", point.green)
                        )
                        .foregroundStyle(.green)
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .chartYAxis {
                    AxisMarks(preset: .inset, position: .trailing, values: .automatic)
                }
            }
        }
        .cardStyle()
        .blockSize(width: 3, height: 1)
    }
}

struct GreenChannelChartView_Previews: PreviewProvider {
    static var previews: some View {
        let model = FakeCameraViewModel()
        model.camera.start()
        
        return GreenChannelChartView()
            .environmentObject(model as CameraViewModel)
    }
}
