//
//  MHWMigrationManager.m
//  BookMigration
//
//  Created by Martin Hwasser on 8/30/13.
//  Copyright (c) 2013 Martin Hwasser. All rights reserved.
//

#import "MHWMigrationManager.h"

@implementation MHWMigrationManager

#pragma mark -
#pragma mark - Migration

//START:progressivelyMigrateURLMethodName
- (BOOL)progressivelyMigrateURL:(NSURL *)sourceStoreURL
                         ofType:(NSString *)type
                        toModel:(NSManagedObjectModel *)finalModel
                          error:(NSError **)error
{
    NSDictionary *sourceMetadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:type
                                                                                              URL:sourceStoreURL
                                                                                            error:error];
    if (!sourceMetadata) {
        return NO;
    }

    if ([finalModel isConfiguration:nil
        compatibleWithStoreMetadata:sourceMetadata]) {
        if (NULL != error) {
            *error = nil;
        }
        return YES;
    }

    //Find the source model
    NSManagedObjectModel *sourceModel = [NSManagedObjectModel mergedModelFromBundles:@[[NSBundle mainBundle]]
                                                                    forStoreMetadata:sourceMetadata];

    NSArray *modelPaths = [self modelPaths];
    
    if (!modelPaths.count) {
        //Throw an error if there are no models
        if (NULL != error) {
            *error = [NSError errorWithDomain:@"Zarra"
                                         code:8001
                                     userInfo:@{ NSLocalizedDescriptionKey : @"No models found!" }];
        }
        return NO;
    }

    //See if we can find a matching destination model
    NSMappingModel *mappingModel = nil;
    NSManagedObjectModel *targetModel = nil;
    NSString *modelPath = nil;
    for (modelPath in modelPaths) {
        targetModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:[NSURL fileURLWithPath:modelPath]];
        mappingModel = [NSMappingModel mappingModelFromBundles:@[[NSBundle mainBundle]]
                                                forSourceModel:sourceModel
                                              destinationModel:targetModel];
        //If we found a mapping model then proceed
        if (mappingModel) break;
    }

    //We have tested every model, if nil here we failed
    if (!mappingModel) {
        if (NULL != error) {
            *error = [NSError errorWithDomain:@"Zarra"
                                         code:8001
                                     userInfo:@{ NSLocalizedDescriptionKey : @"No mapping model found in bundle" }];
        }
        return NO;
    }

    //We have a mapping model and a destination model.  Time to migrate
    NSMigrationManager *manager = [[NSMigrationManager alloc] initWithSourceModel:sourceModel
                                                                 destinationModel:targetModel];

    NSString *modelName = [modelPath.lastPathComponent stringByDeletingPathExtension];
    NSString *storeExtension = [sourceStoreURL.path pathExtension];
    NSString *storePath = [sourceStoreURL.path stringByDeletingPathExtension];
    //Build a path to write the new store
    storePath = [NSString stringWithFormat:@"%@.%@.%@", storePath, modelName, storeExtension];
    NSURL *destinationStoreURL = [NSURL fileURLWithPath:storePath];

    [manager addObserver:self
              forKeyPath:@"migrationProgress"
                 options:NSKeyValueObservingOptionNew
                 context:nil];

    BOOL didMigrate = [manager migrateStoreFromURL:sourceStoreURL
                                              type:type
                                           options:nil
                                  withMappingModel:mappingModel
                                  toDestinationURL:destinationStoreURL
                                   destinationType:type
                                destinationOptions:nil
                                             error:error];
    [manager removeObserver:self
                 forKeyPath:@"migrationProgress"];

    if (!didMigrate) {
        return NO;
    }

    //Migration was successful, move the files around to preserve the source
    NSString *guid = [[NSProcessInfo processInfo] globallyUniqueString];
    guid = [guid stringByAppendingPathExtension:modelName];
    guid = [guid stringByAppendingPathExtension:storeExtension];
    NSString *appSupportPath = [storePath stringByDeletingLastPathComponent];
    NSString *backupPath = [appSupportPath stringByAppendingPathComponent:guid];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager moveItemAtPath:[sourceStoreURL path]
                              toPath:backupPath
                               error:error]) {
        //Failed to copy the file
        return NO;
    }
    //Move the destination to the source path
    if (![fileManager moveItemAtPath:storePath
                              toPath:[sourceStoreURL path]
                               error:error]) {
        //Try to back out the source move first, no point in checking it for errors
        [fileManager moveItemAtPath:backupPath
                             toPath:[sourceStoreURL path]
                              error:nil];
        return NO;
    }

    //We may not be at the "current" model yet, so recurse
    return [self progressivelyMigrateURL:sourceStoreURL
                                  ofType:type
                                 toModel:finalModel
                                   error:error];
}

- (NSArray *)modelPaths
{
    //Find all of the mom and momd files in the Resources directory
    NSMutableArray *modelPaths = [NSMutableArray array];
    NSArray *momdArray = [[NSBundle mainBundle] pathsForResourcesOfType:@"momd"
                                                            inDirectory:nil];
    for (NSString *momdPath in momdArray) {
        NSString *resourceSubpath = [momdPath lastPathComponent];
        NSArray *array = [[NSBundle mainBundle] pathsForResourcesOfType:@"mom"
                          inDirectory:resourceSubpath];
        [modelPaths addObjectsFromArray:array];
    }
    NSArray *otherModels = [[NSBundle mainBundle] pathsForResourcesOfType:@"mom"
                                                              inDirectory:nil];
    [modelPaths addObjectsFromArray:otherModels];
    return modelPaths;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if ([keyPath isEqualToString:@"migrationProgress"]) {
        if ([self.delegate respondsToSelector:@selector(migrationManager:migrationProgress:)]) {
            [self.delegate migrationManager:self migrationProgress:[(NSMigrationManager *)object migrationProgress]];
        }
    } else {
        [super observeValueForKeyPath:keyPath
                             ofObject:object
                               change:change
                              context:context];
    }
}

@end
