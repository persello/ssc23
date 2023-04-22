//
//  WelcomeView.swift
//  Pulse
//
//  Created by Riccardo Persello on 12/04/23.
//

import SwiftUI

struct WelcomeView: View {
    @Binding var shown: Bool
    var body: some View {
        ScrollView(.vertical) {
            VStack {
                VStack {
                    Image(systemName: "heart.fill")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 96, height: 96)
                        .foregroundStyle(.green.gradient)
                        .shadow(color: .green.opacity(0.4), radius: 18)
                        .padding(48)
                        .background(
                            Rectangle()
                                .foregroundColor(.white)
                                .cornerRadius(36)
                                .shadow(color: .black.opacity(0.1), radius: 18)
                        )
                    
                    Text("Welcome to Pulse")
                        .font(.system(size: 48, weight: .bold))
                        .padding()
                }
                .padding(.vertical, 48)
                
                Spacer()
                
                Grid(alignment: .leading, horizontalSpacing: 36, verticalSpacing: 16) {
                    
                    GridRow {
                        Image(systemName: "info")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 48, height: 48)
                            .foregroundStyle(.green.gradient)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("About Pulse")
                                .font(.title2)
                            Text("Pulse is an app that can estimate your heart rate using a webcam. This is done by analyzing a weighed average (in the frequency domain) of the amount of green light reflected from your lower face area.")
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    
                    GridRow {
                        Image(systemName: "person.fill.viewfinder")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 48, height: 48)
                            .foregroundStyle(.pink.gradient)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Setup")
                                .font(.title2)
                            Text("Position your device on a table and sit in front of it. Stay in a diffusely well-lit environment, but avoid pointing strong lights towards your face, as they can create unwanted peaks at some rates.")
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    
                    GridRow {
                        Image(systemName: "face.dashed.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 48, height: 48)
                            .foregroundStyle(.blue.gradient)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("During the measurement")
                                .font(.title2)
                            Text("Try to stay as still as possible, do not tilt your head or move your mouth. Breathe normally: slow respiratory movements are automatically stabilized.")
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    
                    GridRow {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 48, height: 48)
                            .foregroundStyle(.yellow.gradient)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Limitations")
                                .font(.title2)
                            Text("The resulting measurement is an estimate of your heart rate. The frequency range is limited, and a stable pulse detection may take up to a minute after achieving good measurement stability. Please note that accuracy may vary with different lighting conditions, measuring device, distance from the camera, and facial features (such as beards, skin tone and chin shape).")
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, 36)
            }
        }
        
        Divider()
            .padding(.vertical, 4)
        
        HStack {
            Spacer()
            Button("Continue") {
                shown = false
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
        }
        .padding()
    }
}

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView(shown: .constant(true))
    }
}
