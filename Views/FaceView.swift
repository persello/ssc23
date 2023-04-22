//
//  FaceView.swift
//  Pulse
//
//  Created by Riccardo Persello on 10/04/23.
//

import SwiftUI

struct FaceView: View {
    @EnvironmentObject var model: CameraViewModel
    
    var title: String {
        if model.measurementAreaImage != nil {
            return "Measurement area"
        }
        
        return ""
    }
    
    var body: some View {
        Group {
            if let face = model.measurementAreaImage,
               model.camera.running {
                VStack {
                    Spacer()
                    face.resizable().scaledToFit()
                    Spacer()
                }
                .background(.black)
            } else {
                VStack {
                    NoticeView(imageSystemName: "face.dashed",
                               title: "Face not found",
                               subtitle: "Make sure that the camera can see your face.")
                }
                .padding()
            }
        }
        .cardStyle(title: self.title)
        .blockSize(width: 1, height: 1)
    }
}

struct FaceView_Previews: PreviewProvider {
    static var previews: some View {
        FaceView()
    }
}
