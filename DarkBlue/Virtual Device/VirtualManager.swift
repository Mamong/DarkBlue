//
//  VirtualManager.swift
//  DarkBlue
//
//  Created by Marco on 2026/4/20.
//

import CoreBluetooth
internal import Combine

class VirtualManager: NSObject, ObservableObject {
    
    // 用于驱动 UI 弹出 Alert
    @Published var errorMessage: String? = nil
    @Published var showErrorAlert: Bool = false
    
    @Published var isAdvertising: Bool = false
    @Published var bluetoothState: CBManagerState = .unknown
    
    
    // 记录每个特征 UUID 当前的订阅者数量
    @Published private(set) var subscribedCentrals: [CBUUID: Set<UUID>] = [:]
    
    // 1. 隐藏持久化逻辑
    private let deviceStore = VirtualDeviceStore()
    
    // 2. 暴露给 UI 的计算属性
    @Published var savedDevices: [VirtualPeripheral] = []{
        didSet {
            // 每当内存数据变动，自动同步到磁盘
            deviceStore.persist(savedDevices)
        }
    }
    
    // 核心：保存添加成功的 Service 对象引用
    private var registeredServices: [String: CBMutableService] = [:]
    
    private(set) var currentPeripheralID: UUID?
    
    //private let deviceStore: VirtualDeviceStore // 持有引用
    private var peripheralManager: CBPeripheralManager!
    
    // 存储所有已连接设备的 MTU，Key 是设备的 UUID
    private var centralMTUs: [UUID: Int] = [:]
    
    // 获取当前所有连接中的最小 MTU（用于广播数据时的分包参考）
    var minMTU: Int {
        centralMTUs.values.min() ?? 23 // 默认最保底值为 23
    }
    
    var currentPeripheral: VirtualPeripheral?{
        savedDevices.first { vp in
            vp.id == currentPeripheralID
        }
    }
    
