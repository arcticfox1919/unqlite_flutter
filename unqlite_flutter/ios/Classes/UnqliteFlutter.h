#import <Flutter/Flutter.h>
#import <unqlite/unqlite.h>

@interface UnqliteFlutter : NSObject<FlutterPlugin>

-(void)open:(char *)name;
-(void)close;
@end
