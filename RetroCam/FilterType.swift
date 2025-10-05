import UIKit

enum FilterType: Int, CaseIterable {
    case normal
    case eightBit
    case threeDGlasses
    case spectral
    case alien
    case alien2
    case inversion
    case depth
    
    var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .eightBit: return "8-bit"
        case .threeDGlasses: return "3D"
        case .spectral: return "Spectral"
        case .alien: return "Alien"
        case .alien2: return "Alien 2"
        case .inversion: return "Inversion"
        case .depth: return "Depth"
        }
    }
    
    var sfSymbol: String {
        switch self {
        case .normal: return "camera.circle"
        case .eightBit: return "square.grid.3x3.square"
        case .threeDGlasses: return "cube.fill"
        case .spectral: return "camera.filters"
        case .alien: return "globe.central.south.asia"
        case .alien2: return "globe.asia.australia"
        case .inversion: return "circle.lefthalf.filled.righthalf.striped.horizontal.inverse"
        case .depth: return "ev.plug.dc.gb.t.fill"
        }
    }
}
