//
//  NSURL+Utils.m
//  Locky
//
//  Created by Nicolas Dominati on 13/03/15.
//  Copyright (c) 2015 Lunabee Pte Ltd. All rights reserved.
//

#import "NSURL+Utils.h"

@implementation NSURL (Utils)

- (BOOL)fileExists
{
	return [[NSFileManager defaultManager] fileExistsAtPath:self.path];
}

- (long long)sizeInBytes
{
	if  ([self fileExists])
	{
		if ([self isDirectory])
		{
			NSArray *contentOfDirectory = [self contentOfDirectory];
			long long size=0;
			for (NSURL *url in contentOfDirectory)
			{
				size+=[url sizeInBytes];
			}
			
			return size;
		}
		else
		{
			NSNumber *fileSize=[self attributeOfItemForKey:NSFileSize];
			return [fileSize longLongValue];
		}
		
	}
	return 0;
}

- (NSArray *)contentOfDirectory
{
	if (![self fileExists])
	{
		return nil;
	}
	
	NSFileManager *fileMgr = [[NSFileManager alloc] init];
	NSError *error = nil;
	NSArray *urlList = [fileMgr contentsOfDirectoryAtURL:self includingPropertiesForKeys:[NSArray arrayWithObject:NSURLIsDirectoryKey] options:NSDirectoryEnumerationSkipsHiddenFiles error:&error];
	
	return urlList;
}

- (BOOL)isDirectory
{
	if ([self fileExists])
	{
		NSString *status=[self attributeOfItemForKey:NSFileType];
		if ([status isEqualToString:NSFileTypeDirectory])
		{
			return TRUE;
		}
	}
	
	return FALSE;
}

- (id)attributeOfItemForKey:(NSString *)key
{
	NSError *error=nil;
	
	NSDictionary *fileDict = [[NSFileManager defaultManager] attributesOfItemAtPath:[self path] error:&error];
	if (fileDict==nil)
	{
		NSLog(@"No values found.");
	}
	return [fileDict objectForKey:key];
}

+ (NSString *)formatSize:(long long) byteSize
{
	float floatSize=byteSize;
	if (floatSize<1023)
		return([NSString stringWithFormat:NSLocalizedString(@"%i bytes",@"%i bytes"),byteSize]);
	floatSize = floatSize / 1024;
	if (floatSize<1023)
		return([NSString stringWithFormat:NSLocalizedString(@"%1.1f KB",@"%1.1f KB"),floatSize]);
	floatSize = floatSize / 1024;
	if (floatSize<1023)
		return([NSString stringWithFormat:NSLocalizedString(@"%1.1f MB",@"%1.1f MB"),floatSize]);
	floatSize = floatSize / 1024;
	
	return([NSString stringWithFormat:NSLocalizedString(@"%1.1f GB",@"%1.1f GB"),floatSize]);
}

@end