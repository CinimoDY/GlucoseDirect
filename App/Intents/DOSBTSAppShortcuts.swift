//
//  DOSBTSAppShortcuts.swift
//  DOSBTSApp
//
//  Surfaces the two logging intents to Siri + Shortcuts + Spotlight via
//  AppShortcutsProvider. iOS auto-discovers up to 10 phrases per shortcut;
//  we keep the set small and focused on natural phrasing.
//

import AppIntents

struct DOSBTSAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // Note: AppShortcut phrases can interpolate AppEnum / AppEntity
        // parameters, not primitives like Double or String. For numeric
        // parameters (units, carbs) the user provides them in a Siri
        // follow-up turn ("How many units?") after triggering the shortcut.
        AppShortcut(
            intent: AddInsulinIntent(),
            phrases: [
                "Log insulin in \(.applicationName)",
                "Log a dose in \(.applicationName)",
                "Log a \(\.$type) in \(.applicationName)",
                "Add insulin to \(.applicationName)"
            ],
            shortTitle: "Log insulin",
            systemImageName: "syringe.fill"
        )

        AppShortcut(
            intent: AddMealIntent(),
            phrases: [
                "Log a meal in \(.applicationName)",
                "Log food in \(.applicationName)",
                "Log carbs in \(.applicationName)",
                "Add a meal to \(.applicationName)"
            ],
            shortTitle: "Log meal",
            systemImageName: "apple.logo"
        )
    }
}
