//
//  main.m
//  getcodecid
//
//  Created by Andy Vandijck on 27/12/12.
//  Copyright (c) 2012 AnV Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <stdio.h>
#import "getcodecid.h"

@implementation pciDevice

+(NSNumber *)grabEntry:(CFStringRef)entry forService:(io_service_t)service{
    CFTypeRef data = IORegistryEntryCreateCFProperty(service,entry,kCFAllocatorDefault,0);
    if(data==NULL) return @0;
    else{
        NSNumber *temp = @(*(NSInteger *)CFDataGetBytePtr(data));
        CFRelease(data);
        return temp;
    }
}
+(NSDictionary *)match:(pciDevice *)pci{
    NSInteger vendor = [[pci vendor] integerValue];
    NSInteger device = [[pci device] integerValue];
    return @{@kIOPropertyMatchKey:@{@"vendor-id":[NSData dataWithBytes:&vendor length:4], @"device-id":[NSData dataWithBytes:&device length:4]}};
}
-(NSNumber *)vendor{
    return(vendor);
}
-(NSNumber *)device{
    return(device);
}
-(NSNumber *)subVendor{
    return(subVendor);
}
-(NSNumber *)subDevice{
    return(subDevice);
}
-(NSNumber *)pciClassCode{
    return(pciClassCode);
}
-(NSNumber *)pciClass{
    return(PciClass);
}
-(NSNumber *)pciSubClass{
    return(pciSubClass);
}
-(NSString *)vendorString{
    return(vendorString);
}
-(NSString *)deviceString{
    return(deviceString);
}
-(NSString *)classString{
    return(classString);
}
-(NSString *)subClassString{
    return(subClassString);
}
-(void)setVendor:(NSNumber *)setvendor{
    vendor = setvendor;
}
-(void)setDevice:(NSNumber *)setdevice{
    device = setdevice;
}
-(void)setSubVendor:(NSNumber *)setsubVendor{
    subVendor = setsubVendor;
}
-(void)setSubDevice:(NSNumber *)setsubDevice{
    subDevice = setsubDevice;
}
-(void)setPciClassCode:(NSNumber *)setpciClassCode{
    pciClassCode = setpciClassCode;
}
-(void)setPciClass:(NSNumber *)setpciClass{
    PciClass = setpciClass;
}
-(void)setPciSubClass:(NSNumber *)setpciSubClass{
    pciSubClass = setpciSubClass;
}
-(void)setVendorString:(NSString *)setvendorString{
    vendorString = setvendorString;
}
-(void)setDeviceString:(NSString *)setdeviceString{
    deviceString = setdeviceString;
}
-(void)setClassString:(NSString *)setclassString{
    classString = setclassString;
}
-(void)setSubClassString:(NSString *)setsubClassString{
    subClassString = setsubClassString;
}
+(pciDevice *)create:(io_service_t)service classes:(NSMutableDictionary *)classes vendors:(NSMutableDictionary *)vendors{
    pciDevice *temp = [pciDevice create:service];
    [temp setVendorString:[[vendors objectForKey:[temp vendor]] name]];
    [temp setDeviceString:[[[vendors objectForKey:[temp vendor]] devices] objectForKey:[temp device]]];
    [temp setClassString:[[classes objectForKey:[temp pciClass]] name]];
    [temp setSubClassString:[[[classes objectForKey:[temp pciClass]] subClasses] objectForKey:[temp pciSubClass]]];
    return temp;
}
+(pciDevice *)create:(io_service_t)service{
    pciDevice *temp = [pciDevice new];
    [temp setVendor:[self grabEntry:CFSTR("vendor-id") forService:service]];
    [temp setDevice:[self grabEntry:CFSTR("device-id") forService:service]];
    [temp setSubVendor:[self grabEntry:CFSTR("subsystem-vendor-id") forService:service]];
    [temp setSubDevice:[self grabEntry:CFSTR("subsystem-id") forService:service]];
    [temp setPciClassCode:[self grabEntry:CFSTR("class-code") forService:service]];
    [temp setPciClass:@(([temp.pciClassCode integerValue] >> 16) &0xFF)];
    [temp setPciSubClass:@(([temp.pciClassCode integerValue] >>8) &0xFF)];
    return temp;
}
-(NSString *)fullClassString{
    return [NSString stringWithFormat:@"%@, %@", classString, subClassString];
}
-(long)fullID{
    return [device integerValue]<<16 | [vendor integerValue];
}
-(long)fullSubID{
    return [subDevice integerValue]<<16 | [subVendor integerValue];
}

