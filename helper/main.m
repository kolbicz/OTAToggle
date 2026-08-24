#import <Foundation/Foundation.h>
#import <sys/stat.h>
#import <unistd.h>
extern int reboot(int);
#ifndef RB_AUTOBOOT
#define RB_AUTOBOOT 0
#endif

static NSString *PlistPath(void) {
    return @"/var/db/com.apple.xpc.launchd/disabled.plist";
}
static NSArray<NSString *> *Keys(void) { return @[@"com.apple.mobile.softwareupdated",@"com.apple.OTATaskingAgent",@"com.apple.softwareupdateservicesd",@"com.apple.mobile.NRDUpdated"]; }
static NSMutableDictionary *Load(NSError **error) {
    NSString *path=PlistPath(); NSData *data=[NSData dataWithContentsOfFile:path options:0 error:error];
    if(!data) return nil;
    id obj=[NSPropertyListSerialization propertyListWithData:data options:NSPropertyListMutableContainersAndLeaves format:nil error:error];
    if(![obj isKindOfClass:NSDictionary.class]) { if(error)*error=[NSError errorWithDomain:@"OTAToggle" code:2 userInfo:@{NSLocalizedDescriptionKey:@"disabled.plist is not a dictionary."}]; return nil; }
    return [obj mutableCopy];
}
static BOOL Save(NSDictionary *plist,NSError **error) {
    NSData *data=[NSPropertyListSerialization dataWithPropertyList:plist format:NSPropertyListBinaryFormat_v1_0 options:0 error:error]; if(!data)return NO;
    NSString *path=PlistPath(); NSString *temp=[path stringByAppendingFormat:@".otatoggle.%d",getpid()];
    if(![data writeToFile:temp options:NSDataWritingAtomic error:error])return NO;
    chmod(temp.fileSystemRepresentation,0644); chown(temp.fileSystemRepresentation,0,0);
    if(rename(temp.fileSystemRepresentation,path.fileSystemRepresentation)!=0){ int e=errno; unlink(temp.fileSystemRepresentation); if(error)*error=[NSError errorWithDomain:NSPOSIXErrorDomain code:e userInfo:nil]; return NO; }
    return YES;
}
int main(int argc,char **argv){ @autoreleasepool {
    if(geteuid()!=0){fprintf(stderr,"Root helper did not start as root. Install the IPA with TrollStore.\n");return 77;}
    if(argc!=2){fprintf(stderr,"Usage: otatoggle-helper status|enable|disable|reboot\n");return 64;}
    NSString *command=[NSString stringWithUTF8String:argv[1]];
    if([command isEqualToString:@"reboot"]){ sync(); if(reboot(RB_AUTOBOOT)!=0){perror("reboot");return 1;} return 0; }
    NSError *error=nil; NSMutableDictionary *plist=Load(&error); if(!plist){fprintf(stderr,"%s\n",error.localizedDescription.UTF8String);return 1;}
    if([command isEqualToString:@"status"]){
        for(NSString *key in Keys()) printf("%s=%s\n",key.UTF8String,[plist[key] boolValue]?"disabled":"enabled");
        return 0;
    }
    if([command isEqualToString:@"disable"]){for(NSString *key in Keys())plist[key]=@YES;}
    else if([command isEqualToString:@"enable"]){for(NSString *key in Keys())[plist removeObjectForKey:key];}
    else {fprintf(stderr,"Unknown command.\n");return 64;}
    if(!Save(plist,&error)){fprintf(stderr,"%s\n",error.localizedDescription.UTF8String);return 1;} puts("ok"); return 0;
} }
