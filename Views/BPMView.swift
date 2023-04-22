//
//  BPMView.swift
//  Pulse
//
//  Created by Riccardo Persello on 08/04/23.
//

import SwiftUI
import Charts

struct BPMView: View {
    @EnvironmentObject var model: CameraViewModel
    
    var lastBpm: Float32? {
        model.bpmHistory.last?.bpm
    }
    
    var bpmString: AttributedString {
        guard let bpmValue = lastBpm else {
            var noData = AttributedString("--")
            noData.font = .system(size: 40, design: .rounded)
            return noData
        }
        
        var valueText = AttributedString("\(bpmValue.rounded().formatted())")
        valueText.font = .system(size: 40, weight: .regular, design: .rounded)
        
        var unitText = AttributedString("BPM")
        unitText.font = .system(size: 18, weight: .semibold, design: .rounded)
        unitText.foregroundColor = .secondary
        
        let result = valueText + unitText
        
        return result
    }
    
    var binnedData: [(date: Date, min: Float32, max: Float32)] {
        let binSize: TimeInterval = 5
        
        var result: [Date : (min: Float32, max: Float32)] = [:]
        
        self.model.bpmHistory.forEach { item in
            let roundedDate = item.date.addingTimeInterval(
                -item.date.timeIntervalSince1970.remainder(dividingBy: binSize)
            )
            
            if result[roundedDate] == nil {
                result[roundedDate] = (item.bpm, item.bpm)
            } else {
                let (prevMin, prevMax) = result[roundedDate]!
                result[roundedDate] = (min(prevMin, item.bpm), max(prevMax, item.bpm))
            }
        }
        
        return result.map { item in
            (item.key, item.value.min, item.value.max)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top) {
                Chart {
                    ForEach(binnedData, id: \.date) { point in
                        BarMark(
                            x: .value("Date", point.date),
                            yStart: .value("Minimum", point.min),
                            yEnd: .value("Maximum", point.max),
                            width: .fixed(4)
                        )
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        .cornerRadius(.infinity, style: .continuous)
                        .foregroundStyle(.red.gradient)
                    }
                }
                .chartXAxis(.hidden)
                .chartXScale(domain: Date.now - 60 ... Date.now)
                .chartYAxis(.hidden)
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(maxHeight: 30)
                
                Spacer()
                Image(systemName: "heart.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.red.gradient)
            }            
            Spacer()
            Text(bpmString)
        }
        .padding(16)
        .cardStyle()
    }
}

struct BPMView_Previews: PreviewProvider {
    static var previews: some View {
        let model = FakeCameraViewModel()
        model.camera.start()
        return BPMView()
            .environmentObject(model as CameraViewModel)
    }
}
