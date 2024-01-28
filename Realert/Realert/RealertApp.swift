//
//  RealertApp.swift
//  Realert
//
//  Created by Nand Vinchhi on 28/01/24.
//

import SwiftUI

@main
struct RealertApp: App {
    var body: some Scene {
        WindowGroup {
            let res: ClassificationResult = .init(result: "background", confidence: "100%", numThreats: 0, count: 0)
            let bindingRes = Binding.constant(res)
            let resultObserver = ResultsObserver(result: bindingRes)
            ContentView(observer: resultObserver)
        }
    }
}
