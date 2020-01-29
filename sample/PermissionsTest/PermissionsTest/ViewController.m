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
	
	_healthStore = [HKHealthStore new];
	
	NSLog(@"%@", NSBundle.mainBundle.bundleURL.path);
}

- (IBAction)_location:(id)sender
{
	_locationManager = [CLLocationManager new];
	_locationManager.delegate = self;
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
	NSSet* readableTypes = [NSSet setWithObjects:[HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierPeakExpiratoryFlowRate], [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierBloodPressureSystolic], nil];
	
	[_healthStore requestAuthorizationToShareTypes:readableTypes readTypes:readableTypes completion:^(BOOL success, NSError * _Nullable error) {
		NSLog(@"Health: %@", success ? ([_healthStore authorizationStatusForType:[HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierPeakExpiratoryFlowRate]] == HKAuthorizationStatusSharingAuthorized ? @"<granted>" : @"<not granted>") : [NSString stringWithFormat:@"<error: %@>", error]);
	}];
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
	NSLog(@"Location: %@", status == kCLAuthorizationStatusAuthorizedAlways ? @"<always>" : status == kCLAuthorizationStatusAuthorizedWhenInUse ? @"<when in use>" : @"<not granted>");
}

@end
