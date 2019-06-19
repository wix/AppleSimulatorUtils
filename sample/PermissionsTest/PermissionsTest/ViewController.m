//
//  ViewController.m
//  PermissionsTest
//
//  Created by Leo Natan (Wix) on 12/9/18.
//  Copyright © 2018 Leo Natan. All rights reserved.
//

#import "ViewController.h"
@import EventKit;
@import CoreLocation;
@import UserNotifications;
@import HealthKit;

@interface ViewController () <CLLocationManagerDelegate>
{
	EKEventStore* _eventStore;
	CLLocationManager* _locationManager;
	HKHealthStore* _healthStore;
}

@end

@implementation ViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	_eventStore = [EKEventStore new];
	_locationManager = [CLLocationManager new];
	_locationManager.delegate = self;
	
	_healthStore = [HKHealthStore new];
	
	NSLog(@"%@", NSBundle.mainBundle.bundleURL.absoluteString);
}

- (IBAction)_location:(id)sender
{
	[_locationManager requestAlwaysAuthorization];
}

- (IBAction)_calendar:(id)sender
{
	[_eventStore requestAccessToEntityType:EKEntityTypeEvent completion:^(BOOL granted, NSError * _Nullable error) {
		NSLog(@"Calendar: %@", granted ? @"<granted>" : @"<not granted>");
	}];
}

- (IBAction)_notifications:(id)sender
{
	UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
	[center requestAuthorizationWithOptions: UNAuthorizationOptionAlert | UNAuthorizationOptionSound completionHandler:^(BOOL granted, NSError * _Nullable error) {
		NSLog(@"Notifications: %@", granted ? @"<granted>" : @"<not granted>");
	}];
}

- (IBAction)_health:(id)sender
{
//	NSSet* writableTypes = [NSSet setWithObject:[HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierPeakExpiratoryFlowRate]];
	NSSet* readableTypes = [NSSet setWithObjects:[HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceWalkingRunning], [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierBloodPressureSystolic], nil];
	
	[_healthStore requestAuthorizationToShareTypes:nil readTypes:readableTypes completion:^(BOOL success, NSError * _Nullable error) {
		NSLog(@"Health: %@", success ? @"<granted>" : [NSString stringWithFormat:@"<not granted: %@>", error]);
	}];
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
	NSLog(@"Location: %@", status == kCLAuthorizationStatusAuthorizedAlways ? @"<always>" : status == kCLAuthorizationStatusAuthorizedWhenInUse ? @"<when in use>" : @"not granted");
}

@end
