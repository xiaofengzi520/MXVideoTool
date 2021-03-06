//
//  MXVideoMergeTool.m
//  MXVideoTool
//
//  Created by 牟潇 on 16/3/4.
//  Copyright © 2016年 muxiao. All rights reserved.
//

#import "MXVideoMergeTool.h"
#import <AVFoundation/AVFoundation.h>
#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/MobileCoreServices.h>
#define VIDEO_FOLDER @"videos"


@implementation MXVideoMergeTool

+ (void)mergeAndExportVideosAtFileURLs:(NSArray *)fileURLArray  result:(VideoMergeResultBlock)videoMergeBlock
{
    NSError *error = nil;
    
    CGSize renderSize = CGSizeMake(0, 0);
    
    NSMutableArray *layerInstructionArray = [[NSMutableArray alloc] init];
    
    AVMutableComposition *mixComposition = [[AVMutableComposition alloc] init];
    CMTime totalDuration = kCMTimeZero;
    //先去assetTrack 也为了取renderSize
    NSMutableArray *assetTrackArray = [[NSMutableArray alloc] init];
    NSMutableArray *assetArray = [[NSMutableArray alloc] init];
    for (NSURL *fileURL in fileURLArray) {
        AVAsset *asset = [AVAsset assetWithURL:fileURL];
        if (!asset) {
            continue;
        }
        [assetArray addObject:asset];
        AVAssetTrack *assetTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
        [assetTrackArray addObject:assetTrack];
        renderSize.width = MAX(renderSize.width, assetTrack.naturalSize.height);
        renderSize.height = MAX(renderSize.height, assetTrack.naturalSize.width);
    }
    
    CGFloat renderW = MIN(renderSize.width, renderSize.height);
    
    for (int i = 0; i < [assetArray count] && i < [assetTrackArray count]; i++) {
        
        AVAsset *asset = [assetArray objectAtIndex:i];
        AVAssetTrack *assetTrack = [assetTrackArray objectAtIndex:i];
        
        AVMutableCompositionTrack *audioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
        [audioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration)
                            ofTrack:[[asset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0]
                             atTime:totalDuration
                              error:nil];
        
        AVMutableCompositionTrack *videoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
        
        [videoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration)
                            ofTrack:assetTrack
                             atTime:totalDuration
                              error:&error];
        
        //fix orientationissue
        AVMutableVideoCompositionLayerInstruction *layerInstruciton = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
        
        totalDuration = CMTimeAdd(totalDuration, asset.duration);
        
        CGFloat rate;
        rate = renderW / MIN(assetTrack.naturalSize.width, assetTrack.naturalSize.height);
        
        CGAffineTransform layerTransform = CGAffineTransformMake(assetTrack.preferredTransform.a, assetTrack.preferredTransform.b, assetTrack.preferredTransform.c, assetTrack.preferredTransform.d, assetTrack.preferredTransform.tx * rate, assetTrack.preferredTransform.ty * rate);
        layerTransform = CGAffineTransformConcat(layerTransform, CGAffineTransformMake(1, 0, 0, 1, 0, -(assetTrack.naturalSize.width - assetTrack.naturalSize.height) / 2.0));//向上移动取中部影响
        layerTransform = CGAffineTransformScale(layerTransform, rate, rate);//放缩，解决前后摄像结果大小不对称
        
        [layerInstruciton setTransform:layerTransform atTime:kCMTimeZero];
        [layerInstruciton setOpacity:0.0 atTime:totalDuration];
        
        //data
        [layerInstructionArray addObject:layerInstruciton];
    }
    
    //get save path
    NSURL *mergeFileURL = [NSURL fileURLWithPath:[self getVideoMergeFilePathString]];
    
    //export
    AVMutableVideoCompositionInstruction *mainInstruciton = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    mainInstruciton.timeRange = CMTimeRangeMake(kCMTimeZero, totalDuration);
    mainInstruciton.layerInstructions = layerInstructionArray;
    AVMutableVideoComposition *mainCompositionInst = [AVMutableVideoComposition videoComposition];
    mainCompositionInst.instructions = @[mainInstruciton];
    mainCompositionInst.frameDuration = CMTimeMake(1, 30);
    mainCompositionInst.renderSize = CGSizeMake(renderW, renderW);
    
#pragma mark -  视频压缩质量 AVAssetExportPresetMediumQuality
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetMediumQuality];
    exporter.videoComposition = mainCompositionInst;
    exporter.outputURL = mergeFileURL;
    exporter.outputFileType = AVFileTypeMPEG4;
    exporter.shouldOptimizeForNetworkUse = YES;
    NSLog(@"outputUrl = %@", mergeFileURL);
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (videoMergeBlock) {
                videoMergeBlock(mergeFileURL);
            }
        });
    }];

}

