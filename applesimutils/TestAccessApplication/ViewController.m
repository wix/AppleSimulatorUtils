//
//  ViewController.m
//  TestAccessApplication
//
//  Created by Andrew Romanov on 01/10/2018.
//  Copyright © 2018 Wix. All rights reserved.
//

#import "ViewController.h"
@import Photos;


@interface ViewController ()

@property (nonatomic, strong) IBOutlet UILabel* photosStatus;
@property (nonatomic, strong) IBOutlet UIButton* askAccess;

@property (nonatomic, strong) UIActivityIndicatorView* activityIndicator;

- (IBAction)askAccess:(id)sender;

@end


@interface ViewController (Private)

- (void)_updatePhotosStatusLabel;
- (void)_execImmidiateOnMain:(void(^)(void))block;

@end


@implementation ViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
	[self _updatePhotosStatusLabel];
}


#pragma mark Ations
- (IBAction)askAccess:(id)sender
{
	if (!_activityIndicator) {
		_activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
		_activityIndicator.hidesWhenStopped = YES;
		[self.view addSubview:_activityIndicator];
	}
	
	[_activityIndicator startAnimating];
	_askAccess.hidden = YES;
	[PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
		[self _execImmidiateOnMain:^{
			self.askAccess.hidden = NO;
			
			[self.activityIndicator stopAnimating];
			[self.activityIndicator removeFromSuperview];
			self.activityIndicator = nil;
			[self _updatePhotosStatusLabel];
		}];
	}];
}

@end


#pragma mark -
@implementation ViewController (Private)

- (void)_updatePhotosStatusLabel
{
	PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
	NSString* text = @"";
	
	switch (status) {
		case PHAuthorizationStatusNotDetermined:
			text = @"Not determined";
			break;
		case PHAuthorizationStatusRestricted:
			text = @"Restricted";
			break;
		case PHAuthorizationStatusDenied:
			text = @"Denied";
			break;
		case PHAuthorizationStatusAuthorized:
			text = @"Authorized";
			break;
		default:
			break;
	}
	
	self.photosStatus.text = text;
}


- (void)_execImmidiateOnMain:(void(^)(void))block
{
	if ([NSThread isMainThread])
	{
		block();
	}
	else {
		dispatch_async(dispatch_get_main_queue(), block);
	}
}

@end


