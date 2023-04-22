//
//  CameraView.swift
//  Pulse
//
//  Created by Riccardo Persello on 11/03/23.
//

import SwiftUI
import Charts

struct CameraView: View {
    @EnvironmentObject var model: CameraViewModel
    @State private var startButtonPressed = false
    
    var body: some View {
        Group {
            if let image = model.fullPreviewImage,
               model.camera.running {
                VStack {
                    Spacer()
                    image.resizable().scaledToFit()
                    Spacer()
                }
                .background(.black)
            } else {
                VStack {
                    NoticeView(imageSystemName: "camera",
                               title: "Camera required",
                               subtitle: "Pulse needs to access your device's front camera in order to measure your heart rate.")
                    
                    if !startButtonPressed {
                        Button("Start") {
                            model.camera.start()
                            startButtonPressed = true
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        ProgressView()
                    }
                }
                .padding()
            }
        }
        .cardStyle(title: "Preview")
        .blockSize(width: 3, height: 2)
    }
}

struct CameraView_Previews: PreviewProvider {
    static var previews: some View {
        CameraView()
            .environmentObject(FakeCameraViewModel() as CameraViewModel)
            .previewLayout(.fixed(width: 200, height: 1000))
    }
}
