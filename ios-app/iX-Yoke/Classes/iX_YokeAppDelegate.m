//
//  iX_YokeAppDelegate.m
//  iX-Yoke
//
//  Created by Daniel Dickison on 4/25/09.
//  Copyright Daniel_Dickison 2009. All rights reserved.
//

#import "iX_YokeAppDelegate.h"
#import "MainViewController.h"
#import "AsyncUdpSocket.h"
#include "iX_Yoke_Network.h"

#define kUpdateFrequency 20  // Hz
#define kFilteringFactor 0.25f


// Matrices should be an array in column-major order of floats.  outMatrix must have enough space to store the results, which will be aRows x bCols.
static void matMult(float* outMatrix, float *A, float *B, int aCols_bRows, int aRows, int bCols);


@implementation iX_YokeAppDelegate


@synthesize window;
@synthesize mainViewController, hostAddress, hostPort, touch_x, touch_y;


- (void)setHostAddress:(NSString *)addr
{
    if (addr != hostAddress)
    {
        [hostAddress release];
        hostAddress = [addr retain];
        [[NSUserDefaults standardUserDefaults] setObject:addr forKey:@"hostAddress"];
    }
}

- (void)setHostPort:(unsigned)port
{
    hostPort = port;
    [[NSUserDefaults standardUserDefaults] setInteger:port forKey:@"hostPort"];
}


- (void)applicationDidFinishLaunching:(UIApplication *)application
{
    socket = [[AsyncUdpSocket alloc] initWithDelegate:self];
    
    self.hostAddress = [[NSUserDefaults standardUserDefaults] stringForKey:@"hostAddress"];
    self.hostPort = [[NSUserDefaults standardUserDefaults] integerForKey:@"hostPort"];
    
    [UIAccelerometer sharedAccelerometer].updateInterval = (1.0 / kUpdateFrequency);
    [UIAccelerometer sharedAccelerometer].delegate = self;
    
	MainViewController *aController = [[MainViewController alloc] initWithNibName:@"MainView" bundle:nil];
	self.mainViewController = aController;
	[aController release];
	
    mainViewController.view.frame = [UIScreen mainScreen].applicationFrame;
	[window addSubview:[mainViewController view]];
    [window makeKeyAndVisible];
    
    
    // We want to auto-calibrate after a few accelerometer readings have been taken.  2 seconds is probably good enough.
    [self performSelector:@selector(resetTiltCenter) withObject:nil afterDelay:2.0];
}


- (void)dealloc
{
    [mainViewController release];
    [window release];
    [super dealloc];
}


- (void)accelerometer:(UIAccelerometer *)accelerometer didAccelerate:(UIAcceleration *)accel
{
    // Use a basic low-pass filter to only keep the gravity in the accelerometer values for the X and Y axes
    // See the BubbleLevel Apple example.
    acceleration[0] = (float)accel.x * kFilteringFactor + acceleration[0] * (1.0f - kFilteringFactor);
    acceleration[1] = (float)accel.y * kFilteringFactor + acceleration[1] * (1.0f - kFilteringFactor);
    acceleration[2] = (float)accel.z * kFilteringFactor + acceleration[2] * (1.0f - kFilteringFactor);
    
    
    // Apply the rotation matrix to center it about the z-axis.
    float rotated[3];
    matMult(rotated, centerTiltRotationMatrix, acceleration, 3, 3, 1);
    
    // Project to the xy plane for pitch & roll.
    float pitch = -rotated[1];
    float roll = rotated[0];
    
    // The view controller handles calibration via its trackpad.
    [mainViewController updatePitch:&pitch roll:&roll];
    
    if (hostAddress)
    {
        UInt8 buffer[128];
        int i = 0;
        ix_put_tag(buffer, &i, kProtocolVersion1Tag);
        ix_put_ratio(buffer, &i, roll);
        ix_put_ratio(buffer, &i, pitch);
        ix_put_ratio(buffer, &i, touch_x);
        ix_put_ratio(buffer, &i, touch_y);
        NSData *data = [[NSData alloc] initWithBytes:buffer length:i];
        [socket sendData:data toHost:hostAddress port:hostPort withTimeout:-1 tag:0];
        [data release];
    }
}


