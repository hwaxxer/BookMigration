//
//  MHWCoreDataController.m
//  BookMigration
//
//  Created by Martin Hwasser on 8/26/13.
//  Copyright (c) 2013 Martin Hwasser. All rights reserved.
//

#import "MHWCoreDataController.h"
#import "NSFileManager+MHWAdditions.h"
#import "MHWMigrationManager.h"

@interface MHWCoreDataController () <MHWMigrationManagerDelegate>

@property (nonatomic, readwrite, strong) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, readwrite, strong) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, readwrite, strong) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@end

@implementation MHWCoreDataController

static NSURL *sourceStoreURL = nil;

+ (void)setSourceStoreURL:(NSURL *)url
{
    sourceStoreURL = url;
}

+ (MHWCoreDataController *)sharedInstance
{
    static MHWCoreDataController *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [MHWCoreDataController new];
    });
    return sharedInstance;
}

- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }

    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    _managedObjectContext = [[NSManagedObjectContext alloc] init];
    _managedObjectContext.persistentStoreCoordinator = coordinator;

    return _managedObjectContext;
}

- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }

    NSString *momPath = [[NSBundle mainBundle] pathForResource:@"Model"
                                                        ofType:@"momd"];

    if (!momPath) {
        momPath = [[NSBundle mainBundle] pathForResource:@"Model"
                                                  ofType:@"mom"];
    }

    NSURL *url = [NSURL fileURLWithPath:momPath];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:url];
    return _managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }

    NSError *error = nil;

    NSManagedObjectModel *mom = [self managedObjectModel];

    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];

    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                   configuration:nil
                                                             URL:[self sourceStoreURL]
                                                         options:nil
                                                           error:&error]) {

        NSFileManager *fileManager = [NSFileManager new];
        [fileManager removeItemAtPath:[self sourceStoreURL].path error:nil];

        [[[UIAlertView alloc] initWithTitle:@"Ouch"
                                    message:@"A serious error occurred."
                                   delegate:nil
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil] show];
    }

    return _persistentStoreCoordinator;
}

- (NSURL *)sourceStoreURL
{
    return [[NSFileManager urlToApplicationSupportDirectory] URLByAppendingPathComponent:@"Model.sqlite"];
}

- (NSString *)sourceStoreType
{
    return NSSQLiteStoreType;
}

- (NSDictionary *)sourceMetadata:(NSError **)error
{
    return [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:[self sourceStoreType]
                                                                      URL:[self sourceStoreURL]
                                                                    error:error];
}

- (BOOL)isMigrationNeeded
{
    NSError *error = nil;

    // Check if we need to migrate
    NSDictionary *sourceMetadata = [self sourceMetadata:&error];
    BOOL isMigrationNeeded = NO;

    if (sourceMetadata != nil) {
        NSManagedObjectModel *destinationModel = [self managedObjectModel];
        // Migration is needed if destinationModel is NOT compatible
        isMigrationNeeded = ![destinationModel isConfiguration:nil
                                   compatibleWithStoreMetadata:sourceMetadata];
    }
    NSLog(@"isMigrationNeeded: %d", isMigrationNeeded);
    return isMigrationNeeded;
}

- (BOOL)migrate:(NSError *__autoreleasing *)error
{
    // Enable migrations to run even while user exits app
    __block UIBackgroundTaskIdentifier bgTask;
    bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];

    MHWMigrationManager *migrationManager = [MHWMigrationManager new];
    migrationManager.delegate = self;
    
    BOOL OK = [migrationManager progressivelyMigrateURL:[self sourceStoreURL]
                                                 ofType:[self sourceStoreType]
                                                toModel:[self managedObjectModel]
                                                  error:error];
    if (OK) {
        NSLog(@"migration complete");
    }

    // Mark it as invalid
    [[UIApplication sharedApplication] endBackgroundTask:bgTask];
    bgTask = UIBackgroundTaskInvalid;
    return OK;
}

- (void)migrationManager:(MHWMigrationManager *)migrationManager migrationProgress:(float)migrationProgress
{
    NSLog(@"migration progress: %f", migrationProgress);
}

@end
