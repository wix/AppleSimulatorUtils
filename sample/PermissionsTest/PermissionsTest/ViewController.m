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

@interface ViewController () <CLLocationManagerDelegate>
{
	EKEventStore* _eventStore;
	CLLocationManager* _locationManager;
}

@end

@implementation ViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	_eventStore = [EKEventStore new];
	_locationManager = [CLLocationManager new];
	_locationManager.delegate = self;
	
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

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
	NSLog(@"Location: %@", status == kCLAuthorizationStatusAuthorizedAlways ? @"<always>" : status == kCLAuthorizationStatusAuthorizedWhenInUse ? @"<when in use>" : @"not granted");
}

@end
