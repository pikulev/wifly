//
//  iX_YokeAppDelegate.m
//  iX-Yoke
//
//  Created by Daniel Dickison on 4/25/09.
//  Copyright Daniel_Dickison 2009. All rights reserved.
//

#import "iX_YokeAppDelegate.h"
#import "MainViewController.h"

#define kUpdateFrequency 20  // Hz
#define kFilteringFactor 0.2


@implementation iX_YokeAppDelegate


@synthesize window;
@synthesize mainViewController;


- (void)applicationDidFinishLaunching:(UIApplication *)application
{
    [UIAccelerometer sharedAccelerometer].updateInterval = (1.0 / kUpdateFrequency);
    [UIAccelerometer sharedAccelerometer].delegate = self;
    
	MainViewController *aController = [[MainViewController alloc] initWithNibName:@"MainView" bundle:nil];
	self.mainViewController = aController;
	[aController release];
	
    mainViewController.view.frame = [UIScreen mainScreen].applicationFrame;
	[window addSubview:[mainViewController view]];
    [window makeKeyAndVisible];
}


- (void)dealloc
{
    [mainViewController release];
    [window release];
    [super dealloc];
}


- (void)accelerometer:(UIAccelerometer *)accelerometer didAccelerate:(UIAcceleration *)acceleration
{
    // Use a basic low-pass filter to only keep the gravity in the accelerometer values for the X and Y axes
    // See the BubbleLevel Apple example.
    xAvg = acceleration.x * kFilteringFactor + xAvg * (1.0 - kFilteringFactor);
    yAvg = acceleration.y * kFilteringFactor + yAvg * (1.0 - kFilteringFactor);
    zAvg = acceleration.z * kFilteringFactor + zAvg * (1.0 - kFilteringFactor);
    
    // This method gives a range of +/- 90 degrees on each axis, but only if you're rotating about one axis at a time.  If you try to tilt on both axes, then it maxes out at +/- 45 degrees.  It would probably be nicer if the range is kept constant regardless of whether you're tilting in one or two axes.
    double ySqr = yAvg*yAvg;
    pitch = atan2(zAvg, sqrt(ySqr + xAvg*xAvg));
    roll = atan2(xAvg, sqrt(ySqr + zAvg*zAvg));
    
    [mainViewController updatePitch:pitch roll:roll];
}



@end