    override init() {
        self.savedDevices = deviceStore.load() // 初始化同步
        super.init()
        // 这里的 Queue 设为主线程方便更新 UI
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    // 2. 配置并开启广播
    func startAdvertising(peripheral: VirtualPeripheral) {
        guard bluetoothState == .poweredOn else { return }
        
        LogEngine.shared.log("peripheralManager: will refresh Peripheral")
        LogEngine.shared.log("peripheralManager: will remove all services")

        peripheralManager.removeAllServices()
        registeredServices.removeAll()
        
        currentPeripheralID = peripheral.id
        
        LogEngine.shared.log("peripheralManager: will add services[\(peripheral.services.count)]")

        for service in peripheral.services {
            var characteristics :[CBMutableCharacteristic] = []
            for characteristic in service.characteristics {
                // 定义一个特征 (Read + Write + Notify)
                let newCharacteristic = CBMutableCharacteristic(
                    type: CBUUID(string: characteristic.uuid),
                    properties: characteristic.properties,
                    value: nil, // 设为 nil 表示动态管理数据
                    permissions: calculatePermissions(from: characteristic.properties)
                )
                if !characteristic.userDescription.isEmpty{
                    let descriptionDescriptor = CBMutableDescriptor(
                        type: CBUUID.characteristicUserDescriptionUUID,
                        value: characteristic.userDescription // 这里的 value 会被系统自动处理为 Data
                    )
                    // 将描述符装载到特征中
                    newCharacteristic.descriptors = [descriptionDescriptor]
                }
                characteristics.append(newCharacteristic)
            }
            // 定义一个服务并将特征加入
            let newService = CBMutableService(type: CBUUID(string: service.uuid), primary: true)
            newService.characteristics = characteristics
            
            // 保存引用到字典，Key 使用 UUID 字符串
            registeredServices[service.uuid] = newService
            
            // 添加服务并开始广播
            peripheralManager.add(newService)
        }
        //TODO: only advertise after adding all services
        var advertisementData: [String: Any] = [
            CBAdvertisementDataLocalNameKey: peripheral.name
        ]
        
        // 建议：只取第一个服务 UUID 进行广播，以节省空间，但是LightBlue并不发布该信息
//        if let firstService = peripheral.services.first {
//            advertisementData[CBAdvertisementDataServiceUUIDsKey] = [CBUUID(string: firstService.uuid)]
//        }
        
        LogEngine.shared.log("peripheralManager: will start advertising with data: \(advertisementData)")

        peripheralManager.startAdvertising(advertisementData)
    }
    
    func updateAndRestartAdvertising(with device: VirtualPeripheral) {
        guard peripheralManager.state == .poweredOn else { return }
        
        // 1. 停止当前所有活动
        peripheralManager.stopAdvertising()
        
        startAdvertising(peripheral: device)
    }
    
    func stopAdvertising() {
        LogEngine.shared.log("peripheralManager: will stop advertising")
        guard peripheralManager.isAdvertising else { return }
        peripheralManager.stopAdvertising()
        isAdvertising = false
        currentPeripheralID = nil
    }
    
    // 辅助方法：根据 Properties 自动推断 Permissions
    private func calculatePermissions(from props: CBCharacteristicProperties) -> CBAttributePermissions {
        var permissions: CBAttributePermissions = []
        if props.contains(.read) { permissions.insert(.readable) }
        if props.contains(.write) || props.contains(.writeWithoutResponse) { permissions.insert(.writeable) }
        return permissions
    }
    
    // --- 主动推送更新 ---
    func notifyValueUpdate(for charModel: VirtualCharacteristic, with data: Data) {
        // 这里假设你在添加服务时保存了这些 mutable 对象的引用，或者根据 UUID 寻找
        // 1. 获取内存中持有的 Service 实例
        guard let service = registeredServices[charModel.serviceUUID],
              let characteristics = service.characteristics as? [CBMutableCharacteristic],
              // 2. 找到当初添加进系统的那个 char 实例
              let targetChar = characteristics.first(where: { $0.uuid.uuidString == charModel.uuid }) else {
            print("错误：未找到已注册的特征对象")
            return
        }
        
        // 3. 检查是否有订阅者（如果没有订阅者，updateValue 也会返回 false）
        if targetChar.subscribedCentrals == nil || targetChar.subscribedCentrals!.isEmpty {
            print("推送失败：当前没有中心设备订阅此特征")
            return
        }
        
        // 执行推送
        //TODO: 对于长数据此处应该分包，否则会被truncate
        let success = peripheralManager.updateValue(data, for: targetChar, onSubscribedCentrals: nil)
        if !success {
            print("推送失败：预留队列已满（需等待 peripheralManagerIsReady 信号）")
        }
    }
    
    
    // support for subcontract delivery;需要协议支持
//    private func broadcastData(_ data: Data, for characteristic: CBMutableCharacteristic) {
//        // 策略：以最弱的设备为基准分包，确保所有人都能收到
//        let chunkSize = minMTU
//        
//        // 分包发送逻辑...
//        for i in stride(from: 0, to: data.count, by: chunkSize) {
//            let end = min(i + chunkSize, data.count)
//            let chunk = data.subdata(in: i..<end)
//            
//            // onSubscribedCentrals 传 nil 表示发给所有订阅者
//            peripheralManager.updateValue(chunk, for: characteristic, onSubscribedCentrals: nil)
//        }
//    }
}

extension VirtualManager {
    
    // --- 设备管理 ---
    func removeDevice(_ device: VirtualPeripheral) {
        // 1. 检查被删的是否是当前正在运行的设备
        if self.currentPeripheralID == device.id {
            // 2. 彻底停止蓝牙活动
            peripheralManager.stopAdvertising()
            
            // 3. 核心：从硬件移除所有服务
            peripheralManager.removeAllServices()
            
            // 4. 清理内存缓存
            self.registeredServices.removeAll()
            self.currentPeripheralID = nil
        }
        removePeripheral(with: device.id)
    }
    
    
    func addDevice(_ device: VirtualPeripheral) {
        addPeripheral(device)
    }
    
    func addService(to device: VirtualPeripheral) {
        let sUUID = UUID()
        let char = VirtualCharacteristic(uuid: UUID().uuidString, properties: .read, value: "FFFF00000F0F0",serviceUUID: sUUID.uuidString)
        let service = VirtualService(uuid: sUUID.uuidString, characteristics: [char])
        addService(service, to: device.id)
        if device.isAdvertising{
            updateAndRestartAdvertising(with: device)
        }
    }
    
    func updateService(_ service: VirtualService,to device: VirtualPeripheral, with newUUID: String) {
        updateServiceUUID(peripheralID: device.id, serviceID: service.id, newUUID: newUUID)
        if device.isAdvertising{
            updateAndRestartAdvertising(with: device)
        }
    }
    
    func removeService(_ service: VirtualService, from device: VirtualPeripheral) {
        removeService(service.uuid, in: device.id)
        if device.isAdvertising{
            updateAndRestartAdvertising(with: device)
        }
    }
    
