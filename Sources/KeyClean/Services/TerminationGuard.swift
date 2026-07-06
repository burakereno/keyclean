import AppKit
import Foundation

@MainActor
final class TerminationGuard {
    private weak var appState: KeyCleanState?
    private var signalSources: [DispatchSourceSignal] = []

    init(appState: KeyCleanState) {
        self.appState = appState
        installSignalHandlers()
    }

    deinit {
        signalSources.forEach { $0.cancel() }
    }

    private func installSignalHandlers() {
        let handledSignals = [SIGTERM, SIGINT, SIGHUP, SIGQUIT]

        signalSources = handledSignals.map { signalNumber in
            signal(signalNumber, SIG_IGN)

            let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .main)
            source.setEventHandler { [weak self] in
                guard let self else { return }
                self.unlockAndTerminate()
            }
            source.resume()
            return source
        }
    }

    private func unlockAndTerminate() {
        appState?.unlock()
        NSApp.terminate(nil)
    }
}
