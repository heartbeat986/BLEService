//
//  BLEService.swift
//  BLEService
//
//  Created by 焦星星 on 2020/7/2.
//  Copyright © 2020 jxx. All rights reserved.
//

import UIKit
import CoreBluetooth

public enum BLEState:Int {
    case BLEStateOK = -1
    case BLEStateUnknown
    case BLEStateResetting
    case BLEStateUnsupported
    case BLEStateUnauthorized
    case BLEStatePoweredOff
    case BLEStatePoweredOn
    case BLEStateTimeOut
    case BLEStateDisconnect
    case BLEStateFailToConnect
}

public protocol BLEServiceDelegate {
    func onBLEService(_ service:BLEService,
                      isConnect:Bool,
                      stateCode:BLEState,
                      connectError:Error?) -> Void;
    func onBLEService(_ service:BLEService,
                      isWriteSuccess:Bool,
                      error:Error?) -> Void;
    func onBLEService(_ service:BLEService,
                      recive Data:[UInt8],
                       withLength Length:Int) -> Void;
    func onBLEService(_ service:BLEService,
                      deviceList:[String]) -> Void;
}


open class BLEService:NSObject,CBCentralManagerDelegate, CBPeripheralDelegate {
    static let shared = BLEService();
    /**
     * SERVICE UUID
     */
    private let BLE_SERVICE_UUID = "0000e0ff-3c17-d293-8e48-14fe2e4da212";
    /**
     * NOTIFY UUID
     */
    private let BLE_NOTIFY_UUID = "0000ffe1-0000-1000-8000-00805f9b34fb";
    /**
     *WRITE UUID
     */
    private let BLE_WRITE_UUID = "0000ffe9-0000-1000-8000-00805f9b34fb";
    /** Default Scan duration,10 seconds */
    private let _defaultDuration:Double = 10;
    private var _connectCount:TimeInterval = 0;
    private var centerManager:CBCentralManager? = nil;
    private var connectedPeripheral:CBPeripheral?;
    private var dataList:NSMutableDictionary = {
        return NSMutableDictionary.init();
    }();
    private var connectTimer:DispatchSourceTimer? = nil;
    private var writeCharacteristic:CBCharacteristic? = nil;
    private var notifyCharacteristic:CBCharacteristic? = nil;
    public var delegate:BLEServiceDelegate?;
    
    private override init() {}
    
    /**
    * 初始化SDK
    */
    public static func sharedInstance() -> BLEService{
        shared.centerManager = CBCentralManager.init(delegate: shared, queue: nil);
        
        return self.shared;
    }

    func startScan() {
        self.centerManager?.scanForPeripherals(withServices: nil, options: nil);
    }
    
    private func cancelConnectTimer() {
        self.getTimer()?.cancel();
        _connectCount = 0;
        connectTimer = nil;
    }
    
      /// 开始连接蓝牙设备
      ///
      /// - Parameters:
      ///   - name: 要连接的蓝牙设备名称
    open func startToConnect(deviceName name:String) {
        let beConnectedPeripheral:CBPeripheral = self.dataList.object(forKey: name) as! CBPeripheral;
        centerManager!.connect(beConnectedPeripheral, options: nil);
        if(_connectCount > 0){
            self.cancelConnectTimer();
        }
        // 开始连接设备
        self.getTimer()?.resume();
    }
    
   
    /// 主动与蓝牙设备断开连接
    open func disConnectDevice (){
        if self.connectedPeripheral != nil {
            self.centerManager?.cancelPeripheralConnection(self.connectedPeripheral!);
        }
    }
    
    /// 向蓝牙设备写数据
    ///
    /// - Parameters:
    ///   - bytes: 要发送的字节数组
    ///   - length: 字节数组长度
    ///
    public func writeData(_ bytes:[UInt8], with length:Int ){
        let byteData:NSData = NSData(bytes: bytes, length: length);
        connectedPeripheral?.writeValue(byteData as Data, for: writeCharacteristic!, type: CBCharacteristicWriteType.withResponse);
    }
    
