//
//  MHWCoreDataTests.m
//  BookMigration
//
//  Created by Martin Hwasser on 8/31/13.
//  Copyright (c) 2013 Martin Hwasser. All rights reserved.
//

#import "MHWCoreDataTests.h"
#import "MHWMigrationManager.h"

@implementation MHWCoreDataTests

- (void)setUpCoreDataStackMigratingFromStoreWithName:(NSString *)name
{
    // Create a unique url every test so migration always runs
    NSString *uniqueName = [NSProcessInfo processInfo].globallyUniqueString;
    NSURL *storeURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingString:uniqueName]];

    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSFileManager *fileManager = [NSFileManager new];
    [fileManager copyItemAtPath:[bundle pathForResource:[name stringByDeletingPathExtension] ofType:name.pathExtension]
                         toPath:storeURL.path error:nil];

    NSURL *momURL = [[NSBundle mainBundle] URLForResource:@"Model" withExtension:@"momd"];
    self.managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:momURL];

    MHWMigrationManager *migrationManager = [MHWMigrationManager new];
    [migrationManager progressivelyMigrateURL:storeURL
                                       ofType:NSSQLiteStoreType
                                      toModel:self.managedObjectModel
                                        error:nil];

    self.persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.managedObjectModel];
    [self.persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                  configuration:nil
                                                            URL:storeURL
                                                        options:nil
                                                          error:nil];

    self.managedObjectContext = [[NSManagedObjectContext alloc] init];
    self.managedObjectContext.persistentStoreCoordinator = self.persistentStoreCoordinator;
}

@end