+ (NSString *)getVideoMergeFilePathString
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *path = [paths objectAtIndex:0];
    
    //path = [path stringByAppendingPathComponent:VIDEO_FOLDER];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyyMMddHHmmss";
    NSString *nowTimeStr = [formatter stringFromDate:[NSDate dateWithTimeIntervalSinceNow:0]];
    
    NSString *fileName = [[path stringByAppendingPathComponent:nowTimeStr] stringByAppendingString:@"merge.mp4"];
    
    return fileName;
}

+ (NSString *)exportGifImagesWithVideoUrl:(NSURL *)url
{
    CGFloat duration = [MXVideoMergeTool durationForVideo:url];
    CGFloat delay = 0.05;
    CGFloat currentTime = 0;
    NSMutableArray *imageArr = [NSMutableArray array];
    NSMutableArray *delayArr = [NSMutableArray array];
    while (currentTime < duration) {
        UIImage *image = [MXVideoMergeTool thumbnailImageForVideo:url atTime:currentTime];
        if (image) {
            [imageArr addObject:image];
            [delayArr addObject:@(delay)];
        }
        currentTime += delay;
        if (currentTime > duration) {
            currentTime = duration;
            UIImage *image = [MXVideoMergeTool thumbnailImageForVideo:url atTime:currentTime];
            if (image) {
                [imageArr addObject:image];
                [delayArr addObject:@(delay)];
            }
        }
    }
    if (imageArr.count > 0) {
        NSString * gifPath = [MXVideoMergeTool exportGifImages:imageArr delays:delayArr loopCount:0];
        return gifPath;
    }
    return nil;
    
}

+ (NSString *)exportGifImages:(NSArray *)images delays:(NSArray *)delays loopCount:(NSUInteger)loopCount
{
    NSString *fileName = [NSString stringWithFormat: @"%.0f.%@", [NSDate timeIntervalSinceReferenceDate] * 1000.0, @"gif"];
    NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:filePath],
                                                                        kUTTypeGIF, images.count, NULL);
    if(!loopCount){
        loopCount = 0;
    }
    NSDictionary *gifProperties = @{ (__bridge id)kCGImagePropertyGIFDictionary: @{
                                             (__bridge id)kCGImagePropertyGIFLoopCount: @(loopCount), // 0 means loop forever
                                             }
                                     };
    float delay = 0.1; //默认每一帧间隔0.1秒
    for (int i=0; i<images.count; i++) {
        UIImage *itemImage = images[i];
        if(delays && i<delays.count){
            delay = [delays[i] floatValue];
        }
        //每一帧对应的延迟时间
        NSDictionary *frameProperties = @{(__bridge id)kCGImagePropertyGIFDictionary: @{
                                                  (__bridge id)kCGImagePropertyGIFDelayTime: @(delay), // a float (not double!) in seconds, rounded to centiseconds in the GIF data
                                                  }
                                          };
        CGImageDestinationAddImage(destination,itemImage.CGImage, (__bridge CFDictionaryRef)frameProperties);
    }
    CGImageDestinationSetProperties(destination, (__bridge CFDictionaryRef)gifProperties);
    if (!CGImageDestinationFinalize(destination)) {
        NSLog(@"failed to finalize image destination");
    }
    CFRelease(destination);
    return filePath;
}

+ (UIImage *)thumbnailImageForVideo:(NSURL *)videoURL atTime:(NSTimeInterval)time
{
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:videoURL options:nil];
    NSParameterAssert(asset);
    AVAssetImageGenerator *assetImageGennerator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    assetImageGennerator.appliesPreferredTrackTransform = YES;
    assetImageGennerator.apertureMode = AVAssetImageGeneratorApertureModeEncodedPixels;
    CGImageRef thumbnailImageRef = NULL;
    CFTimeInterval thumbnailImageTime = time * 60;
    NSError *thumbnailImageGenerationError = nil;
    thumbnailImageRef = [assetImageGennerator copyCGImageAtTime:CMTimeMake(thumbnailImageTime, 60) actualTime:NULL error:&thumbnailImageGenerationError];
    if (!thumbnailImageRef) {
        NSLog(@"thumbnailImageGenerationError %@",thumbnailImageGenerationError);
    }
    UIImage *thumbnailImage = thumbnailImageRef ? [[UIImage alloc] initWithCGImage:thumbnailImageRef] : nil;
    CFRelease(thumbnailImageRef);
    return thumbnailImage;
}

+ (CGFloat)durationForVideo:(NSURL *)mediaUrl
{
    AVURLAsset *avUrl = [AVURLAsset assetWithURL:mediaUrl];
    CMTime time = [avUrl duration];
    return ceil(time.value/time.timescale);

}

@end