    /// 获取扫描到的蓝牙设备
    ///
    /// - returns: 蓝牙设备名称列表
    public func getDeviceList()->[String]{
        return dataList.allKeys as! [String];
    }
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case CBManagerState.unknown:
            delegate?.onBLEService(self, isConnect:false,
                                   stateCode:BLEState.BLEStateUnknown,
                                   connectError:nil);
        case CBManagerState.resetting:
            delegate?.onBLEService(self,
                                   isConnect:false,
                                   stateCode:BLEState.BLEStateResetting,
                                   connectError:nil);
        case CBManagerState.unsupported:
            delegate?.onBLEService(self,
                                   isConnect:false,
                                   stateCode:BLEState.BLEStateUnsupported,
                                   connectError:nil);
        case CBManagerState.unauthorized:
            delegate?.onBLEService(self,
                                   isConnect:false,
                                   stateCode:BLEState.BLEStateUnauthorized,
                                   connectError:nil);
        case CBManagerState.poweredOff:
             delegate?.onBLEService(self,
                                    isConnect:false,
                                    stateCode:BLEState.BLEStatePoweredOff,
                                    connectError:nil);
        case CBManagerState.poweredOn:
            delegate?.onBLEService(self,
                                   isConnect:false,
                                   stateCode:BLEState.BLEStatePoweredOn,
                                   connectError:nil);
             self.startScan();
        default:
            break
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let keyArray = dataList.allKeys;
        if peripheral.name == nil {return};
        let isContain = keyArray.contains { (element) -> Bool in
            if  element is String {
                let name = element as! String;
                if peripheral.name == name {
                    return true;
                } else{
                    return false;
                }
            } else {
                return false;
            }
        };
        if isContain == false {
            let obj:[String:Any] = [peripheral.name!:peripheral];
            dataList.addEntries(from: obj);
            delegate?.onBLEService(self, deviceList:self.getDeviceList());
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        self.cancelConnectTimer();
        self.connectedPeripheral = peripheral;
        self.centerManager?.stopScan();
        self.connectedPeripheral?.delegate = self;
        let serviceUUID = CBUUID.init(string:BLE_SERVICE_UUID);
        peripheral.discoverServices([serviceUUID]);
        delegate?.onBLEService(self,
                               isConnect:true,
                               stateCode:BLEState.BLEStateOK,
                               connectError:nil);
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        self.cancelConnectTimer();
        delegate?.onBLEService(self,
                               isConnect:false,
                               stateCode:BLEState.BLEStateFailToConnect,
                               connectError:error);
    }
    
    
    // #pragma -mark  PeripheralDelegate
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if peripheral.services!.count > 0  {
            let writeUUID:CBUUID = CBUUID.init(string: BLE_WRITE_UUID);
            let notifyUUID:CBUUID = CBUUID.init(string: BLE_NOTIFY_UUID);
            peripheral.discoverCharacteristics([writeUUID,notifyUUID], for: peripheral.services![0]);
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        self.dataList.removeAllObjects();
        self.startScan();
        delegate?.onBLEService(self,
                               isConnect:false,
                               stateCode:BLEState.BLEStateDisconnect,
                               connectError:error);
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        let writeUUID:CBUUID = CBUUID.init(string: BLE_WRITE_UUID);
        let notifyUUID:CBUUID = CBUUID.init(string: BLE_NOTIFY_UUID);
        if service.characteristics!.count > 1 {
            let first:CBCharacteristic = service.characteristics![0];
            if (first.uuid.isEqual(writeUUID)) {
                self.writeCharacteristic = service.characteristics![0];
                self.notifyCharacteristic = service.characteristics![1];
            }else if(first.uuid.isEqual(notifyUUID)){
                self.notifyCharacteristic = service.characteristics![0];
                self.writeCharacteristic = service.characteristics![1];
            }
            peripheral.setNotifyValue(true, for: self.notifyCharacteristic!);
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        let isSuccess:Bool = error == nil ? true : false;
        delegate?.onBLEService(self,
                               isWriteSuccess:isSuccess,
                               error:error);
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic.isEqual(self.notifyCharacteristic) && characteristic.isNotifying {
            if characteristic.value != nil {
                let data = characteristic.value;
                let nsdata = NSData.init(data: data!);
                var byteArray:[UInt8] = [UInt8]()
                for i in 0..<data!.count {
                    var temp:UInt8 = 0;
                    nsdata.getBytes(&temp, range: NSRange(location: i,length:1 ));
                    byteArray.append(temp);
                }
                delegate?.onBLEService(self,recive:byteArray, withLength:Int(data!.count));
            } else {
                delegate?.onBLEService(self,recive:[UInt8](), withLength:0);
            }
        }
    }
    
    func getTimer()->DispatchSourceTimer? {
        if connectTimer == nil {
            let timer = DispatchSource.makeTimerSource(flags: [], queue: DispatchQueue.global());
            timer.schedule(deadline: DispatchTime.now(),
                           repeating: DispatchTimeInterval.seconds(1),
                           leeway: DispatchTimeInterval.seconds(0));
            timer.setEventHandler(handler: {
                self._connectCount = self._connectCount + 1;
                if (self._connectCount == self._defaultDuration) {
                    print("到时间断开");
                    self.cancelConnectTimer();
                    DispatchQueue.main.async {
                        self.delegate?.onBLEService(self,
                                                    isConnect: false,
                                                    stateCode:BLEState.BLEStateTimeOut,
                                                    connectError:nil);
                    }
                 }
            })
            self.connectTimer = timer;
            return timer;
        }else {
            return self.connectTimer;
        }
    }
}
