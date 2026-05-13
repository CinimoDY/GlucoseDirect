//
//  MealStore.swift
//  DOSBTSApp
//

import Combine
import Foundation
import GRDB

func mealEntryStoreMiddleware() -> Middleware<DirectState, DirectAction> {
    return { state, action, _ in
        switch action {
        case .startup:
            DataStore.shared.createMealEntryTable()

            return DataStore.shared.getFirstMealEntryDate().map { minSelectedDate in
                DirectAction.setMinSelectedDate(minSelectedDate: minSelectedDate)
            }.eraseToAnyPublisher()

        case .addMealEntry(mealEntryValues: let mealEntryValues):
            guard !mealEntryValues.isEmpty else {
                return Empty().eraseToAnyPublisher()
            }
            // Async write — emit .loadMealEntryValues from the completion.
            // The reducer already did an optimistic in-memory append so the
            // marker shows immediately; the reload is a defensive re-sync.
            return DataStore.shared.insertMealEntry(mealEntryValues)
                .map { _ in DirectAction.loadMealEntryValues }
                .eraseToAnyPublisher()

        // Cross-middleware: mealImpactStoreMiddleware also handles .deleteMealEntry
        // to cascade-delete MealImpact rows
        case .deleteMealEntry(mealEntry: let mealEntry):
            return DataStore.shared.deleteMealEntry(mealEntry)
                .map { _ in DirectAction.loadMealEntryValues }
                .eraseToAnyPublisher()

        case .updateMealEntry(mealEntry: let mealEntry):
            return DataStore.shared.updateMealEntry(mealEntry)
                .map { _ in DirectAction.loadMealEntryValues }
                .eraseToAnyPublisher()

        case .setSelectedDate(selectedDate: _):
            return Just(DirectAction.loadMealEntryValues)
                .setFailureType(to: DirectError.self)
                .eraseToAnyPublisher()

        case .loadMealEntryValues:
            guard state.appState == .active else {
                return Empty().eraseToAnyPublisher()
            }

            return DataStore.shared.getMealEntryValues(selectedDate: state.selectedDate).map { mealEntryValues in
                DirectAction.setMealEntryValues(mealEntryValues: mealEntryValues)
            }.eraseToAnyPublisher()

        case .setAppState(appState: let appState):
            guard appState == .active else {
                return Empty().eraseToAnyPublisher()
            }

            return Just(DirectAction.loadMealEntryValues)
                .setFailureType(to: DirectError.self)
                .eraseToAnyPublisher()

        default:
            break
        }

        return Empty().eraseToAnyPublisher()
    }
}

// `internal` (not `private`) so the App Intents in App/Intents/ can call
// insertMealEntry directly when Siri invokes them outside the Redux
// dispatch path (DMNC-634).
extension DataStore {
    func createMealEntryTable() {
        if let dbQueue = dbQueue {
            do {
                try dbQueue.write { db in
                    try db.create(table: MealEntry.Table, ifNotExists: true) { t in
                        t.column(MealEntry.Columns.id.name, .text)
                            .primaryKey()
                        t.column(MealEntry.Columns.timestamp.name, .date)
                            .notNull()
                            .indexed()
                        t.column(MealEntry.Columns.mealDescription.name, .text)
                            .notNull()
                        t.column(MealEntry.Columns.carbsGrams.name, .double)
                        t.column(MealEntry.Columns.timegroup.name, .date)
                            .notNull()
                            .indexed()
                    }
                }
            } catch {
                DirectLog.error("\(error)")
            }

            var migrator = DatabaseMigrator()

            migrator.registerMigration("Add nutrition columns to MealEntry") { db in
                try db.alter(table: MealEntry.Table) { t in
                    t.add(column: MealEntry.Columns.proteinGrams.name, .double)
                    t.add(column: MealEntry.Columns.fatGrams.name, .double)
                    t.add(column: MealEntry.Columns.calories.name, .double)
                    t.add(column: MealEntry.Columns.fiberGrams.name, .double)
                }
            }

            migrator.registerMigration("Add analysisSessionId to MealEntry") { db in
                try db.alter(table: MealEntry.Table) { t in
                    t.add(column: MealEntry.Columns.analysisSessionId.name, .text)
                }
            }

            do {
                try migrator.migrate(dbQueue)
            } catch {
                DirectLog.error("\(error)")
            }
        }
    }