    func addCharacteristic(in service: VirtualService, to device: VirtualPeripheral) {
        let char = VirtualCharacteristic(uuid: UUID().uuidString, properties: .read, value: "FFFF00000F0F0", serviceUUID: service.uuid)
        addCharacteristic(char, in: service.uuid, to: device.id)
        if device.isAdvertising {
            updateAndRestartAdvertising(with: device)
        }
    }
    
    func removeCharacteristic(_ characteristic: VirtualCharacteristic, from device: VirtualPeripheral) {
        removeCharacteristic(characteristic.uuid, in: characteristic.serviceUUID, to: device.id)
        if device.isAdvertising {
            updateAndRestartAdvertising(with: device)
        }
    }
    
    // 此时调用 updateLocalStore 就能找到 deviceStore 了
    func updateCharacteristicValue(for charUUID: CBUUID, with hexString: String) {
        guard let deviceID = currentPeripheral?.id else { return }
        updateCharacteristicValue(
            peripheralID: deviceID,
            charUUID: charUUID.uuidString,
            newHex: hexString
        )
    }
    
    // 3. 统一的操作入口
    private func addPeripheral(_ peripheral: VirtualPeripheral) {
        savedDevices.append(peripheral)
    }
    
    private func removePeripheral(with id: UUID) {
        savedDevices.removeAll(where: { $0.id == id })
    }
    
    private func addService(_ service: VirtualService, to peripheralID: UUID) {
        guard let pIndex = savedDevices.firstIndex(where: { $0.id == peripheralID }) else { return }
        savedDevices[pIndex].services.append(service)
    }
    
    private func removeService(_ serviceID: String, in peripheralID: UUID) {
        guard let pIndex = savedDevices.firstIndex(where: { $0.id == peripheralID }) else { return }
        savedDevices[pIndex].services.removeAll(where: { $0.uuid == serviceID })
    }
    
    private func addCharacteristic(_ characteristic: VirtualCharacteristic, in serviceID: String, to peripheralID: UUID) {
        guard let pIndex = savedDevices.firstIndex(where: { $0.id == peripheralID }),
              let sIndex = savedDevices[pIndex].services.firstIndex(where: { $0.uuid == serviceID }) else { return }
        savedDevices[pIndex].services[sIndex].characteristics.append(characteristic)
    }
    
    private func removeCharacteristic(_ charID: String, in serviceID: String, to peripheralID: UUID) {
        guard let pIndex = savedDevices.firstIndex(where: { $0.id == peripheralID }),
              let sIndex = savedDevices[pIndex].services.firstIndex(where: { $0.uuid == serviceID }) else { return }
        savedDevices[pIndex].services[sIndex].characteristics.removeAll(where: { $0.uuid == charID})
    }
    
    /// 根据 UUID 路径定位并更新特征的 Hex 值
    private func updateCharacteristicValue(peripheralID: UUID, charUUID: String, newHex: String) {
        // 1. 定位外设
        guard let pIndex = savedDevices.firstIndex(where: { $0.id == peripheralID }) else { return }
        
        // 2. 遍历服务查找对应的特征（因为一个 UUID 可能存在于多个服务中，通常更新匹配到的第一个）
        for sIndex in savedDevices[pIndex].services.indices {
            if let cIndex = savedDevices[pIndex].services[sIndex].characteristics.firstIndex(where: { $0.uuid.uppercased() == charUUID.uppercased() }) {
                
                // 3. 更新内存中的值
                savedDevices[pIndex].services[sIndex].characteristics[cIndex].value = newHex
                            
                print("成功同步数据到存储: [\(charUUID)] -> \(newHex)")
                return
            }
        }
    }
    
    /// 更新 Service UUID 及其关联的所有特征
    private func updateServiceUUID(peripheralID: UUID, serviceID: UUID, newUUID: String) {
        guard let pIndex = savedDevices.firstIndex(where: { $0.id == peripheralID }),
              let sIndex = savedDevices[pIndex].services.firstIndex(where: { $0.id == serviceID }) else { return }
        
        // 1. 更新 Service 本身的 UUID
        savedDevices[pIndex].services[sIndex].uuid = newUUID
        
        // 2. 自动同步该服务下所有特征的 serviceUUID 字段
        for cIndex in savedDevices[pIndex].services[sIndex].characteristics.indices {
            savedDevices[pIndex].services[sIndex].characteristics[cIndex].serviceUUID = newUUID
        }
    }
}

extension VirtualManager: CBPeripheralManagerDelegate{
    // --- Delegate 代理方法 ---
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        LogEngine.shared.log("peripheralManager: will change state to \(peripheral.state.description) from \(bluetoothState.description)")

