//
//  BluetoothManager.swift
//  DarkBlue
//
//  Created by Marco on 2026/4/16.
//

import CoreBluetooth
import SwiftUI
internal import Combine

enum ConnectStatus:Int {
    case disconnected = 0

    case connecting = 1

    case connected = 2
    
    case negotiating = 3

    case negotiated = 4

    case disconnecting = 5
}


class BluetoothManager: NSObject, ObservableObject {
    private var centralManager: CBCentralManager!
    
    // 发现的设备列表（UI会自动根据这个数组刷新）
    @Published var discoveredDevices: [DiscoveredPeripheral] = []
    @Published var connectedPeripheral: CBPeripheral? // 当前连接成功的设备
    // 蓝牙当前状态
    //@Published var bluetoothState: CBManagerState = .unknown
    
    @Published var isScanning: Bool = false
    @Published var connectState: ConnectStatus = .disconnected
    
    @Published var myCachedServices: [CachedService] = []

    @Published var readValues: [CBUUID: [DataRecord]] = [:]
    @Published var writeValues: [CBUUID: [DataRecord]] = [:]
    
    private var writingValue: Data?
    private var penddingServiceCount = 0
    private var pendingPeripheral: CBPeripheral? // 当前协商的设备

    struct DataRecord: Identifiable {
        let id = UUID()
        let timestamp: Date
        let data: Data
        let type: Int//0读 1写
        
        var hexString: String {
            data.map { String(format: "%02X", $0) }.joined(separator: "")
        }
        
        var asciiString: String {
            String(data: data, encoding: .utf8) ?? "???"
        }
    }
        
    
    // 1. 用于后台高速缓存，不触发 UI 刷新
    private var allDevices: [UUID: DiscoveredPeripheral] = [:]
    // 记录 ID 出现的先后顺序
    private var deviceOrder: [UUID] = []
    
    // 2. 定时器，控制 UI 刷新频率
    private var refreshTimer: Timer?

    // 定义手环常用的 Service UUIDs (用于检索已连接设备)
    private let monitorServices = [
        CBUUID(string: "1800"), // 通用访问 (Generic Access)
        CBUUID(string: "1801"), // 属性服务 (Attribute Service)
        CBUUID(string: "180D"), // 心率
        CBUUID(string: "180F"), // 电池
        CBUUID(string: "1812"), // HID (键盘/鼠标)
        CBUUID(string: "180A"), // 设备信息
        CBUUID(string: "FEE7"), // 微信/通用穿戴
        CBUUID(string: "FEAF")  // 常见蓝牙耳机/音频控制
    ]
    
    private var lastLoggedCount: Int = 0
    private var lastLogTime: Date = .distantPast

    override init() {
        super.init()
        // 初始化中央管理器，delegate 指向自己
        /**
         * initWithDelegate:queue:options: 方法参数
         *
         * CBCentralManagerOptionShowPowerAlertKey  默认为NO，系统当蓝牙关闭时是否弹出一个警告框
         * CBCentralManagerOptionRestoreIdentifierKey 系统被杀死，重新恢复centermanager的ID
         */
        // 创建一个专用的蓝牙后台队列
        //let btQueue = DispatchQueue(label: "com.lion.bluetooth", qos: .userInitiated)
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }
    
    func startScan() {
        stopScan()
        
        deviceOrder.removeAll()
        allDevices.removeAll()
        discoveredDevices.removeAll()
        
        // 动作 B：拉取系统已经连接的设备（比如小米手环）
        fetchConnectedDevices()
        
        resumeScan()
    }

