//
//  DCBluetooth.h
//  Hardbox
//
//  Created by Dalmo Cirne on 4/6/13.
//  Copyright (c) 2013 Dalmo Cirne. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CBPeripheral;

@protocol DCBluetoothDelegate;

@interface DCBluetooth : NSObject

@property (nonatomic, strong) CBPeripheral *peripheral;
@property (nonatomic, weak) id<DCBluetoothDelegate> delegate;

- (void)findBluetoothPeripherals:(NSTimeInterval)timeout;
- (void)connect:(CBPeripheral *)peripheral;
- (void)disconnect;
- (void)write:(NSData *)data;

@end

@protocol DCBluetoothDelegate <NSObject>
- (void)bluetoothDidConnect;
- (void)bluetoothDidDisconnect;
@end