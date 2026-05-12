//
//  LogEngine.swift
//  DarkBlue
//
//  Created by Marco on 2026/4/18.
//

import SwiftUI
internal import Combine

class LogEngine: ObservableObject {
    static let shared = LogEngine()
    
    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let message: String
        let level: LogLevel
        
        // 自定义格式化输出
        var timeString: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS" // 如果需要毫秒可以改用 "HH:mm:ss.SSS"
            return formatter.string(from: timestamp)
        }
    }
    
    enum LogLevel {
        case info, error, warning, success
        var color: Color {
            switch self {
            case .info: return .primary
            case .error: return .red
            case .warning: return .orange
            case .success: return .green
            }
        }
    }

    @Published var entries: [LogEntry] = []

    func log(_ message: String, level: LogLevel = .info) {
        DispatchQueue.main.async {
            let entry = LogEntry(timestamp: Date(), message: message, level: level)
            self.entries.append(entry)
            // 限制条数防止占用过多内存
            if self.entries.count > 1000 { self.entries.removeFirst() }
        }
    }
}