    // 扫描周围设备
    func resumeScan() {
        guard centralManager.state == .poweredOn && !isScanning else { return }
        
        LogEngine.shared.log("Starting search for nearby peripherals")
        LogEngine.shared.log("Scanning on Main Thread")
        
        isScanning = true // 开始扫描
        
        /**
         * scanForPeripheralsWithServices:options: 方法参数
         *
         * CBCentralManagerScanOptionAllowDuplicatesKey  默认为NO，过滤功能是否启用，每次寻找都会合并相同的peripheral。如果设备YES的话每次都能接受到来自peripherals的广播包数据。
         * CBCentralManagerScanOptionSolicitedServiceUUIDsKey  想要扫描的服务的UUID，以一个数组的形式存在。扫描的时候只会扫描到包含这些UUID的设备。
         */
        // 注意：如果要实时刷新 RSSI，CBCentralManagerScanOptionAllowDuplicatesKey 设为 true
        // 这样同一个设备发出的每一个广播包都会触发回调，从而更新信号值
        // 动作 A：扫描周围未连接/未配对的设备
        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        
        // 3. 启动定时器：每 1.0 秒同步一次缓存到 UI
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateUI()
            self?.updateDiscoveryLog()
        }
    }
    
    func fetchConnectedDevices() {
        // iOS 只有指定了具体的 Service UUID 才能找回已连接的设备
        let connected = centralManager.retrieveConnectedPeripherals(withServices: monitorServices)
        
        for peripheral in connected {
            // 已连接设备通常拿不到实时的 RSSI，我们给它一个默认值（比如 -50）
            let device = DiscoveredPeripheral(peripheral: peripheral, rssi: -127, advertisementData: [:], isConnectable: true)
            if allDevices[peripheral.identifier] == nil {
                allDevices[peripheral.identifier] = device
                deviceOrder.append(peripheral.identifier)
                print("成功找回已连接设备: \(peripheral.name ?? "Unknown")")
            }
        }
    }

    func stopScan() {
        LogEngine.shared.log("Stopping search for nearby peripherals")
        centralManager.stopScan()
        isScanning = false // 停止扫描
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    func connect(to peripheral: CBPeripheral) {
        LogEngine.shared.log("Connecting to nearby peripherals: \(peripheral.name ?? "Unnamed")")

        // 1. 记录正在连接的 ID 以显示 ProgressView
        self.connectState = .connecting
        self.pendingPeripheral = peripheral
        self.stopScan()
        self.readValues.removeAll()
        self.writeValues.removeAll()
        self.myCachedServices.removeAll()
        // 2. 发起连接
        /**
         * connectPeripheral:options: 方法中的参数
         * CBConnectPeripheralOptionEnableAutoReconnect:是否要自动连接
         * CBConnectPeripheralOptionNotifyOnConnectionKey 默认为NO，APP被挂起时，这时如果连接到peripheral时，是否要给APP一个提示框。
         * CBConnectPeripheralOptionNotifyOnDisconnectionKey 默认为NO，APP被挂起时，恰好在这个时候断开连接，要不要给APP一个断开提示。
         * CBConnectPeripheralOptionNotifyOnNotificationKey  默认为NO，APP被挂起时，是否接受到所有的来自peripheral的包都要弹出提示框。
         *
         */
        centralManager.connect(peripheral, options: nil)
    }
    
    func disconnect(peripheral: CBPeripheral?){
        guard let peripheral = peripheral else { return }
                
        print("正在断开设备: \(peripheral.name ?? "Unknown")")
        connectState = .disconnecting
        pendingPeripheral = nil
        // 调用系统 API 断开连接
        centralManager.cancelPeripheralConnection(peripheral)
    }
    
    func cancelConnection() {
        disconnect(peripheral: pendingPeripheral)
    }
    
//    func discoverDescriptor(_ characteristic: CBCharacteristic) {
//        guard let connectedPeripheral else {
//            return
//        }
//        connectedPeripheral.discoverDescriptors(for: characteristic)
//    }
    
    func writeValue(_ data: Data, for characteristic: CBCharacteristic) {
        guard let peripheral = connectedPeripheral else { return }
        
        let type: CBCharacteristicWriteType = characteristic.properties.contains(.write) ? .withResponse : .withoutResponse
        // generally, 512 bytes for both ios and macos; test 524
        // withoutResponse will truncates data, while withResponse will fail
        let maxLength = peripheral.maximumWriteValueLength(for: type)
        if maxLength < data.count{
            print("Attempted to write data exceeding the length limit.")
        }
        //let data = data.prefix(maxLength)
        peripheral.writeValue(data, for: characteristic, type: type)
        
        // 关键：手动更新本地已存储的特征值，触发 UI 刷新
        // 注意：CBCharacteristic 的 value 属性是只读的，所以我们需要在 ViewModel 里维护一个自己的缓存
        DispatchQueue.main.async {
            let record = DataRecord(timestamp: Date(), data: data, type: 1)
            // 将新数据插入到该特征对应的数组顶部（最新的在最前）
            if self.writeValues[characteristic.uuid] != nil {
                self.writeValues[characteristic.uuid]?.insert(record, at: 0)
                if self.writeValues[characteristic.uuid]!.count>5{
                    self.writeValues[characteristic.uuid]?.removeLast()
                }
            } else {
                self.writeValues[characteristic.uuid] = [record]
            }
        }
    }
    
    
    // 在 BluetoothManager 类内部添加
    func getAdData(for uuid: UUID) -> [String: Any]? {
        // 假设你之前已经把扫描到的数据存入了 allDevices 字典
        return allDevices[uuid]?.advertisementData
    }

    
    // 4. 统一更新 UI 的方法
    // 定时刷新 UI
    private func updateUI() {
        // 根据记录好的顺序，从缓存中取出对应的设备
        let orderedDevices = deviceOrder.compactMap { allDevices[$0] }
        
        DispatchQueue.main.async {
            // 直接赋值，顺序由 deviceOrder 决定，不再跳动
            self.discoveredDevices = orderedDevices
        }
    }
    
    // 2. 手动触发排序方法
    func sortCurrentList() {
        // 对当前的快照进行一次性排序
        self.deviceOrder.sort{
            (allDevices[$0]?.rssi ?? -127) > (allDevices[$1]?.rssi ?? -127)
        }
        updateUI()
    }

    // 在感知到 allDevices.count 变化的地方调用（例如 .onChange 或 蓝牙回调）
    private func updateDiscoveryLog() {
        let currentCount = allDevices.count
        let now = Date()
        
        // 条件 1: 个数必须大于 10
        //guard currentCount >= 10 else { return }
        
        // 条件 2: 个数必须发生了变化
        guard currentCount != lastLoggedCount else { return }
        
        // 条件 3: 间隔至少 2 秒
        if now.timeIntervalSince(lastLogTime) >= 2.0 {
            // 执行日志记录
            LogEngine.shared.log("\(currentCount) peripherals discovered", level: .info)
            
            // 更新状态锁
            lastLoggedCount = currentCount
            lastLogTime = now
        }
    }
}