+(NSArray *)readIDs{
    FILE *handle = fopen("/usr/share/pci.ids","rb");
    NSMutableArray *pcis = [NSMutableArray array];
    NSMutableDictionary *classes = [NSMutableDictionary dictionary];
    NSMutableDictionary *vendors = [NSMutableDictionary dictionary];
    NSNumber *currentClass;
    NSNumber *currentVendor;
    char buffer[256];
    long device_id, subclass_id;
    char *buf;
    bool class_parse = false;
    while(fgets(buffer, 256, handle)) {
        if (buffer[0]=='#') continue;
        if (strlen(buffer) <= 4) continue;
        buffer[strlen(buffer)-1]='\0';
        buf = buffer;
        if (*buf == 'C') class_parse = true;
        if (class_parse) {
            if (*buf == 0x09) {
                buf++;
                if (*buf != 0x09) {
                    subclass_id = strtol(buf, NULL, 16);
                    buf += 4;
                    while (*buf == ' ' || *buf == 0x09) buf++;
                    [[[classes objectForKey:currentClass] subClasses] setObject:@(buf) forKey:@(subclass_id)];
                }
            }
            else if (*buf == 'C') {
                buf += 2;
                currentClass = @(strtol(buf, NULL, 16));
                buf += 4;
                while (*buf == ' ' || *buf == 0x09) buf++;
                [classes setObject:[pciClass create:@(buf)] forKey:currentClass];
            }
        }
        else {
            if (*buf == 0x09) {
                buf++;
                if (*buf != 0x09) {
                    device_id = strtol(buf, NULL, 16);
                    buf += 4;
                    while (*buf == ' ' || *buf == 0x09) buf++;
                    [[[vendors objectForKey:currentVendor] devices] setObject:@(buf) forKey:@(device_id)];
                }
            }
            else if (*buf != '\\') {
                currentVendor = @(strtol(buf, NULL, 16));
                buf += 4;
                while (*buf == ' ' || *buf == 0x09) buf++;
                [vendors setObject:[pciVendor create:@(buf)] forKey:currentVendor];
            }
        }
    }
    fclose(handle);
    io_iterator_t itThis;
    if(IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("IOPCIDevice"), &itThis) == KERN_SUCCESS) {
        io_service_t service;
        while((service = IOIteratorNext(itThis))){
            [pcis addObject:[pciDevice create:service classes:classes vendors:vendors]];
            IOObjectRelease(service);
        }
        IOObjectRelease(itThis);
    }
    return pcis;
}
@end

@implementation pciVendor
-(void)setName:(NSString *)setname
{
    name = setname;
}
-(NSString *)name
{
    return(name);
}

-(void)setDevices:(NSMutableDictionary *)setdevices
{
    devices = setdevices;
}
-(NSMutableDictionary *)devices
{
    return(devices);
}

+(pciVendor *)create:(NSString *)name{
    pciVendor *temp = [pciVendor new];
    [temp setName:name];
    [temp setDevices:[NSMutableDictionary dictionary]];
    return temp;
}
@end

@implementation pciClass
-(void)setName:(NSString *)setname
{
    name = setname;
}
-(NSString *)name
{
    return(name);
}

-(void)setSubClasses:(NSMutableDictionary *)setsubClasses
{
    subClasses = setsubClasses;
}
-(NSMutableDictionary *)subClasses
{
    return(subClasses);
}

