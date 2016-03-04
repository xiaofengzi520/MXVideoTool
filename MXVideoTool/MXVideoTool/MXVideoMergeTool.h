//
//  MXVideoMergeTool.h
//  MXVideoTool
//
//  Created by 牟潇 on 16/3/4.
//  Copyright © 2016年 muxiao. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef  void(^VideoMergeResultBlock)(NSURL *videoMergeUrl);

@interface MXVideoMergeTool : NSObject

/*!
 @method mergeAndExportVideosAtFileURLs:
 
 @param fileURLArray
 包含所有视频分段的文件URL数组，必须是[NSURL fileURLWithString:...]得到的
 
 @discussion
 将所有分段视频合成为一段完整视频，并且裁剪为正方形
 */
+ (void)mergeAndExportVideosAtFileURLs:(NSArray *)fileURLArray result:(VideoMergeResultBlock)videoMergeBlock;


@end
