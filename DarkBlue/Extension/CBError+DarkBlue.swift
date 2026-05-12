//
//  CBError+DarkBlue.swift
//  DarkBlue
//
//  Created by Marco on 2026/4/23.
//

import CoreBluetooth

extension CBError {
    var localizedDescription: String {
        switch self.code {
        case .unknown:
            return "发生未知错误。"
        case .invalidParameters:
            return "广播参数无效（可能是名称过长或 UUID 格式错误）。"
        case .invalidHandle:
            return "无效的句柄。"
        case .notConnected:
            return "设备未连接。"
        case .outOfSpace:
            return "系统资源不足（尝试添加的服务或特征过多）。"
        case .operationCancelled:
            return "操作已取消。"
        case .connectionTimeout:
            return "连接超时。"
        case .peripheralDisconnected:
            return "外设已断开连接。"
        case .uuidNotAllowed:
            return "该 UUID 被系统保留，不允许使用。"
        case .alreadyAdvertising:
            return "设备正在广播中。"
        case .connectionFailed:
            return "连接失败。"
        case .connectionLimitReached:
            return "已达到蓝牙连接数量上限。"
        case .operationNotSupported:
            return "该设备不支持此蓝牙功能。"
        case .unknownDevice:
            return "未知设备。"
        default:
            return "蓝牙错误: \(self.code.rawValue)"
        }
    }
}

func getReadableError(_ error: Error) -> String {
    if let cbError = error as? CBError {
        return cbError.localizedDescription
    } else if let attError = error as? CBATTError {
        return attError.localizedDescription
    }
    return error.localizedDescription
}
