//
//  Widgets.swift
//  Widgets
//

import SwiftUI
import WidgetKit

@main
struct Widgets: WidgetBundle {
    var body: some Widget {
        WidgetBundleBuilder.buildBlock(
            GlucoseWidget(),
            GlucoseActivityWidget(),
            SensorWidget(),
            TransmitterWidget()
        )
    }
}

extension View {
    func widgetBackground(backgroundView: some View) -> some View {
        containerBackground(for: .widget) {
            backgroundView
        }
    }
}
