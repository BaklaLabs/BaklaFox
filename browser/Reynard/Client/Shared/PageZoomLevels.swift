//
//  PageZoomLevels.swift
//  Reynard
//
//  Created by Minh Ton on 28/6/26.
//

import Foundation

enum PageZoomLevels {
    static let defaultLevel = 100
    static let all = [50, 75, 90, 100, 110, 125, 150, 175, 200, 250, 300]
    
    static func displayText(for level: Int) -> String {
        return "\(level)%"
    }
}