extension BluetoothManager: CBCentralManagerDelegate{
    // 1. 监控蓝牙开关状态
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOff:
            LogEngine.shared.log("Bluetooth State : Powered Off")
        case .poweredOn:
            LogEngine.shared.log("Bluetooth State : Powered On")
            startScan()
        case .resetting:
            LogEngine.shared.log("Bluetooth State : Resetting")
        case .unauthorized:
            LogEngine.shared.log("Bluetooth State : Unauthorized")
        case .unknown:
            LogEngine.shared.log("Bluetooth State : Unknown")
        case .unsupported:
            LogEngine.shared.log("Bluetooth State : Unsupported")
        @unknown default:
            fatalError()
        }
    }
    
    func centralManager(
        _ central: CBCentralManager,
        willRestoreState dict: [String : Any]
    ){
        
    }

    // 2. 发现外设时回调
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {

        // 获取是否可连接的状态（有些设备只广播不接受连接，如某些 Beacon）
        let connectable = advertisementData[CBAdvertisementDataIsConnectable] as? Bool ?? false
            
        let deviceID = peripheral.identifier
        let newDevice = DiscoveredPeripheral(peripheral: peripheral, rssi: RSSI.intValue, advertisementData: advertisementData, isConnectable: connectable)
 
        if allDevices[deviceID] == nil {
            // 首次发现：记录顺序并存入缓存
            deviceOrder.append(deviceID)
            allDevices[deviceID] = newDevice
        } else {
            // 再次发现：仅更新数据（RSSI等），不改变顺序
            allDevices[deviceID] = newDevice
        }
    }
    
    // 连接成功的代理
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        LogEngine.shared.log("Connected to nearby peripherals: \(peripheral.name ?? "Unnamed")")

        // 接下来在这里触发 Service 发现
        // 3. 更新状态，触发跳转
        DispatchQueue.main.async {
            self.connectedPeripheral = peripheral
            self.connectState = .connected
        }
        
        // 4. 设置代理并寻找服务
        peripheral.delegate = self
        peripheral.discoverServices(nil)
        self.connectState = .negotiating
    }

    // 连接失败的代理
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("连接失败")
        DispatchQueue.main.async {
            self.connectState = .disconnected
            // 这里可以添加错误提示
        }
    }
    
    //断开连接的代理
    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: (any Error)?
    ){
        if let error {
            LogEngine.shared.log("Disconnecting from nearby peripherals: \(peripheral.name ?? "Unnamed") with error: \(error.localizedDescription)")
        }else{
            LogEngine.shared.log("Disconnecting from nearby peripherals: \(peripheral.name ?? "Unnamed")")
        }
        DispatchQueue.main.async {
            // 1. 清理当前连接的对象
            if self.connectedPeripheral?.identifier == peripheral.identifier {
                self.connectedPeripheral = nil
            }
            
            // 2. 重置导航状态，确保 UI 回到列表页（如果还没回的话）
            //self.navigateToDetail = false
            
            // 3. 清理该特征值的读取历史（可选，根据你的需求决定是否保留）
            //self.characteristicValues.removeAll()
            
            // 4. 断开后通常建议重新开始扫描，除非用户手动停止了
            //self.startScanning()
        }
        //objectWillChange.send()
    }
