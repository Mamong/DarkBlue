//
//  CBManageState+DarkBlue.swift
//  DarkBlue
//
//  Created by Marco on 2026/5/6.
//

import CoreBluetooth

extension CBManagerState {
    var description: String {
        switch self {
        case .poweredOn:    return "poweredOn"
        case .poweredOff:   return "poweredOff"
        case .unauthorized: return "unauthorized"
        case .unsupported:  return "unsupported"
        case .resetting:    return "resetting"
        case .unknown:      return "unknown"
        @unknown default:   return "unknown default"
        }
    }
}
