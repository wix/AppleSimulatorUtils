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
@import Photos;
@import PhotosUI;
@import AppTrackingTransparency;

@interface ViewController () <CLLocationManagerDelegate, PHPickerViewControllerDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate>
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

- (IBAction)_photos:(id)sender
{
	id handler = ^(PHAuthorizationStatus status) {
		if(@available(iOS 14, *))
		{
			if(status == PHAuthorizationStatusLimited)
			{
				NSLog(@"Photos: <limited>");
				
				return;
			}
		}
		
		NSLog(@"Photos: %@", status == PHAuthorizationStatusRestricted ? @"<restricted>" : status == PHAuthorizationStatusDenied ? @"<not granted>" : status == PHAuthorizationStatusAuthorized ? @"<granted>" : @"<?>");
	};
	
	if(@available(iOS 14, *))
	{
		[PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelReadWrite handler:handler];
	}
	else
	{
		[PHPhotoLibrary requestAuthorization:handler];
	}
}

- (IBAction)_photosOS14:(id)sender
{
	if(@available(iOS 14, *))
	{
		PHPickerConfiguration* config = [PHPickerConfiguration new];
		config.selectionLimit = 0;

		PHPickerViewController* picker = [[PHPickerViewController alloc] initWithConfiguration:config];
		picker.delegate = self;
		[self presentViewController:picker animated:YES completion:nil];
	}
	else
	{
		UIImagePickerController* picker = [UIImagePickerController new];
		picker.delegate = self;
		[self presentViewController:picker animated:YES completion:nil];
	}
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

- (IBAction)_criticalAlerts:(id)sender
{
	UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    if (@available(iOS 12.0, *)) {
        [center requestAuthorizationWithOptions: UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionCriticalAlert completionHandler:^(BOOL granted, NSError * _Nullable error) {
            NSLog(@"Critical Alerts: %@", granted ? @"<granted>" : @"<not granted>");
        }];
    } else {
        NSLog(@"Critical Alerts: Not available on iOS<12.0");
    }
}

- (IBAction)_health:(id)sender
{
	NSSet* readableTypes = [NSSet setWithObjects:[HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierPeakExpiratoryFlowRate], [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierBloodPressureSystolic], nil];
	
	[_healthStore requestAuthorizationToShareTypes:readableTypes readTypes:readableTypes completion:^(BOOL success, NSError * _Nullable error) {
		NSLog(@"Health: %@", success ? ([_healthStore authorizationStatusForType:[HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierPeakExpiratoryFlowRate]] == HKAuthorizationStatusSharingAuthorized ? @"<granted>" : @"<not granted>") : [NSString stringWithFormat:@"<error: %@>", error]);
	}];
}

- (IBAction)_trackOS14:(id)sender
{
    if(@available(iOS 14, *)) {
        [ATTrackingManager requestTrackingAuthorizationWithCompletionHandler:^(ATTrackingManagerAuthorizationStatus status) {
            
            NSLog(@"Track: %@", status == ATTrackingManagerAuthorizationStatusRestricted ? @"<restricted>" : status == ATTrackingManagerAuthorizationStatusDenied ? @"<not granted>" : status == ATTrackingManagerAuthorizationStatusAuthorized ? @"<granted>" : @"<?>");
        }];
    }
    else
    {
        NSLog(@"Track: <granted>");
    }
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
	NSLog(@"Location: %@", status == kCLAuthorizationStatusAuthorizedAlways ? @"<always>" : status == kCLAuthorizationStatusAuthorizedWhenInUse ? @"<when in use>" : @"<not granted>");
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results API_AVAILABLE(ios(14))
{
	[self dismissViewControllerAnimated:YES completion:nil];
}

@end
