import SwiftUI

struct ContentView: View {
    
    var content: some View {
        Group {
            CameraView()
            FaceView()
            BPMView()
            AccuracyView()
            FrequencyDomainChartView()
//            TimelineView(.periodic(from: .now, by: 1)) { context in
//                GreenChannelChartView()
//                .drawingGroup()
//            }
        }
    }
    
    var body: some View {
        ScrollView {
            ViewThatFits {
                BlockGrid(
                    minimumBlockSize: 150,
                    maximumBlockSize: 240,
                    acceptableColumnCounts: [3, 4, 6]) {
                    content
                }
                
                VStack {
                    content
                }
            }
            .padding()
        }
    }
}
