//
//  ViewController.m
//  MXVideoTool
//
//  Created by 牟潇 on 16/3/4.
//  Copyright © 2016年 muxiao. All rights reserved.
//

#import "ViewController.h"
#import "MXVideoMergeTool.h"
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
     NSBundle *bundle = [NSBundle mainBundle];
    NSString *videoPath1 = [bundle pathForResource:@"07dc4d37-937b-4824-8fae-982bcaedc753" ofType:@".mp4"];
    NSString *videoPath2 = [bundle pathForResource:@"6ca96de9-a135-4a4d-bba0-4c40eb7f3062" ofType:@".mp4"];
    
    [MXVideoMergeTool mergeAndExportVideosAtFileURLs:@[[NSURL fileURLWithPath:videoPath1],[NSURL fileURLWithPath:videoPath2]] result:nil];
    NSString *path = [MXVideoMergeTool exportGifImagesWithVideoUrl:[NSURL fileURLWithPath:videoPath1]];
    NSLog(@"filePath = %@", path);
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
