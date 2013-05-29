//
//  DCViewController.m
//  Hardbox
//
//  Created by Dalmo Cirne on 4/1/13.
//  Copyright (c) 2013 Dalmo Cirne. All rights reserved.
//

#import "DCViewController.h"
#import <CoreMotion/CoreMotion.h>
#import <dispatch/dispatch.h>
#import <QuartzCore/QuartzCore.h>
#import "DCBluetooth.h"

#define ACCELERATION_FILTER 0.35
#define NUMBER_OF_LEDS 7
#define LEDS_OFF 255

static UIColor *greenColor;
static UIColor *redColor;
const NSTimeInterval timeout = 3.0;

@interface DCViewController() <DCBluetoothDelegate> {
    IBOutlet UIView *ledView;
    IBOutlet UIActivityIndicatorView *activityIndicator;
    
    NSOperationQueue *motionQueue;
    UIAccelerationValue yAcceleration;
    CGFloat maxSlidingDistance;
    CGFloat maxDistance;
    CGFloat xMin;
    CGFloat xMax;
    Byte activeLed;
    Byte centerLed;
    DCBluetooth *bluetooth;
}

@property (nonatomic, strong) CMMotionManager *motionManager;

@end


@implementation DCViewController

+ (void)initialize {
    greenColor = [UIColor colorWithRed:0.05 green:0.8 blue:0.2 alpha:1];
    redColor = [UIColor colorWithRed:0.85 green:0 blue:0.1 alpha:1];
}

- (void)awakeFromNib {
    [super awakeFromNib];
    
    activeLed = 0;
    centerLed = (Byte)floor(NUMBER_OF_LEDS / 2.0);
    yAcceleration = FLT_MAX;
    motionQueue = [[NSOperationQueue alloc] init];

    bluetooth = [[DCBluetooth alloc] init];
    bluetooth.delegate = self;
    
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self
                           selector:@selector(handleApplicationDidEnterBackground:)
                               name:UIApplicationDidEnterBackgroundNotification
                             object:nil];
    
    [notificationCenter addObserver:self
                           selector:@selector(handleApplicationWillEnterForeground:)
                               name:UIApplicationWillEnterForegroundNotification
                             object:nil];
}

- (void)dealloc {
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    [notificationCenter removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    ledView.hidden = YES;
    
    CGFloat radius = ledView.bounds.size.height / 2.0;
    [ledView.layer setCornerRadius:radius];
    
    double delayInSeconds = 1.1;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^{
        CGFloat padding = [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad ? 200.0f : 100.0f;
        maxSlidingDistance = self.view.bounds.size.width - padding;
        maxDistance = maxSlidingDistance / 2.0;
        CGRect frame = ledView.frame;
        frame.size.width = maxDistance / ((CGFloat)NUMBER_OF_LEDS / 2.0);
        ledView.frame = frame;
        xMin = self.view.center.y - maxDistance;
        xMax = self.view.center.y + maxDistance;
        [self startMonitoringDeviceMotion];
        
        [self connectToHardbox];
    });
}

#pragma mark Motion
- (CMMotionManager *)motionManager {
    if (!_motionManager) {
        _motionManager = [[CMMotionManager alloc] init];
    }
    
    return _motionManager;
}

- (void)startMonitoringDeviceMotion {
    self.motionManager.accelerometerUpdateInterval = 0.05;
    [self.motionManager startAccelerometerUpdatesToQueue:motionQueue
                                             withHandler:^(CMAccelerometerData *accelerometerData, NSError *error) {
                                                 [self handleDeviceAcceleration:accelerometerData error:error];
                                             }];
}

- (void)stopMonitoringDeviceMotion {
    if (_motionManager && _motionManager.accelerometerActive) {
        [_motionManager stopAccelerometerUpdates];
    }
}

- (void)handleDeviceAcceleration:(CMAccelerometerData *)accelerometerData error:(NSError *)error {
    CGPoint centerPoint = CGPointMake(self.view.center.y, self.view.center.x);
    yAcceleration = (yAcceleration != FLT_MAX) ? (accelerometerData.acceleration.y * ACCELERATION_FILTER) + (yAcceleration * (1.0 - ACCELERATION_FILTER)) : accelerometerData.acceleration.y;
    double distance = maxDistance * yAcceleration;
    double direction = [UIApplication sharedApplication].statusBarOrientation == UIInterfaceOrientationLandscapeLeft ? 1.0 : -1.0;
    centerPoint.x += distance * direction;
    [self calculateActiveLedForPosition:centerPoint.x];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        ledView.center = centerPoint;
    });
}

