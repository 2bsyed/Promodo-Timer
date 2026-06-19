import Cocoa
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var viewModel: TimerViewModel!
    var cancellables: Set<AnyCancellable> = []
    var contentView: ContentView!
    var menu: NSMenu!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Initialize the view model with a 25-minute duration
        viewModel = TimerViewModel(duration: 25)
        
        // Create the content view (keep reference for window helpers)
        contentView = ContentView(viewModel: viewModel)

        // Create the status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = ""
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Create the popover
        popover = NSPopover()
        popover.contentViewController = NSHostingController(rootView: contentView)
        popover.behavior = .transient

        // Build right-click context menu
        menu = NSMenu()
        menu.addItem(NSMenuItem(title: "History", action: #selector(openHistoryMenu), keyEquivalent: "y"))
        menu.addItem(NSMenuItem(title: "Detach Timer", action: #selector(detachTimer), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Settings", action: #selector(openSettingsMenu), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))

        // Observe the remaining time to update the status bar title
        viewModel.$remainingTime
            .receive(on: RunLoop.main)
            .sink { [weak self] remainingTime in
                self?.updateStatusBarTitle()
            }
            .store(in: &cancellables)
    }

    @objc func statusItemClicked(_ sender: Any?) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            // Right-click: show context menu
            popover.performClose(nil)
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            // Remove menu after showing so left-click works again
            DispatchQueue.main.async {
                self.statusItem.menu = nil
            }
        } else {
            // Left-click: toggle popover
            togglePopover(sender)
        }
    }

    @objc func togglePopover(_ sender: Any?) {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                makePopoverBackgroundTransparent()
                popover.contentViewController?.view.window?.becomeKey()
            }
        }
    }

    private func makePopoverBackgroundTransparent() {
        guard let window = popover.contentViewController?.view.window else { return }
        window.backgroundColor = .clear
        window.isOpaque = false
        
        if let frameView = window.contentView?.superview {
            frameView.wantsLayer = true
            frameView.layer?.backgroundColor = NSColor.clear.cgColor
            
            for subview in frameView.subviews {
                if subview != window.contentView {
                    subview.isHidden = true
                    subview.alphaValue = 0
                }
            }
        }
    }

    @objc func openHistoryMenu() {
        contentView.openHistory()
    }

    @objc func detachTimer() {
        contentView.openTimerWindow()
    }

    @objc func openSettingsMenu() {
        contentView.openSettings()
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    func updateStatusBarTitle() {
        if let button = statusItem.button {
            let minutes = viewModel.remainingTime / 60
            let seconds = viewModel.remainingTime % 60
            let title = String(format: "%02d:%02d", minutes, seconds)
            
            // Create an attributed string with monospace font
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            ]
            let attributedTitle = NSAttributedString(string: title, attributes: attributes)
            
            button.attributedTitle = attributedTitle
        }
    }
}
