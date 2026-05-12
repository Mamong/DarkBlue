//
//  CBDescriptor+DarkBlue.swift
//  DarkBlue
//
//  Created by Marco on 2026/4/24.
//

import CoreBluetooth

extension CBDescriptor{
    var valueString: String {
            guard let value = self.value else { return "No Value" }
            
            switch self.uuid {
            case CBUUID.characteristicUserDescriptionUUID: // Characteristic User Description
                return (value as? String) ?? "Invalid String"
                
            case CBUUID.clientCharacteristicConfigurationUUID: // Client Characteristic Configuration (CCCD)
                guard let data = value as? NSNumber else { return "Unknown" }
                let byte = data.uint16Value
                if byte == 0x0  { return "0"/*Disbaled*/}
                if byte == 0x01 { return "1"/*"Notifications Enabled"*/ }
                if byte == 0x02 { return "1"/*Indications Enabled"*/ }
                if byte == 0x03 { return "2"/*"Both Enabled"*/ }
                return ""
                
            case CBUUID.characteristicPresentationFormatUUID: // Characteristic Presentation Format
                return "Format Descriptor (Data Structure)" // 结构较复杂，通常显示为格式说明
                
            default:
                // 不常见的描述符，显示原始 Hex
                if let data = value as? Data {
                    return data.map { String(format: "%02X", $0) }.joined(separator: " ")
                }
                return "\(value)"
            }
        }
}
