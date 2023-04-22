//
//  FrequencyDomainChartView.swift
//  Pulse
//
//  Created by Riccardo Persello on 02/04/23.
//

import SwiftUI
import Charts

struct FrequencyDomainChartView: View {
    @EnvironmentObject var model: CameraViewModel
    
    var body: some View {
        VStack {
            if model.lastTransform.isEmpty {
                Spacer()
                NoticeView(imageSystemName: "chart.xyaxis.line",
                           title: "No data",
                           subtitle: "\(model.greenChannelHistory.count)/\(CameraViewModel.FFT_SAMPLE_COUNT) samples.")
                Spacer()
            } else {
                Chart {
                    ForEach(model.averagedTransform, id: \.bpm) { point in
                        AreaMark(
                            x: .value("Rate", point.bpm),
                            y: .value("Magnitude", point.intensity),
                            series: .value("Spectrum", "Averaged")
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(.red.gradient)
                    }
                    
                    ForEach(model.lastTransform, id: \.bpm) { point in
                        LineMark(
                            x: .value("Rate", point.bpm),
                            y: .value("Magnitude", point.intensity),
                            series: .value("Spectrum", "Raw")
                        )
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(dash: [5, 5]))
                        .foregroundStyle(.white)
                    }
                    
                    if let bpm = model.bpmHistory.last?.bpm {
                        RuleMark(x: .value("Measured BPM", bpm))
                            .foregroundStyle(.white)
                    }
                }
                .chartXScale(domain: 50...100)
                .chartXAxis {
                    AxisMarks(preset: .inset, position: .top, values: .automatic)
                }
                .chartYAxis {
                    AxisMarks(preset: .inset, position: .trailing, values: .automatic)
                }
            }
        }
        .cardStyle(title: "Spectrum")
        .blockSize(width: 3, height: 1)
    }
}

struct FrequencyDomainChartView_Previews: PreviewProvider {
    static var previews: some View {
        FrequencyDomainChartView()
            .environmentObject(FakeCameraViewModel() as CameraViewModel)
    }
}
