//
//  timerView.swift
//  Timer
//
//

import SwiftUI

struct timerView: View {
    @ObservedObject var viewModel: TimerViewModel
    @State private var isHovered = false

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            // Calculate progress: remaining seconds divided by total seconds
            let totalSeconds = viewModel.timerDuration * 60
            let progress: Double = totalSeconds > 0 ? Double(viewModel.remainingTime) / totalSeconds : 0.0
            let lineX = width * CGFloat(progress)
            
            ZStack(alignment: .leading) {
                // Animated progress backgrounds and vertical separator line
                ZStack(alignment: .leading) {
                    // Left side: warm chocolate/brown color representing remaining progress
                    Rectangle()
                        .fill(Color(red: 43/255, green: 36/255, blue: 30/255))
                        .frame(width: lineX)
                    
                    // Right side: very dark/black color representing elapsed progress
                    Rectangle()
                        .fill(Color(red: 19/255, green: 19/255, blue: 19/255))
                        .frame(width: width - lineX)
                        .offset(x: lineX)
                    
                    // Vertical orange indicator line dividing remaining and elapsed progress
                    Rectangle()
                        .fill(Color(red: 241/255, green: 152/255, blue: 70/255))
                        .frame(width: 2.0)
                        .offset(x: lineX)
                        .opacity(progress > 0 && progress < 1.0 ? 1 : 0) // hide at the absolute edges
                }
                .animation(.linear(duration: 1.0), value: progress)
                
                // Digital remaining time text centered in the window
                Text(viewModel.timeString(from: viewModel.remainingTime))
                    .font(.system(size: 52, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundColor(Color(red: 241/255, green: 152/255, blue: 70/255))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Hover close button in top-left corner
                VStack {
                    HStack {
                        Button(action: {
                            for window in NSApplication.shared.windows {
                                if window.frameAutosaveName == "TimerWindow" {
                                    window.close()
                                    break
                                }
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color.white.opacity(0.4))
                                .padding(4)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .opacity(isHovered ? 1.0 : 0.0)
                        .animation(.easeInOut(duration: 0.15), value: isHovered)
                        
                        Spacer()
                    }
                    Spacer()
                }
                .padding(.top, 8)
                .padding(.leading, 8)
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
            .onTapGesture(count: 2) {
                viewModel.toggleTimer()
            }
            .onHover { hovering in
                isHovered = hovering
            }
        }
        .frame(width: 240, height: 110)
    }
}

#Preview {
    timerView(viewModel: TimerViewModel(duration: 25))
}
