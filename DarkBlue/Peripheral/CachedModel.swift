//
//  CachedModel.swift
//  DarkBlue
//
//  Created by Marco on 2026/4/19.
//

import Foundation
import CoreBluetooth


struct CachedService: Hashable, Equatable {
    let uuid: CBUUID
    var characteristics: [CachedCharacteristic]?
    
//    static func == (lhs: CachedService, rhs: CachedService) -> Bool {
//        return lhs.uuid.isEqual(rhs.uuid)
//    }

    func hash(into hasher: inout Hasher){
        hasher.combine(uuid.hash)
    }
}

struct CachedCharacteristic: Hashable, Equatable {
    let uuid: CBUUID
    var properties: CBCharacteristicProperties

    var value: Data?
    //var descriptors: [CachedDescriptor] = []
    var userDescription:String?
    var service: CBUUID?
    
    var displayName:String{
        return userDescription ?? uuid.displayName
    }
    
    static func == (lhs: CachedCharacteristic, rhs: CachedCharacteristic) -> Bool {
        return lhs.uuid.isEqual(rhs.uuid) &&
         lhs.properties == rhs.properties &&
         lhs.service == rhs.service &&
         lhs.userDescription == rhs.userDescription
    }

    func hash(into hasher: inout Hasher){
        hasher.combine(uuid.hash)
    }
}