#if os(iOS)
    
    func centralManager(
        _ central: CBCentralManager,
        connectionEventDidOccur event: CBConnectionEvent,
        for peripheral: CBPeripheral
    ){}

    
    func centralManager(
        _ central: CBCentralManager,
        didUpdateANCSAuthorizationFor peripheral: CBPeripheral
    ){}
#endif
    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        timestamp: CFAbsoluteTime,
        isReconnecting: Bool,
        error: (any Error)?
    ){}
}

extension BluetoothManager: CBPeripheralDelegate{
    
    // 发现服务后的回调
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            // 发现每个服务下的特征
            peripheral.discoverCharacteristics(nil, for: service)
        }
        self.myCachedServices = services.map { CachedService(uuid: $0.uuid) }
        penddingServiceCount = myCachedServices.count
        // 触发 UI 刷新
        //objectWillChange.send()
        DispatchQueue.main.asyncAfter(deadline: .now()+10){
            if self.penddingServiceCount > 0{
                self.connectState = .negotiated
            }
        }
    }
    
    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverIncludedServicesFor service: CBService,
        error: (any Error)?
    ){}
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        // 特征发现后，UI 会通过 service.characteristics 自动获取
        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            if [CBUUID.batteryLevelUUID,
                CBUUID.manufacturerNameStringUUID,
                CBUUID.modelNumberStringUUID].contains(characteristic.uuid){
                peripheral.readValue(for: characteristic)
            }
            peripheral.discoverDescriptors(for: characteristic)
        }
        // 找到对应的缓存 Service 并填充特征
        if let index = myCachedServices.firstIndex(where: { $0.uuid == service.uuid }) {
            myCachedServices[index].characteristics = characteristics.map {
                CachedCharacteristic(uuid: $0.uuid, properties: $0.properties, service: myCachedServices[index].uuid)
            }
        }else{
            print("miss match")
        }
        penddingServiceCount = penddingServiceCount - 1
        
        if penddingServiceCount == 0 {
            //TODO: 读取值完毕后再完成协商
            DispatchQueue.main.asyncAfter(deadline: .now()+3){
                self.connectState = .negotiated
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        guard let descriptors = characteristic.descriptors else { return }
        print("Bluetooth Manager --> didDiscoverDescriptorsForCharacteristic")
        if let error {
            print("Bluetooth Manager --> Fail to discover descriptor for characteristic Error:\(error.localizedDescription)")
            return
        }
        for descriptor in descriptors {
            print("发现描述符: \(descriptor.uuid)")
            // 如果需要读取描述符的值
            peripheral.readValue(for: descriptor)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            print("Bluetooth Manager --> Failed to read value for the characteristic. Error:\(error.localizedDescription)")
            //TODO: 是否要写入空值
            return
        }
        LogEngine.shared.log("Characteristic [\(characteristic.uuid.uuidString)] read: <\(characteristic.value!.hexSummary)>")

        guard let data = characteristic.value else { return }
        
        DispatchQueue.main.async {
            let record = DataRecord(timestamp: Date(), data: data, type: 0)
            // 将新数据插入到该特征对应的数组顶部（最新的在最前）
            if self.readValues[characteristic.uuid] != nil {
                self.readValues[characteristic.uuid]?.insert(record, at: 0)
                if self.readValues[characteristic.uuid]!.count>5{
                    self.readValues[characteristic.uuid]!.removeLast()
                }
            } else {
                self.readValues[characteristic.uuid] = [record]
            }
            //同步缓存的特征值
            if let index = self.myCachedServices.firstIndex(where: { $0.uuid == characteristic.service!.uuid }) {
                if let cindex = self.myCachedServices[index].characteristics?.firstIndex(where: {$0.uuid == characteristic.uuid}){
                    self.myCachedServices[index].characteristics?[cindex].value = data
                }
            }
        }
        // 2. 检查 App 是否在后台
        #if os(iOS)
        if UIApplication.shared.applicationState == .background {
            // 3. 发送本地通知
            //let threshold = UserDefaults.standard.double(forKey: "minRssiThreshold")
            let charName = characteristic.uuid.displayName
            let charId = characteristic.uuid.uuidString
            let content = UNMutableNotificationContent()
            content.title = charName == charId ? charId: "\(charId) \(charName)"
            //content.subtitle = "来自设备: \(peripheral.name ?? "Unknown")"
            //TODO: dataformat dynamic
            content.body = data.formattedDataString(as: .hex)
            //content.sound = .default

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil // 立即发送
            )
            
            UNUserNotificationCenter.current().add(request)
        }
        #endif
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {

        guard let characteristic = descriptor.characteristic else { return }

        let description = descriptor.valueString
        print("特征 \(descriptor.characteristic?.uuid.uuidString ?? "") 的描述是: \(description)")
        
        //同步缓存的用户描述
//        if descriptor.uuid == CBUUID.characteristicUserDescriptionUUID{
//            if let index = self.myCachedServices.firstIndex(where: { $0.uuid == characteristic.service!.uuid }) {
//                if let cindex = self.myCachedServices[index].characteristics?.firstIndex(where: {$0.uuid == characteristic.uuid}){
//                    self.myCachedServices[index].characteristics?[cindex].userDescription = description
//                }
//            }
//        }
    }
    
    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: (any Error)?
    ){
        print("Bluetooth Manager --> didUpdateNotificationStateForCharacteristic")
        if let error {
            print("Bluetooth Manager --> Failed to update notification for the characteristic. Error:\(error.localizedDescription)")
            //FIXME: 多个设备订阅同个特征时候，取消订阅会报错且isNotifying仍然为true，似乎是ios自己的问题，LightBlue也如此
            print("警告：订阅报未知错误，但状态已同步为\(characteristic.isNotifying ?"打开":"关闭")。")
            return
        }
        objectWillChange.send()
    }
    
    func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: (any Error)?
    ){
        print("Bluetooth Manager --> didWriteValueForCharacteristic")
        if let error {
            print("Bluetooth Manager --> Failed to write value for the characteristic. Error:\(error.localizedDescription)")
            return
        }
    }
    
    func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor descriptor: CBDescriptor,
        error: (any Error)?
    ){
        print("Bluetooth Manager --> didWriteValueForDescriptor")
        
    }
    
    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral)
    {
        print("Bluetooth Manager --> isReady(toSendWriteWithoutResponse")
    }
    
    func peripheralDidUpdateName(_ peripheral: CBPeripheral){
        print("Bluetooth Manager --> didUpdateName")
        
    }
    
    func peripheral(
        _ peripheral: CBPeripheral,
        didModifyServices invalidatedServices: [CBService]
    ){
        print("Bluetooth Manager --> didModifyServices")
        print("外设服务已变更: \(invalidatedServices.map { $0.uuid.uuidString })")
        //TODO: 服务变更支持，但是LightBlue似乎并不处理
        return
        // 1. 检查受影响的服务中是否包含我们当前正在查看的服务
        // 在 DarkBlue 中，通常的做法是直接触发全量重新发现，以保证数据绝对同步
        
        // 2. 重新发现服务
        // 传入 nil 表示重新发现所有服务，或者只发现 invalidatedServices 里的 UUID
        //peripheral.discoverServices(nil)
        
        // 3. UI 提示 (可选)
        // 告知用户外设配置已更新，正在重新加载...
    }
    
    func peripheral(
        _ peripheral: CBPeripheral,
        didReadRSSI RSSI: NSNumber,
        error: (any Error)?
    ){}
    
    func peripheral(
        _ peripheral: CBPeripheral,
        didOpen channel: CBL2CAPChannel?,
        error: (any Error)?
    ){}
}

//CBPeripheralManagerDelegate,模拟外设时候，收到中心设备的请求
