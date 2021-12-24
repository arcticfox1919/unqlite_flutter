#import "UnqliteFlutter.h"

@implementation UnqliteFlutter
{
    unqlite *pdb;
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"unqlite_flutter"
            binaryMessenger:[registrar messenger]];
  UnqliteFlutter* instance = [[UnqliteFlutter alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    result(FlutterMethodNotImplemented);
}

-(void)open:(char *)name{
    pdb = NULL;
    int r = unqlite_open(&pdb, name, UNQLITE_OPEN_CREATE);
    if(r != UNQLITE_OK){
        NSLog(@"Database open failed!");
    }
}

-(void)close{
    if(pdb != NULL){
        unqlite_close(pdb);
    }
}

@end