+(pciClass *)create:(NSString *)name{
    pciClass *temp = [pciClass new];
    [temp setName:name];
    [temp setSubClasses:[NSMutableDictionary dictionary]];
    return temp;
}
@end

#pragma mark Formatter
@implementation hexFormatter
+(BOOL)allowsReverseTransformation{
    return false;
}
+(Class)transformedValueClass{
    return [NSString class];
}
-(id)transformedValue:(id)value{
    return [NSString stringWithFormat:@"%04X",(unsigned int)[(NSNumber *)value integerValue]];
}
@end

@implementation HDA
+ (NSMutableDictionary *)voodooHDAwithIterator:(io_iterator_t)itThis
{
    io_service_t service;
    io_service_t parent;
    io_name_t name;
    
    NSMutableDictionary *temp = [NSMutableDictionary dictionary];
    NSString *pciFormat = @"0x%04X%04X";
    while((service = IOIteratorNext(itThis))) {
        IORegistryEntryGetParentEntry(service, kIOServicePlane, &parent);
        IORegistryEntryGetName(parent, name);
        pciDevice *audio = [pciDevice create:parent];
        io_connect_t connect;
        if(IOServiceOpen(service, mach_task_self(), 0, &connect)==KERN_SUCCESS){
            mach_vm_address_t address;
            mach_vm_size_t size;
            if(IOConnectMapMemory64(connect, 0x2000, mach_task_self(), &address, &size, kIOMapAnywhere|kIOMapDefaultCache)==KERN_SUCCESS){
                NSString *dump = [[NSString alloc] initWithBytes:(const void *)address length:(NSInteger)size encoding:NSUTF8StringEncoding];

                [[NSRegularExpression regularExpressionWithPattern:@"Codec ID: 0x([0-9a-f]{8})" options:0 error:nil] enumerateMatchesInString:dump options:0 range:NSMakeRange(0, [dump length]) usingBlock:^void(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop){
                    long codecid = strtol([[dump substringWithRange:[result rangeAtIndex:1]] UTF8String], NULL, 16);
                    char *codecname = NULL;
                    for(int n = 0; gCodecList[n].name; n++)
                        if(HDA_DEV_MATCH(gCodecList[n].id, codecid))
                        {
                            codecname = gCodecList[n].name;
                            break;
                        }
                    if(codecname == NULL)
                    {
                        codecname = (codecid == 0) ? "NULL Codec" : "Unknown Codec";
                    }
                    NSDictionary *spec = @{
                                           @"device":[NSString stringWithFormat:pciFormat,
                                                      (unsigned int)[audio.vendor integerValue],
                                                      (unsigned int)[audio.device integerValue]],
                                           @"subdevice":[NSString stringWithFormat:pciFormat,
                                                         (unsigned int)[audio.subVendor integerValue],
                                                         (unsigned int)[audio.subDevice integerValue]],
                                           @"model":[NSString stringWithUTF8String:codecname]
                                           };
                    [temp setObject:spec forKey:[NSString stringWithFormat:@"0x%08X", (unsigned int)codecid]];
                }];
                IOConnectUnmapMemory64(connect, 0x2000, mach_task_self(), address);
            }
            IOServiceClose(connect);
        }
        IOObjectRelease(parent);
        IOObjectRelease(service);
    }
    IOObjectRelease(itThis);
    if (DEBUG_MODE) {
        NSString *desk = [NSHomeDirectory() stringByAppendingPathComponent:@"Desktop/VOODOOHDA.plist"];
        NSLog(@"VOODOOHDA = %@\n", temp);
        [temp writeToFile:desk atomically:YES];
    }
    if (temp && temp.count > 0) return temp;
    return nil;
}