#pragma mark Gesture recognizer
- (IBAction)handleLedPressedGesture:(UILongPressGestureRecognizer *)sender {
    CGPoint centerPoint = CGPointZero;
    
    switch (sender.state) {
        case UIGestureRecognizerStateBegan:
            [self stopMonitoringDeviceMotion];
            
        case UIGestureRecognizerStateChanged: {
            centerPoint = CGPointMake(self.view.center.y, self.view.center.x);
            CGPoint touchPoint = [sender locationInView:self.view];
            centerPoint.x = touchPoint.x;
            if (centerPoint.x < xMin) {
                centerPoint.x = xMin;
            } else if (centerPoint.x > xMax) {
                centerPoint.x = xMax;
            }
            
            [self calculateActiveLedForPosition:centerPoint.x];
        }
            break;
            
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateEnded:
            yAcceleration = FLT_MAX;
            [self startMonitoringDeviceMotion];
            
        default:
            return;
            break;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        ledView.center = centerPoint;
    });
}

#pragma mark Private methods
- (void)calculateActiveLedForPosition:(CGFloat)xCoordinate {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        double delta = xCoordinate - xMin;
        if (delta > maxSlidingDistance - 25.0) {
            delta = ledView.bounds.size.width * NUMBER_OF_LEDS;
        }
        
        Byte calculatedActiveLed = NUMBER_OF_LEDS - (Byte)floor(delta / ledView.bounds.size.width) - 1;
        if (calculatedActiveLed == activeLed) {
            return;
        }
        
        activeLed = calculatedActiveLed;
        UIColor *ledColor = activeLed == centerLed ? greenColor : redColor;
        [self sendActiveLed];
        dispatch_async(dispatch_get_main_queue(), ^{
            [ledView setBackgroundColor:ledColor];
        });
    });
}

#pragma mark Notification handlers
- (void)handleApplicationDidEnterBackground:(NSNotification *)notification {
    [self stopMonitoringDeviceMotion];
    [self setMotionManager:nil];
    
    activeLed = LEDS_OFF;
    [self sendActiveLed];
    
    double delayInSeconds = 0.01;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^{
        [self disconnectFromHardbox];
    });
}

- (void)handleApplicationWillEnterForeground:(NSNotification *)notification {
    [self startMonitoringDeviceMotion];
    
    [self connectToHardbox];
}

#pragma mark Bluetooth LE methods
- (void)connectToHardbox {
    if (!activityIndicator.isAnimating) {
        [activityIndicator startAnimating];
    }
    
    if (bluetooth.peripheral) {
        [self disconnectFromHardbox];
        [bluetooth setPeripheral:nil];
    }
    
    [bluetooth findBluetoothPeripherals:timeout];
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)((timeout + 0.01) * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^{
        if (bluetooth.peripheral) {
            [bluetooth connect:bluetooth.peripheral];
        } else {
            [self connectToHardbox];
        }
    });
}

- (void)disconnectFromHardbox {
    [bluetooth disconnect];
}

- (void)sendActiveLed {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        Byte buf[1] = {activeLed};
        NSData *data = [[NSData alloc] initWithBytes:buf length:1];
        [bluetooth write:data];
    });
}

#pragma mark DCBluetoothDelegate methods
- (void)bluetoothDidConnect {
    activeLed = centerLed;
    [self sendActiveLed];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [activityIndicator stopAnimating];
        ledView.hidden = NO;
    });
}

- (void)bluetoothDidDisconnect {
    dispatch_async(dispatch_get_main_queue(), ^{
        ledView.hidden = YES;
        [self connectToHardbox];
    });
}

@end
