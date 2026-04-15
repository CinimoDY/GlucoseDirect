//
//  TreatmentBannerView.swift
//  DOSBTS
//

import SwiftUI
import Combine

struct TreatmentBannerView: View {
    @EnvironmentObject var store: DirectStore

    @State private var remainingSeconds: Int = 0
    @State private var timer: AnyCancellable?
    @State private var autoDismissTask: DispatchWorkItem?

    private enum BannerState {
        case countdown
        case rechecking
        case staleData
        case recovered(Int) // glucose value
    }

    private var bannerState: BannerState {
        guard let expiry = store.state.treatmentCycleCountdownExpiry else {
            return .countdown
        }

        if Date() < expiry {
            return .countdown
        }

        // Countdown expired
        if store.state.recheckDispatched {
            if let glucose = store.state.latestSensorGlucose,
               glucose.glucoseValue >= store.state.alarmLow {
                return .recovered(glucose.glucoseValue)
            }
            // Still low case is handled by the modal, not the banner
            return .rechecking
        }

        // Check for stale data (no glucose reading for >5 min after expiry)
        if let latestGlucose = store.state.latestSensorGlucose {
            let staleness = Date().timeIntervalSince(latestGlucose.timestamp)
            if staleness > 5 * 60 {
                return .staleData
            }
        } else {
            return .staleData
        }

        return .rechecking
    }

    var body: some View {
        HStack(spacing: DOSSpacing.sm) {
            bannerContent

            Spacer()

            Button(action: {
                store.dispatch(.dismissTreatmentCycle)
            }) {
                Image(systemName: "xmark")
                    .font(DOSTypography.caption)
                    .foregroundColor(AmberTheme.amberDark)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DOSSpacing.md)
        .padding(.vertical, DOSSpacing.sm)
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.cancel()
        }
    }

    // MARK: - Banner Content

    @ViewBuilder
    private var bannerContent: some View {
        switch bannerState {
        case .countdown:
            HStack(spacing: DOSSpacing.xs) {
                Image(systemName: "timer")
                    .foregroundColor(AmberTheme.cgaGreen)
                Text("HYPO TREATMENT")
                    .font(DOSTypography.caption)
                    .foregroundColor(AmberTheme.cgaGreen)
                Text("— recheck in \(formattedRemaining)")
                    .font(DOSTypography.caption)
                    .foregroundColor(AmberTheme.amberPrimary)
            }

        case .rechecking:
            HStack(spacing: DOSSpacing.xs) {
                ProgressView()
                    .tint(AmberTheme.amberPrimary)
                Text("RECHECKING...")
                    .font(DOSTypography.caption)
                    .foregroundColor(AmberTheme.amberPrimary)
            }

        case .staleData:
            HStack(spacing: DOSSpacing.xs) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(AmberTheme.amberPrimary)
                Text("NO RECENT DATA — CHECK SENSOR")
                    .font(DOSTypography.caption)
                    .foregroundColor(AmberTheme.amberPrimary)
            }

        case .recovered(let glucose):
            HStack(spacing: DOSSpacing.xs) {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(AmberTheme.cgaGreen)
                Text("STABILISED AT \(glucose) \(store.state.glucoseUnit.localizedDescription)")
                    .font(DOSTypography.caption)
                    .foregroundColor(AmberTheme.cgaGreen)
            }
            .onAppear {
                // Auto-dismiss after 5 seconds (cancellable if user taps X first)
                let task = DispatchWorkItem { [weak store] in
                    guard let store = store, store.state.treatmentCycleActive else { return }
                    store.dispatch(.endTreatmentCycle)
                }
                autoDismissTask = task
                DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: task)
            }
            .onDisappear {
                autoDismissTask?.cancel()
                autoDismissTask = nil
            }
        }
    }

    // MARK: - Timer

    private var formattedRemaining: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func startTimer() {
        updateRemaining()
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                updateRemaining()
            }
    }

    private func updateRemaining() {
        guard let expiry = store.state.treatmentCycleCountdownExpiry else {
            remainingSeconds = 0
            return
        }
        let remaining = Int(expiry.timeIntervalSinceNow)
        remainingSeconds = max(0, remaining)
    }
}
