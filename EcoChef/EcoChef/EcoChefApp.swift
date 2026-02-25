//
//  EcoChefApp.swift
//  EcoChef
//
//  Created by AMAN SHARMA on 15/02/26.
//

import SwiftUI

@main
struct EcoChefApp: App {
    @UIApplicationDelegateAdaptor(NotificationAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