+ (NSMutableDictionary *)appleHDAwithIterator:(io_iterator_t)itThis
{
    NSMutableDictionary *temp = [NSMutableDictionary dictionary];
    NSString *pciFormat = @"0x%04X%04X";
    
    io_service_t service;
    io_service_t parent;
    io_name_t name;
    while((service = IOIteratorNext(itThis)))
    {
        IORegistryEntryGetParentEntry(service, kIOServicePlane, &parent);
        IORegistryEntryGetName(parent, name);
        io_service_t child;
        pciDevice *audio = [pciDevice create:parent];
        io_iterator_t itChild;
        if (IORegistryEntryGetChildIterator(service, kIOServicePlane, &itChild) == KERN_SUCCESS)
        {
            while ((child = IOIteratorNext(itChild)))
            {
                long codecid;
                long revisionid;
                char *codecname = NULL;
                CFNumberRef codec = (CFNumberRef)IORegistryEntryCreateCFProperty(child, CFSTR("IOHDACodecVendorID"), kCFAllocatorDefault, 0);
                if (!codec) return nil;
                CFNumberGetValue(codec, kCFNumberLongType, &codecid);
                codecid &= 0x00000000FFFFFFFF;
                CFRelease(codec);
                
                // Need to look for "IOHDACodecRevisionID" and parse it
                CFNumberRef revision = (CFNumberRef)IORegistryEntryCreateCFProperty(child, CFSTR("IOHDACodecRevisionID"), kCFAllocatorDefault, 0);
                CFNumberGetValue(revision, kCFNumberLongType, &revisionid);
                
                // First pass: match codecid abd revisionid?
                for(int n = 0; gCodecList[n].name; n++)
                {
                    if( HDA_DEV_MATCH(gCodecList[n].id, codecid) && HDA_DEV_MATCH(gCodecList[n].rev_id, revisionid) )
                    {
                        
                        codecname = gCodecList[n].name;
                        break;
                    }
                }

                // Second pass: match for "generic" codecid
                if( codecname == NULL )
                {
                    for(int n = 0; gCodecList[n].name; n++)
                    {
                        if( HDA_DEV_MATCH(gCodecList[n].id, codecid))
                        {
                            
                            codecname = gCodecList[n].name;
                            break;
                        }
                    }
                    // Here we facing the case where the codecid is not in the list
                    if( codecname == NULL )
                    {
                        codecname = (codecid==0) ? "NULL Codec" : "Unknown Codec";
                    }
                }

                NSDictionary *spec = @{
                                       @"device":[NSString stringWithFormat:pciFormat,
                                                  [audio.vendor integerValue],
                                                  [audio.device integerValue]],
                                       @"subdevice":[NSString stringWithFormat:pciFormat,
                                                     [audio.subVendor integerValue],
                                                     [audio.subDevice integerValue]],
                                       @"revisionid":[NSString stringWithFormat:@"0x%08lX",
                                                      revisionid],
                                       @"model":[NSString stringWithUTF8String:codecname]
                                       };
                [temp setObject:spec forKey:[NSString stringWithFormat:@"0x%08lX", codecid]];
                IOObjectRelease(child);
            }
            IOObjectRelease(itChild);
        }
        IOObjectRelease(parent);
        IOObjectRelease(service);
    }
    IOObjectRelease(itThis);
    IOObjectRelease(itThis);
    if (DEBUG_MODE) {
        NSString *desk = [NSHomeDirectory() stringByAppendingPathComponent:@"Desktop/APPLEHDA.plist"];
        NSLog(@"APPLEHDA = %@\n", temp);
        [temp writeToFile:desk atomically:YES];
    }
    if (temp && temp.count > 0) return temp;
    return nil;
}
@end

