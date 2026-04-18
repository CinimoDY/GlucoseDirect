//
//  IOBMiddleware.swift
//  DOSBTSApp
//

import Combine
import Foundation

func iobMiddleware() -> Middleware<DirectState, DirectAction> {
    return { state, action, _ in
        switch action {
        case .addSensorGlucose:
            return Just(DirectAction.loadIOBDeliveries)
                .setFailureType(to: DirectError.self)
                .eraseToAnyPublisher()

        case .addInsulinDelivery:
            return Just(DirectAction.loadIOBDeliveries)
                .setFailureType(to: DirectError.self)
                .eraseToAnyPublisher()

        case .deleteInsulinDelivery:
            return Just(DirectAction.loadIOBDeliveries)
                .setFailureType(to: DirectError.self)
                .eraseToAnyPublisher()

        case .setBolusInsulinPreset, .setBasalDIAMinutes:
            return Just(DirectAction.loadIOBDeliveries)
                .setFailureType(to: DirectError.self)
                .eraseToAnyPublisher()

        case .setAppState(appState: let appState):
            guard appState == .active else {
                break
            }

            return Just(DirectAction.loadIOBDeliveries)
                .setFailureType(to: DirectError.self)
                .eraseToAnyPublisher()

        case .loadIOBDeliveries:
            guard state.appState == .active else {
                break
            }

            let maxDIAMinutes = max(state.bolusInsulinPreset.diaMinutes, state.basalDIAMinutes)

            return DataStore.shared.getIOBDeliveries(diaMinutes: maxDIAMinutes).map { deliveries in
                DirectAction.setIOBDeliveries(deliveries: deliveries)
            }.eraseToAnyPublisher()

        default:
            break
        }

        return Empty().eraseToAnyPublisher()
    }
}