    func deleteAllMealEntry() {
        if let dbQueue = dbQueue {
            do {
                try dbQueue.write { db in
                    do {
                        try MealEntry.deleteAll(db)
                    } catch {
                        DirectLog.error("\(error)")
                    }
                }
            } catch {
                DirectLog.error("\(error)")
            }
        }
    }

    /// Async-write variants — DMNC-905. See InsulinDeliveryStore for the
    /// rationale: sync `dbQueue.write` blocks the dispatch thread (main) for
    /// the duration of the GRDB write, stalling SwiftUI's runloop and hiding
    /// the reducer's optimistic state update from `.onChange` observers.
    func deleteMealEntry(_ value: MealEntry) -> Future<Void, DirectError> {
        return Future { promise in
            guard let dbQueue = self.dbQueue else {
                promise(.success(()))
                return
            }
            dbQueue.asyncWrite({ db in
                try MealEntry.deleteOne(db, id: value.id)
            }, completion: { _, result in
                switch result {
                case .success: promise(.success(()))
                case .failure(let error):
                    DirectLog.error("\(error)")
                    promise(.failure(.withError(error)))
                }
            })
        }
    }

    func updateMealEntry(_ value: MealEntry) -> Future<Void, DirectError> {
        return Future { promise in
            guard let dbQueue = self.dbQueue else {
                promise(.success(()))
                return
            }
            dbQueue.asyncWrite({ db in
                try value.update(db)
            }, completion: { _, result in
                switch result {
                case .success: promise(.success(()))
                case .failure(let error):
                    DirectLog.error("\(error)")
                    promise(.failure(.withError(error)))
                }
            })
        }
    }

    func insertMealEntry(_ values: [MealEntry]) -> Future<Void, DirectError> {
        return Future { promise in
            guard let dbQueue = self.dbQueue else {
                promise(.success(()))
                return
            }
            dbQueue.asyncWrite({ db in
                for value in values {
                    try value.insert(db)
                }
            }, completion: { _, result in
                switch result {
                case .success: promise(.success(()))
                case .failure(let error):
                    DirectLog.error("\(error)")
                    promise(.failure(.withError(error)))
                }
            })
        }
    }

    func getFirstMealEntryDate() -> Future<Date, DirectError> {
        return Future { promise in
            if let dbQueue = self.dbQueue {
                dbQueue.asyncRead { asyncDB in
                    do {
                        let db = try asyncDB.get()

                        if let date = try Date.fetchOne(db, sql: "SELECT MIN(timestamp) FROM \(MealEntry.Table)") {
                            promise(.success(date))
                        } else {
                            promise(.success(Date()))
                        }
                    } catch {
                        promise(.failure(.withError(error)))
                    }
                }
            }
        }
    }

    func getMealEntryValues(selectedDate: Date? = nil) -> Future<[MealEntry], DirectError> {
        return Future { promise in
            if let dbQueue = self.dbQueue {
                dbQueue.asyncRead { asyncDB in
                    do {
                        let db = try asyncDB.get()

                        if let selectedDate = selectedDate, let nextDate = Calendar.current.date(byAdding: .day, value: +1, to: selectedDate) {
                            let result = try MealEntry
                                .filter(Column(MealEntry.Columns.timestamp.name) >= selectedDate.startOfDay)
                                .filter(nextDate.startOfDay > Column(MealEntry.Columns.timestamp.name))
                                .order(Column(MealEntry.Columns.timestamp.name))
                                .fetchAll(db)

                            promise(.success(result))
                        } else {
                            let result = try MealEntry
                                .filter(sql: "\(MealEntry.Columns.timestamp.name) >= datetime('now', '-\(DirectConfig.lastChartHours) hours')")
                                .order(Column(MealEntry.Columns.timestamp.name))
                                .fetchAll(db)

                            promise(.success(result))
                        }
                    } catch {
                        promise(.failure(.withError(error)))
                    }
                }
            }
        }
    }
}