        self.bluetoothState = peripheral.state
    }
    
    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        willRestoreState dict: [String : Any]
    ){}
    
    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        didAdd service: CBService,
        error: (any Error)?
    ){
        print("Peripheral Manager --> didAddService")
        if let error {
            print("Peripheral Manager --> Fail to add service Error:\(error.localizedDescription)")
            //停止广播
            DispatchQueue.main.async {
                // 触发错误显示
                self.errorMessage = getReadableError(error)
                self.showErrorAlert = true
                
                // 失败时应重置 UI 上的广播开关
                // 你可以根据需要在这里重置 isAdvertising 状态
                if let index = self.savedDevices.firstIndex(where: { vp in
                    vp.id == self.currentPeripheral?.id
                }){
                    self.savedDevices[index].isAdvertising = false
                }
                self.stopAdvertising()
            }
        } else {
            LogEngine.shared.log("peripheralManager: did add service: \(service.uuid.uuidString)")

            print("服务添加成功: \(service.uuid)")
            // 当所有服务都添加完成后再启动广播（简单处理：检查是否还有待添加的服务）
            // 实际开发中如果服务多，可以计数。这里我们直接尝试启动
            //            if !peripheral.isAdvertising, let adData = pendingAdData {
            //                peripheral.startAdvertising(adData)
            //                pendingAdData = nil // 清空
            //            }
        }
    }
    
    // i'm advertising
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        print("Peripheral Manager --> didStartAdvertising")
        if let error {
            print(error.localizedDescription)
            return
        }
        LogEngine.shared.log("peripheralManager: add start advertising")
        DispatchQueue.main.async { self.isAdvertising = true }
    }
    
    //Subscribe to me
    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        central: CBCentral,
        didSubscribeTo characteristic: CBCharacteristic
    ){
        let charUUID = characteristic.uuid
        var subscribers = subscribedCentrals[charUUID] ?? []
        subscribers.insert(central.identifier)
        subscribedCentrals[charUUID] = subscribers
        
        let mtu = central.maximumUpdateValueLength
        centralMTUs[central.identifier] = mtu
        
        print("特征 \(charUUID) 收到新订阅, central maximumUpdateValueLength:\(central.maximumUpdateValueLength)")
    }
    
    //Unsubscribe from me
    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        central: CBCentral,
        didUnsubscribeFrom characteristic: CBCharacteristic
    ){
        let charUUID = characteristic.uuid
        subscribedCentrals[charUUID]?.remove(central.identifier)
        centralMTUs.removeValue(forKey: central.identifier)
        print("特征 \(charUUID) 取消订阅")
    }
    
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager){
        print("peripheral Manager Is Ready")
    }
    
    /*
     进阶方案：使用“订阅/通知”模式
     对于大数据传输，读取（Read）模式的效率非常低（每轮请求都有往返延迟）。业内更推荐的做法是：
     中心设备订阅（Notify）特征值。
     外设通过 updateValue(_:for:onSubscribedCentrals:) 主动推送数据。
     外设自己负责将数据切片（根据 central.maximumUpdateValueLength），循环发送。
     */
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        // 从你的数据模型（比如 VirtualChar.hexValue）中获取最新的 Data
        guard let currentPeripheral else { return }
        
        // 2. 匹配特征并处理逻辑
        var characteristic: VirtualCharacteristic?
        
        for service in currentPeripheral.services{
            if let char = service.characteristics.first(where: { c in
                CBUUID(string: c.uuid) == request.characteristic.uuid
            }){
                characteristic = char
            }
        }
        
        guard let characteristic else {
            peripheralManager.respond(to: request, withResult: .attributeNotFound)
            return
        }
        //如果你返回的数据超过 20 字节（MTU 限制），中心设备可能会发起多次 offset 不为 0 的请求
        let dataToReturn = characteristic.value
        let fullData = dataToReturn.hexToData ?? Data()
        // 检查偏移量，防止越界
        if request.offset > fullData.count {
            peripheral.respond(to: request, withResult: .invalidOffset)
            return
        }
        // 截取数据并填充给 request
        let range = Range(uncheckedBounds: (request.offset, fullData.count))
        request.value = fullData.subdata(in: range)
        
        // 必须响应成功
        peripheralManager.respond(to: request, withResult: .success)
    }
    
    //对于超长的数据应该协议分包界定，然后多次write；对于MTU和最大写入长度之间的数据可简单处理offset
    /*
     与处理读取请求的方式相同，每次收到回调时，都必须严格只调用一次 `CBPeripheralManager` 类的 `respond(to: withResult:)` 方法。如果 `requests` 参数中包含多个请求，应将其视为一个单独的请求来处理：如果无法完成某个具体的请求，那么就不应该尝试完成任何请求，而应立即调用 `respond(to: withResult:)` 方法，并提供一个说明失败原因的结果。

     在处理写入请求时，请注意：虽然 `peripheralManager(_:didReceiveWrite:)` 方法返回的是一个包含多个 `CBATTRequest` 对象的数组，但 `respond(to: withResult:)` 方法的第一个参数实际上只需要接收其中一个 `CBATTRequest` 对象。因此，在调用该方法时，只需传递数组中的第一个请求即可。
     */
    //FIXME: 不清楚requests何时会出现多个
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        guard let currentPeripheral else { return }
        guard let firstRequest = requests.first else { return }
        
        
        /* 支持带offset的多characteristic，但是不支持乱序情况。乱序需要分组排序。
        let grouped = Dictionary(grouping: requests) { $0.characteristic }
        for (characteristic, charRequests) in grouped {
            // 组内排序，确保处理逻辑线性
            let sortedRequests = charRequests.sorted { $0.offset < $1.offset }
            // 验证所有 Offset 的连续性/合法性
            for request in sortedRequests {
            }
        }
        */
        for request in requests {
            // 1. 检查数据是否存在
            guard let newValue = request.value else {
                peripheralManager.respond(to: request, withResult: .invalidAttributeValueLength)
                return
            }
            
            // 2. 匹配特征并处理逻辑
            var found = false
            
            for service in currentPeripheral.services{
                if let _ = service.characteristics.first(where: { c in
                    CBUUID(string: c.uuid) == request.characteristic.uuid
                }){
                    found = true
                }
            }
            
            guard found else {
                // 如果是不支持的特征
                peripheralManager.respond(to: request, withResult: .attributeNotFound)
                return
            }
            
            let char = request.characteristic as! CBMutableCharacteristic
            // 准备可变的数据容器
            var mutableData = char.value ?? Data()
            
            // 计算写入范围：从 offset 开始，长度为 newValue 的长度
            let range = request.offset..<(request.offset + newValue.count)
            
            if request.offset > mutableData.count{
                peripheral.respond(to: firstRequest, withResult: .invalidOffset)
                return
            }
            if request.offset == mutableData.count {
                mutableData.append(newValue)
            }else{
                //range可能超出mutableData范围
                //mutableData.replaceSubrange(range, with: newValue)
            }
            
            // 更新特征值
            char.value = mutableData
            
//            let centralID = request.central.identifier

            // 1. 如果 offset 为 0，说明是新的一段数据或单包数据
//            if request.offset == 0 {
//                writeBuffers[centralID] = newValue
//            } else {
//                // 2. 如果 offset > 0，说明是续接之前的长数据
//                // 在生产环境中，建议校验 offset 是否等于 writeBuffer.count 以防数据包乱序或丢失
//                if var existingData = writeBuffers[centralID] {
//                    // 理论上 offset 应该等于当前已收到的数据长度
//                    let offset = request.offset
//                    if offset <= existingData.count {
//                        // 处理覆盖写入或追加写入
//                        let range = offset..<(offset + newValue.count)
//                        if offset == existingData.count {
//                            existingData.append(newValue)
//                        } else {
//                            // 如果 offset 小于当前长度，替换对应部分
//                            existingData.replaceSubrange(range, with: newValue)
//                        }
//                        writeBuffers[centralID] = existingData
//                    }else{
//                        peripheralManager.respond(to: request, withResult: .invalidAttributeValueLength)
//                        return
//                    }
//                }
//            }
            // 将 Data 转换为 Hex 字符串并存入你的 VirtualDeviceStore
            let hexString = mutableData.map { String(format: "%02X", $0) }.joined()
            
            DispatchQueue.main.async {
                // 更新 UI 绑定的数据模型，这样你在 HexValueView 就能看到变化
                self.updateCharacteristicValue(for: request.characteristic.uuid, with: hexString)
            }
        }
         
        // 2. 统一回应（通常针对数组中的第一个请求进行 respond 即可代表整个批次）
        // 3. 必须响应请求 (非常重要！)
        // 如果是 Write with Response，中心设备会等待这个 success 信号
        peripheral.respond(to: firstRequest, withResult: .success)
    }
    
}
