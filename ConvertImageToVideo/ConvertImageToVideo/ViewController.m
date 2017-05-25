//
//  ViewController.m
//  ConvertImageToVideo
//
//  Created by Migu on 2017/5/24.
//  Copyright © 2017年 VIctorChee. All rights reserved.
//

#import "ViewController.h"
@import AVFoundation;

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self convertImages:@[[UIImage imageNamed:@"frame1"], [UIImage imageNamed:@"frame2"]] duration:2 completionHandler:^(NSURL *location) {
        NSLog(@"%@", location);
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)convertImages:(NSArray *)images duration:(NSTimeInterval)duration completionHandler:(void (^)(NSURL *location))completionHandler {
    if (!images || images.count == 0 || duration <= 0) {
        return;
    }
    
    NSLog(@"%f", CFAbsoluteTimeGetCurrent());
    
    if (images.count == 1) {
        images = @[images.firstObject, images.firstObject];
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *documentURL = [fileManager URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
    NSURL *destination = [documentURL URLByAppendingPathComponent:@"out.mp4"];
    [fileManager removeItemAtURL:destination error:nil];
    
    AVAssetWriter *videoWriter = [[AVAssetWriter alloc] initWithURL:destination fileType:AVFileTypeQuickTimeMovie error:nil];
    NSParameterAssert(videoWriter);
    
    NSDictionary *videoSettings = @{AVVideoCodecKey: AVVideoCodecH264, AVVideoWidthKey: @640, AVVideoHeightKey: @480};
    AVAssetWriterInput *writeInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
    AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:writeInput sourcePixelBufferAttributes:nil];
    NSParameterAssert(writeInput);
    NSParameterAssert([videoWriter canAddInput:writeInput]);
    [videoWriter addInput:writeInput];
    
    [videoWriter startWriting];
    [videoWriter startSessionAtSourceTime:kCMTimeZero];
    
    CVPixelBufferRef buffer = NULL;
    NSInteger index = 0;
    while (1) {
        if (writeInput.readyForMoreMediaData) {
            CMTime frameTime = CMTimeMake((duration/images.count)*600, 600);
            CMTime presentTime = CMTimeMake(index*frameTime.value, 600);
            
//            if (!index) {
//                presentTime = frameTime;
//            }
            
            if (index >= images.count) {
                break;
            } else {
                buffer = [self pixelBufferFromImage:images[index]];
            }
            
            if (buffer) {
                [adaptor appendPixelBuffer:buffer withPresentationTime:presentTime];
                index += 1;
            }
        }
    }
    
    [writeInput markAsFinished];
    [videoWriter finishWritingWithCompletionHandler:^{
        CVPixelBufferPoolRelease(adaptor.pixelBufferPool);
        
        NSLog(@"%f", CFAbsoluteTimeGetCurrent());
        
        __block typeof(completionHandler) block = completionHandler;
        if (block) {
            block(destination);
            block = nil;
        }
    }];
}

- (CVPixelBufferRef)pixelBufferFromImage:(UIImage *)image {
    NSDictionary *options = @{(__bridge NSString *)kCVPixelBufferCGImageCompatibilityKey: @YES, (__bridge NSString *)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES};
    CVPixelBufferRef pixelBuffer = NULL;
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, image.size.width, image.size.height, kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef)options, &pixelBuffer);
    NSParameterAssert(status == kCVReturnSuccess && pixelBuffer != NULL);
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    void *pixelData = CVPixelBufferGetBaseAddress(pixelBuffer);
    NSParameterAssert(pixelData != NULL);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixelData, image.size.width, image.size.height, 8, 4*image.size.width, colorSpace, kCGImageAlphaNoneSkipFirst);
    NSParameterAssert(context);
    CGContextConcatCTM(context, CGAffineTransformMakeRotation(0));
    CGContextDrawImage(context, CGRectMake(0, 0, image.size.width, image.size.height), image.CGImage);
    CGColorSpaceRelease(colorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    return pixelBuffer;
}

@end
