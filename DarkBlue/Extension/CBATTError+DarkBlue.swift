//
//  CBATTError+DarkBlue.swift
//  DarkBlue
//
//  Created by Marco on 2026/4/23.
//

import CoreBluetooth

extension CBATTError {
    var localizedDescription: String {
        switch self.code {
        case .success:
            return "操作成功。"
        case .invalidHandle:
            return "无效的属性句柄。"
        case .readNotPermitted:
            return "该特征不允许读取。"
        case .writeNotPermitted:
            return "该特征不允许写入。"
        case .invalidPdu:
            return "协议数据单元 (PDU) 无效。"
        case .insufficientAuthentication:
            return "认证不足，需要配对。"
        case .requestNotSupported:
            return "设备不支持该请求。"
        case .invalidOffset:
            return "无效的数据偏移量（通常发生在读取大数据包时）。"
        case .insufficientAuthorization:
            return "授权不足。"
        case .prepareQueueFull:
            return "准备队列已满。"
        case .attributeNotFound:
            return "未找到指定的属性。"
        case .attributeNotLong:
            return "该属性不是长属性，不支持偏移读取。"
        case .insufficientEncryptionKeySize:
            return "加密密钥长度不足。"
        case .invalidAttributeValueLength:
            return "写入的数据长度非法。"
        case .unlikelyError:
            return "发生偶发性未知错误。"
        case .insufficientEncryption:
            return "连接未加密，无法操作。"
        case .unsupportedGroupType:
            return "不支持的分组类型。"
        case .insufficientResources:
            return "服务器资源不足。"
        default:
            return "ATT 协议错误 (0x\(String(format: "%02X", self.code.rawValue)))"
        }
    }
}
