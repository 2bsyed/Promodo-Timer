import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var viewModel: TimerViewModel
    @AppStorage("standardTimer") private var standardTimer = 25
    @AppStorage("shortBreak") private var shortBreak = 5
    @AppStorage("longBreak") private var longBreak = 10

    private let accentColor = Color(red: 241/255, green: 152/255, blue: 70/255)
    private let bgColor = Color.black

    var body: some View {
        VStack(spacing: 0) {
            // Ruler slider
            RulerSliderView(
                value: Binding(
                    get: { viewModel.displayTime },
                    set: { viewModel.displayTime = $0 }
                ),
                range: 0...180,
                step: 1
            )
            .padding(.horizontal, 22)
            .padding(.top, 18)

            Spacer(minLength: 8)

            // Bottom row: button(s) + time display
            HStack(alignment: .center) {
                Button(action: viewModel.toggleTimer) {
                    Text(buttonText(for: viewModel.timerState))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(accentColor)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(accentColor.opacity(0.12))
                        )
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()

                // Large time display
                Text(viewModel.timeString(from: viewModel.remainingTime))
                    .font(.system(size: 46, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundColor(accentColor)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        viewModel.resetTimer()
                    }
            }

            .padding(.horizontal, 22)
            .padding(.bottom, 18)
            .animation(.easeInOut(duration: 0.2), value: viewModel.timerState)
        }
        .frame(width: 320, height: 140)
        .background(bgColor)
        .clipShape(RoundedRectangle(cornerRadius: 42, style: .continuous))
    }




    private func buttonText(for state: TimerState) -> String {
        switch state {
        case .running:
            return "Pause"
        case .paused:
            return "Resume"
        case .stopped:
            return "Start Timer"
        }
    }

    func openTimerWindow() {
        let screen = NSScreen.main
        let screenRect = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)

        let windowWidth: CGFloat = 240
        let windowHeight: CGFloat = 110

        let windowX = screenRect.midX - (windowWidth / 2)
        let windowY = screenRect.midY - (windowHeight / 2)

        let newWindow = NSWindow(
            contentRect: NSRect(x: windowX, y: windowY, width: windowWidth, height: windowHeight),
            styleMask: [.borderless],
            backing: .buffered, defer: false)
        
        newWindow.isMovableByWindowBackground = true
        newWindow.center()
        newWindow.setFrameAutosaveName("TimerWindow")
        newWindow.isReleasedWhenClosed = false
        newWindow.level = .floating
        newWindow.isOpaque = false
        newWindow.backgroundColor = .clear
        newWindow.hasShadow = true
        
        newWindow.contentView = NSHostingView(rootView: timerView(viewModel: viewModel))
        newWindow.makeKeyAndOrderFront(nil)
    }

    func openSettings() {
        for window in NSApplication.shared.windows {
            if window.frameAutosaveName == "SettingsWindow" {
                window.makeKeyAndOrderFront(nil)
                return
            }
        }

        let screen = NSScreen.main
        let screenRect = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let windowWidth: CGFloat = 340
        let windowHeight: CGFloat = 240
        let windowX = screenRect.midX - (windowWidth / 2)
        let windowY = screenRect.midY - (windowHeight / 2)

        let newWindow = NSWindow(
            contentRect: NSRect(x: windowX, y: windowY, width: windowWidth, height: windowHeight),
            styleMask: [.borderless],
            backing: .buffered, defer: false)
        
        newWindow.isMovableByWindowBackground = true
        newWindow.center()
        newWindow.setFrameAutosaveName("SettingsWindow")
        newWindow.isReleasedWhenClosed = false
        newWindow.level = .floating
        newWindow.isOpaque = false
        newWindow.backgroundColor = .clear
        newWindow.hasShadow = true
        
        newWindow.contentView = NSHostingView(rootView: settingsView(standardTimer: $standardTimer, shortBreak: $shortBreak, longBreak: $longBreak))
        newWindow.makeKeyAndOrderFront(nil)
    }

    func openHistory() {
        for window in NSApplication.shared.windows {
            if window.frameAutosaveName == "HistoryWindow" {
                window.makeKeyAndOrderFront(nil)
                return
            }
        }

        let screen = NSScreen.main
        let screenRect = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)

        let windowWidth: CGFloat = 360
        let windowHeight: CGFloat = 590

        let windowX = screenRect.midX - (windowWidth / 2)
        let windowY = screenRect.midY - (windowHeight / 2)

        let newWindow = NSWindow(
            contentRect: NSRect(x: windowX, y: windowY, width: windowWidth, height: windowHeight),
            styleMask: [.borderless],
            backing: .buffered, defer: false)
        
        newWindow.isMovableByWindowBackground = true
        newWindow.center()
        newWindow.setFrameAutosaveName("HistoryWindow")
        newWindow.isReleasedWhenClosed = false
        newWindow.level = .floating
        newWindow.isOpaque = false
        newWindow.backgroundColor = .clear
        newWindow.hasShadow = true
        
        newWindow.contentView = NSHostingView(rootView: HistoryView())
        newWindow.makeKeyAndOrderFront(nil)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(viewModel: TimerViewModel(duration: 25))
    }
}

