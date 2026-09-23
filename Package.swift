// swift-tools-version: 5.9
//
//  Package.swift
//  KitoCalendar
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import PackageDescription

let package = Package(
    name: "KitoCalendar",
    platforms: [.iOS(.v17)],
    products: [.library(name: "KitoCalendar", targets: ["KitoCalendar"])],
    dependencies: [
        .package(url: "https://github.com/WykSofts-Inc/KitoCore.git", from: "1.0.0"),
    ],
    targets: [
        .target(name: "KitoCalendar", dependencies: [.product(name: "KitoCore", package: "KitoCore")]),
        .testTarget(name: "KitoCalendarTests", dependencies: ["KitoCalendar"]),
    ]
)