- (void)resetTiltCenter
{
    //float ySqr = yAvg*yAvg;
    //pitchOffset = -atan2f(zAvg, sqrtf(ySqr + xAvg*xAvg));
    //rollOffset = -atan2f(xAvg, sqrtf(ySqr + zAvg*zAvg));
    
    // This version only centers with respect to rotation about the x-axis -- that is, pitch.  This seems more intuitive since you rarely need to have the center of tilt be sideways.  For landscape mode, this will have to be rotation about the y-axis.
    float y = -acceleration[1];
    float z = acceleration[2];
    float theta = asinf(y / sqrtf(y*y + z*z));
    if (z > 0) theta = M_PI - theta;
    float c = cosf(theta);
    float s = sinf(theta);
    
    centerTiltRotationMatrix[0] = 1;
    centerTiltRotationMatrix[1] = 0;
    centerTiltRotationMatrix[2] = 0;
    centerTiltRotationMatrix[3] = 0;
    centerTiltRotationMatrix[4] = c;
    centerTiltRotationMatrix[5] = s;
    centerTiltRotationMatrix[6] = 0;
    centerTiltRotationMatrix[7] = -s;
    centerTiltRotationMatrix[8] = c;
    
    // The following version centers by rotating the acceleration vector onto the z-axis, and making the projection onto the xy-plane the pitch and roll.  This is a little bit unintuitive when the center is tilted with respect to the x-axis, so I'm going to prefer the z-only rotation version above.
    /*
    // Figure out the rotation transform matrix to rotate the current acceleration vector v onto the z axis (aka 'k').
    // Theta will be the angle between k and v, found using the dot product.
    // The axis of rotation will be n, the unit normal of k and v, found using cross product.
    
    // k dot v = <0,0,1> dot <vx,vy,vz> = vz
    float vmag = sqrt(acceleration[0]*acceleration[0] + acceleration[1]*acceleration[1] + acceleration[2]*acceleration[2]);
    float theta = acosf(acceleration[2] / vmag);
    
    // k cross v = <vx,vy,vz> cross <0,0,1> = <vy, -vx, 0>
    float nx = acceleration[1];
    float ny = -acceleration[0];
    float nmag = sqrt(nx*nx + ny*ny);
    nx /= nmag;
    ny /= nmag;
    
    // I'm using the axis-angle rotation math from:
    // http://www.euclideanspace.com/maths/algebra/matrix/orthogonal/rotation/index.htm
    // Note that nz is zero, so it's a bit simpler here.
    // Also, we don't really need row 3, since we ignore the transformed z coordinate, but I'll calculate them anyways for clarity.
    float c = cosf(theta);
    float s = sinf(theta);
    centerTiltRotationMatrix[0] = 1.0f + (1.0f-c)*(nx*nx-1);
    centerTiltRotationMatrix[1] = (1.0f-c)*nx*ny;
    centerTiltRotationMatrix[2] = -ny*s;
    centerTiltRotationMatrix[3] = (1.0f-c)*nx*ny;
    centerTiltRotationMatrix[4] = 1.0f + (1.0f-c)*(ny*ny-1);
    centerTiltRotationMatrix[5] = nx*s;
    centerTiltRotationMatrix[6] = ny*s;
    centerTiltRotationMatrix[7] = -nx*s;
    centerTiltRotationMatrix[8] = 1.0f;
     */
}


@end



static void matMult(float* outMatrix, float *A, float *B, int aCols_bRows, int aRows, int bCols)
{
    for (int i = 0; i < aRows; i++)
    {
        for (int j = 0; j < bCols; j++)
        {
            float *val = outMatrix + i + j*aRows;
            *val = 0;
            
            float *aVal = A + i;
            float *bVal = B + j*aCols_bRows;
            
            for (int k = 0; k < aCols_bRows; k++)
            {
                *val += (*aVal) * (*bVal);
                aVal += aCols_bRows;
                bVal += 1;
            }
        }
    }
}