int main(int argc, const char * argv[])
{
    if (!getuid() && DEBUG_MODE) {
        printf("Error: You must not run this command as root user when in Debug Mode!\n");
        exit(2);
    }
    
    if( argc == 2 && (strcmp("-i",argv[1]) == 0))
    {
        printf("%s", kgetcodecInfo);
    }
    else if (argc > 2)
    {
        printf("%s", kgetcodecErrorUsage);
        EXIT_FAILURE;
    }
    else
    {
        // no matter other args print the codecs info..
        io_iterator_t itThis;
        
        @autoreleasepool
        {
            NSMutableDictionary *allCodecs = [NSMutableDictionary dictionary];
            // firstly see for VoodooHDA
            if(IOServiceGetMatchingServices(kIOMasterPortDefault,
                                            IOServiceMatching("VoodooHDADevice"), &itThis)==KERN_SUCCESS)
            {
                NSMutableDictionary *dict = [HDA voodooHDAwithIterator:itThis];
                if (dict) [allCodecs addEntriesFromDictionary:dict];
            }
            
            if (allCodecs.allKeys.count == 0)
            {
                itThis = NULL;
                // secondly see for AppleHDA
                /* in case of same codec-id entry in both dictionaries (voodoo + Apple), the first take object from the second
                 this ensure missing value (like the revision) to be merged from AppleHDA output!
                 */
                if(IOServiceGetMatchingServices(kIOMasterPortDefault,
                                                IOServiceMatching("AppleHDAController"), &itThis)==KERN_SUCCESS)
                {
                    NSMutableDictionary *dict = [HDA appleHDAwithIterator:itThis];
                    if (dict) [allCodecs addEntriesFromDictionary:dict];
                }
            }
            
            if (allCodecs && allCodecs.allKeys.count > 0)
            {
                for (NSString *codec in allCodecs.allKeys) {
                    NSMutableString *codecid, *revision, *device, *subdevice;
                    NSString  *model = [[allCodecs objectForKey:codec] objectForKey:@"model"];
                    
                    //-----------------------------------------------
                    codecid = [NSMutableString stringWithString:
                               [codec.lowercaseString  stringByReplacingOccurrencesOfString:@"0x" withString:@""]];
                    [codecid insertString:@":" atIndex:4];
                    //-----------------------------------------------
                    device    = [NSMutableString stringWithString:[[[[allCodecs objectForKey:codec]
                                                                     objectForKey:@"device"] lowercaseString]
                                                                   stringByReplacingOccurrencesOfString:@"0x" withString:@""]];
                    [device insertString:@":" atIndex:4];
                    //-----------------------------------------------
                    subdevice = [NSMutableString stringWithString:[[[[allCodecs objectForKey:codec]
                                                                     objectForKey:@"subdevice"] lowercaseString]
                                                                   stringByReplacingOccurrencesOfString:@"0x" withString:@""]];
                    [subdevice insertString:@":" atIndex:4];
                    //-----------------------------------------------
                    
                    // revision can or cannot show up ATM, crashing the code for a nil value
                    if ([[allCodecs objectForKey:codec] objectForKey:@"revisionid"]) {
                        //-----------------------------------------------
                        revision     = [NSMutableString stringWithString: [[[[allCodecs objectForKey:codec]
                                                                             objectForKey:@"revisionid"] lowercaseString]
                                                                           stringByReplacingOccurrencesOfString:@"0x" withString:@""]];
                        //-----------------------------------------------
                        printf("(AppleHDA)\t%s (%s) Rev.(%s)\n\t\tController %s (sub-ven:%s)\n",
                               model.UTF8String, codecid.UTF8String, revision.UTF8String, device.UTF8String, subdevice.UTF8String);
                    } else {
                        printf("(VoodooHDA)\t%s (%s)\n\t\tController %s (sub-ven:%s)\n",
                               model.UTF8String, codecid.UTF8String, device.UTF8String, subdevice.UTF8String);
                    }
                }
            }
            else
            {
                printf("no audio codecs found!\nBe sure to have AppleHDA or VoodooHDA somewere!\n");
                EXIT_FAILURE;// ie 1. In a bash script this can be intercepted. In this case comment the printf above to use custom output
            }
        }
    }
    EXIT_SUCCESS;
}
