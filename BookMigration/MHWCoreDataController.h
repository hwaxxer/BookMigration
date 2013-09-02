//
//  MHWCoreDataController.h
//  BookMigration
//
//  Created by Martin Hwasser on 8/26/13.
//  Copyright (c) 2013 Martin Hwasser. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface MHWCoreDataController : NSObject

+ (void)setSourceStoreURL:(NSURL *)url;
+ (MHWCoreDataController *)sharedInstance;

- (BOOL)isMigrationNeeded;
- (BOOL)migrate:(NSError *__autoreleasing *)error;

@property (nonatomic, readonly, strong) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, readonly, strong) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, readonly, strong) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@end
