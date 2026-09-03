#import "EasyPdfViewerPlugin.h"
#import <UIKit/UIKit.h>

static NSString *const kDirectory = @"EasyPdfViewer";

@implementation EasyPdfViewerPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  FlutterMethodChannel *channel = [FlutterMethodChannel
      methodChannelWithName:@"easy_pdf_viewer_plugin"
            binaryMessenger:registrar.messenger];
  EasyPdfViewerPlugin *instance = [[EasyPdfViewerPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    @autoreleasepool {
      if ([call.method isEqualToString:@"getPage"]) {
        NSString *filePath = call.arguments[@"filePath"];
        NSNumber *pageNumber = call.arguments[@"pageNumber"];
        if (![filePath isKindOfClass:[NSString class]] ||
            ![pageNumber isKindOfClass:[NSNumber class]] ||
            pageNumber.integerValue < 1) {
          result([FlutterError errorWithCode:@"INVALID_ARGUMENTS"
                                     message:@"filePath and a one-based pageNumber are required."
                                     details:nil]);
          return;
        }
        result([self getPage:filePath ofPage:(size_t)pageNumber.integerValue]);
      } else if ([call.method isEqualToString:@"getNumberOfPages"]) {
        NSString *filePath = call.arguments[@"filePath"];
        NSNumber *clearCacheDir = call.arguments[@"clearCacheDir"];
        if (![filePath isKindOfClass:[NSString class]]) {
          result([FlutterError errorWithCode:@"INVALID_ARGUMENTS"
                                     message:@"filePath is required."
                                     details:nil]);
          return;
        }
        result([self getNumberOfPages:filePath clearCacheDir:clearCacheDir]);
      } else if ([call.method isEqualToString:@"clearCacheDir"]) {
        [self clearCacheDir];
        result(nil);
      } else {
        result(FlutterMethodNotImplemented);
      }
    }
  });
}

- (void)clearCacheDir {
  NSArray *paths = NSSearchPathForDirectoriesInDomains(
      NSCachesDirectory, NSUserDomainMask, YES);
  NSString *cachePath = [paths.firstObject stringByAppendingPathComponent:kDirectory];
  NSError *error = nil;
  if ([[NSFileManager defaultManager] fileExistsAtPath:cachePath] &&
      ![[NSFileManager defaultManager] removeItemAtPath:cachePath error:&error]) {
    NSLog(@"[EasyPdfViewerPlugin] Clear cache error: %@", error);
  }
}

- (NSString *)getNumberOfPages:(NSString *)path clearCacheDir:(NSNumber *)clearCacheDir {
  if (clearCacheDir.boolValue) [self clearCacheDir];

  NSURL *sourceURL = [path hasPrefix:@"file://"]
      ? [NSURL URLWithString:path]
      : [NSURL fileURLWithPath:path];
  CGPDFDocumentRef document =
      CGPDFDocumentCreateWithURL((__bridge CFURLRef)sourceURL);
  if (document == NULL) return nil;

  size_t pageCount = CGPDFDocumentGetNumberOfPages(document);
  CGPDFDocumentRelease(document);
  return [NSString stringWithFormat:@"%zu", pageCount];
}

- (NSString *)getPage:(NSString *)path ofPage:(size_t)requestedPage {
  NSURL *sourceURL = [path hasPrefix:@"file://"]
      ? [NSURL URLWithString:path]
      : [NSURL fileURLWithPath:path];
  CGPDFDocumentRef document =
      CGPDFDocumentCreateWithURL((__bridge CFURLRef)sourceURL);
  if (document == NULL) return nil;

  size_t pageCount = CGPDFDocumentGetNumberOfPages(document);
  if (pageCount == 0) {
    CGPDFDocumentRelease(document);
    return nil;
  }
  size_t pageNumber = MIN(requestedPage, pageCount);
  CGPDFPageRef page = CGPDFDocumentGetPage(document, pageNumber);
  if (page == NULL) {
    CGPDFDocumentRelease(document);
    return nil;
  }

  NSArray *paths = NSSearchPathForDirectoriesInDomains(
      NSCachesDirectory, NSUserDomainMask, YES);
  NSString *cachePath = [paths.firstObject stringByAppendingPathComponent:kDirectory];
  NSError *error = nil;
  if (![[NSFileManager defaultManager] createDirectoryAtPath:cachePath
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:&error]) {
    CGPDFDocumentRelease(document);
    return nil;
  }

  CGRect sourceRect = CGPDFPageGetBoxRect(page, kCGPDFMediaBox);
  CGFloat dpi = 300.0 / 72.0;
  CGFloat width = MAX(1.0, sourceRect.size.width * dpi);
  CGFloat height = MAX(1.0, sourceRect.size.height * dpi);
  UIGraphicsBeginImageContextWithOptions(CGSizeMake(width, height), YES, 1.0);

  CGContextRef context = UIGraphicsGetCurrentContext();
  CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
  CGContextSetRGBFillColor(context, 1.0, 1.0, 1.0, 1.0);
  CGContextFillRect(context, CGContextGetClipBoundingBox(context));
  CGContextTranslateCTM(context, 0.0, height);
  CGContextScaleCTM(context, dpi, -dpi);
  CGContextDrawPDFPage(context, page);

  UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
  NSData *pngData = UIImagePNGRepresentation(image);
  UIGraphicsEndImageContext();
  CGPDFDocumentRelease(document);
  if (pngData == nil) return nil;

  NSString *fileName = [NSString stringWithFormat:@"%@-%@-%zu.png",
                        kDirectory, [NSUUID UUID].UUIDString, pageNumber];
  NSString *filePath = [cachePath stringByAppendingPathComponent:fileName];
  if (![pngData writeToFile:filePath atomically:YES]) return nil;
  return filePath;
}

@end
