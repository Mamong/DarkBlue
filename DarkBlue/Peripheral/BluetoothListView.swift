//
//  BluetoothListView.swift
//  DarkBlue
//
//  Created by Marco on 2026/4/17.
//
import SwiftUI
import CoreBluetooth

struct BluetoothListView: View {
    @StateObject var bluetoothManager = BluetoothManager()
    @State private var isShowingDetail = false
    @State private var searchText = ""
    @State private var selectedPeripheral: CBPeripheral?

    // 用于控制键盘和焦点状态
    @FocusState private var isSearching: Bool
    
    // 引入过滤状态（从 AppStorage 读取，确保与设置页同步）
    @AppStorage("isRssiFilterEnabled") var isFilterEnabled = false
    @AppStorage("minRssiThreshold") var minRssiThreshold: Double = -100
    
    var body: some View {
        let _ = Self._printChanges()

        NavigationStack {
            ZStack{
                VStack(spacing: 0) {
                    customHeader
                    
                    customSearchBar
                    
                    List {
                        Section{
                            ForEach(filteredDevices) { device in
                                PeripheralRow(
                                    device: device,
                                    onConnect: {
                                        selectedPeripheral = device.peripheral
                                        bluetoothManager.connect(to: device.peripheral)
                                    }
                                )
                                .listRowInsets(.none)
                            }
                            // 如果过滤后列表为空，显示占位图
                            if filteredDevices.isEmpty && !bluetoothManager.isScanning {
                                emptyPlaceholder
                            }
                        }
                    }
                    .listStyle(.plain)
                    .navigationDestination(isPresented: $isShowingDetail){
                        if let peripheral = selectedPeripheral {
                            PeripheralDetailView(peripheral: peripheral) // 此时 peripheral 是非可选的
                        }else{
                            Text("PeripheralDetailView")
                        }
                    }
                    
                    // 3. 监听连接成功状态
                    .onChange(of: bluetoothManager.connectState) { connectState in
                        if connectState == .negotiated {
                            //self.selectedPeripheral = bluetoothManager.connectedPeripheral
                            self.isShowingDetail = true
                        }
                    }
                    .refreshable {
                        bluetoothManager.startScan()
                    }
                }
                if [.connecting, .connected, .negotiating].contains(bluetoothManager.connectState){
                    ConnectionOverlay(title: bluetoothManager.connectState == .connecting ? "Connecting....":"Interrogating...", subtitle: selectedPeripheral?.name ?? "Unnamed"){
                        bluetoothManager.cancelConnection()
                    }
                }
            }
#if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
#endif
            .onAppear{
                bluetoothManager.disconnect(peripheral: bluetoothManager.connectedPeripheral)
                bluetoothManager.resumeScan()
            }
            .onDisappear{
                bluetoothManager.stopScan()
            }
        }
#if os(iOS)
        .toolbarBackground(Color.lbSkyBlue, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar) // Makes title white
#endif
        .tint(.white)
        .environmentObject(bluetoothManager)
    }
    
    // 计算属性：处理【搜索】和【RSSI 过滤】的双重筛选
    var filteredDevices: [DiscoveredPeripheral] {
        bluetoothManager.discoveredDevices.filter { device in
            // 1. RSSI 过滤逻辑
            let satisfiesRssi = !isFilterEnabled || Double(device.rssi) >= minRssiThreshold
            
            // 2. 搜索框过滤逻辑
            let name = device.peripheral.name ?? "Unnamed"
            let satisfiesSearch = searchText.isEmpty || name.localizedCaseInsensitiveContains(searchText)
            
            return satisfiesRssi && satisfiesSearch
        }
    }
    
    var customHeader: some View {
        ZStack{
            Color.lbSkyBlue.ignoresSafeArea(edges: .top)
            HStack {
                Text("DarkBlue")
                    .font(.title)
                Spacer()
                HStack(spacing: 20) {
                    // 针对 macOS/Catalyst 按钮刷新
#if targetEnvironment(macCatalyst) || os(macOS)
                    Button(action:{
                        bluetoothManager.startScan()
                    }){
                        Image(systemName: "arrow.clockwise")
                    }
#endif
                    Button(action:{
                        bluetoothManager.sortCurrentList()
                    }){
                        Image(systemName: "line.3.horizontal.decrease")
                    }
                    NavigationLink(destination: PeripheralFilteringView()){
                        Image(systemName: isFilterEnabled ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 44)
        .foregroundColor(.white)
    }
    
    // 自定义搜索框组件
    var customSearchBar: some View {
        VStack(alignment: .leading) {
            HStack {
                Group{
                    if isFilterEnabled {
                        Text("Peripherals Nearby (\(filteredDevices.count) of \(bluetoothManager.discoveredDevices.count))")
                    }else{
                        Text("Peripherals Nearby")
                    }
                }
                .font(.title3)
                .foregroundColor(.gray)
                Image(systemName: "info.circle.fill")
                    .font(.title3)
                    .foregroundColor(.gray)
                Spacer()
            }
            // 过滤条件行：只有在开启过滤时显示
            if isFilterEnabled {
                let bars = rssiToBars(Int(minRssiThreshold))
                Text("Min RSSI Set: \(Int(minRssiThreshold)) dB (\(bars) \(bars <= 1 ? "bar" : "bars"))")
                    .padding(.vertical, 6)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            
            HStack{
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search peripherals by name", text: $searchText)
                        .focused($isSearching)
                        .textFieldStyle(.plain)
                        .font(.callout)
                }
                .padding(8)
                .background(Color.adaptiveSystemGray6)
                .cornerRadius(8)
                
                // 只有在搜索状态（有焦点）时才显示 Cancel 按钮
                if isSearching {
                    Button("Cancel") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            searchText = ""
                            isSearching = false // 移除焦点，隐藏键盘
                        }
                    }
                    .padding(.leading, 12)
                    .transition(.move(edge: .trailing).combined(with: .opacity)) // 从右侧滑入
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color.white) // 确保搜索框背景不透明
        // 添加一个细微的底边线，模拟原图层次感
        .overlay(Divider().alignmentGuide(.bottom) { $0[.bottom] }, alignment: .bottom)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isSearching)
    }
    
    var emptyPlaceholder: some View {
        HStack{
            Spacer()
            VStack(spacing: 10) {
                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                    .font(.largeTitle)
                Text("没有符合条件的设备")
            }
            .foregroundColor(.secondary)
            .padding(.top, 50)
            Spacer()
        }
    }
}
