//
//  VirtualDeviceStore.swift
//  DarkBlue
//
//  Created by Marco on 2026/4/21.
//
import Foundation

class VirtualDeviceStore {

    
//    private let saveKey = "SavedVirtualDevices"
    private var pendingWorkItem: DispatchWorkItem?
    
//    init() {
//        devices = load()
//    }
    
//    private func load() {
//        guard let data = UserDefaults.standard.data(forKey: saveKey),
//              let decoded = try? JSONDecoder().decode([VirtualPeripheral].self, from: data) else {
//            // 如果本地没数据，加载之前定义的 presetVirtualDevices
//            self.devices = []
//            return
//        }
//        self.devices = decoded
//    }
//    
//    func save() {
//        if let encoded = try? JSONEncoder().encode(devices) {
//            UserDefaults.standard.set(encoded, forKey: saveKey)
//        }
//    }
    
    // 配合使用的加载方法
    func load() -> [VirtualPeripheral] {
        guard FileManager.default.fileExists(atPath: savePath.path) else { return [] }
        do {
            let data = try Data(contentsOf: savePath)
            let decoder = JSONDecoder()
            return try decoder.decode([VirtualPeripheral].self, from: data)
        } catch {
            print("❌ 加载数据失败: \(error.localizedDescription)")
            return []
        }
    }
    
    // 存储文件的路径（保存在 Documents 文件夹下）
    private var savePath: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("virtual_devices.json")
    }
    
    func persist(_ devices: [VirtualPeripheral]) {
        // 取消之前的待执行任务
        pendingWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            self?.performWrite(devices)
        }
        
        pendingWorkItem = workItem
        // 延迟 0.5 秒执行，如果期间有新修改，旧的会被取消
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }
    
    private func performWrite(_ devices: [VirtualPeripheral]) {
        // 使用后台队列执行磁盘 I/O，避免卡顿主线程
        do {
            let encoder = JSONEncoder()
            // 让生成的 JSON 更易读（方便你调试时直接打开文件看）
            encoder.outputFormatting = .prettyPrinted
            
            let data = try encoder.encode(devices)
            
            // .atomic 选项确保写入过程是原子的：先写临时文件，成功后再替换原文件
            // 这能防止在写入中途 App 崩溃导致数据损坏
            try data.write(to: self.savePath, options: [.atomic, .completeFileProtection])
            
            print("💾 数据已成功持久化至磁盘: \(devices.count) 个设备")
        } catch {
            print("❌ 持久化失败: \(error.localizedDescription)")
        }
    }
}
