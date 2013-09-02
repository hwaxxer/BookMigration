//
//  MHWMigrationManager.h
//  BookMigration
//
//  Created by Martin Hwasser on 8/30/13.
//  Copyright (c) 2013 Martin Hwasser. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MHWMigrationManager;

@protocol MHWMigrationManagerDelegate <NSObject>

@optional
- (void)migrationManager:(MHWMigrationManager *)migrationManager migrationProgress:(float)migrationProgress;

@end

@interface MHWMigrationManager : NSObject

- (BOOL)progressivelyMigrateURL:(NSURL *)sourceStoreURL
                         ofType:(NSString *)type
                        toModel:(NSManagedObjectModel *)finalModel
                          error:(NSError **)error;

@property (nonatomic, weak) id<MHWMigrationManagerDelegate> delegate;

@end
