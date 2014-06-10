//
//  NOStore.m
//  NetworkObjects
//
//  Created by Alsey Coleman Miller on 10/2/13.
//  Copyright (c) 2013 CDA. All rights reserved.
//

@import CoreData;
#import "NOStore.h"
#import "NetworkObjectsConstants.h"

@interface NOStore (Concurrency)

-(NSManagedObject<NOResourceProtocol> *)concurrentlyCreateNewResourceWithEntityDescription:(NSEntityDescription *)entityDescription
                                                                                   context:(NSManagedObjectContext **)context
                                                                                     error:(NSError **)error;

@end

@implementation NOStore

#pragma mark - Initialization

-(id)initWithPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)persistentStoreCoordinator
                             lastIDsURL:(NSURL *)lastIDsURL
{
    self = [super init];
    if (self) {
        
        // create context
        
        _context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        
        _context.undoManager = nil;
        
        // setup persistent store coordinator
        
        if (persistentStoreCoordinator) {
            
            self.context.persistentStoreCoordinator = persistentStoreCoordinator;
        }
        else {
            
            self.context.persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[NSManagedObjectModel mergedModelFromBundles:nil]];
        }
        
        
        // create a creation queue per NSManagedObject subclass that conforms to NOResourceProtocol
        
        NSMutableDictionary *creationQueuesDict = [[NSMutableDictionary alloc] init];
        
        for (NSEntityDescription *entityDescription in self.context.persistentStoreCoordinator.managedObjectModel.entities) {
            
            Class entityClass = NSClassFromString(entityDescription.managedObjectClassName);
            
            if ([entityClass conformsToProtocol:@protocol(NOResourceProtocol)]) {
                
                NSOperationQueue *operationQueue = [[NSOperationQueue alloc] init];
                
                operationQueue.maxConcurrentOperationCount = 1;
                
                operationQueue.name = [NSString stringWithFormat:@"com.ColemanCDA.NetworkObjects.NOStore%@CreationQueue", entityDescription.name];
                
                // add to mutable dict
                creationQueuesDict[entityDescription.name] = operationQueue;
            }
        }
        
        // setup last resource IDs dictionary
        
        _createResourcesQueues = [NSDictionary dictionaryWithDictionary:creationQueuesDict];
        
        _lastResourceIDs = [[NSMutableDictionary alloc] init];
        
        // load previously saved last resourceIDs
        
        if (lastIDsURL) {
            
            _lastIDsURL = lastIDsURL;
            
            NSDictionary *savedLastIDs = [NSDictionary dictionaryWithContentsOfURL:lastIDsURL];
            
            // not new store
            if (savedLastIDs) {
                
                [_lastResourceIDs addEntriesFromDictionary:savedLastIDs];
                                
            }
        }
    }
    return self;
}

-(instancetype)initWithConcurrentPersistanceDelegate:(id<NOStoreConcurrentPersistanceDelegate>)delegate;
{
    if (!delegate) {
        
        return nil;
    }
    
    self = [super init];
    
    if (self) {
        
        _concurrentPersistanceDelegate = delegate;
        
    }
    
    return self;
}

- (id)init
{
    return [[NOStore alloc] initWithPersistentStoreCoordinator:nil
                                                    lastIDsURL:nil];
}

#pragma mark - Generate new instances

-(NSManagedObjectContext *)newConcurrentContext
{
    if (!_concurrentPersistanceDelegate) {
        
        return nil;
    }
    
    NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    
    context.undoManager = nil;
    
    context.persistentStoreCoordinator = [_concurrentPersistanceDelegate newPersistentStoreCoordinatorForStore:self];
    
    return context;
}

#pragma mark - Manipulate Resources

-(NSManagedObject<NOResourceProtocol> *)resourceWithEntityDescription:(NSEntityDescription *)entityDescription
                                                           resourceID:(NSNumber *)resourceID
                                                       shouldPrefetch:(BOOL)shouldPrefetch
                                                              context:(NSManagedObjectContext *__autoreleasing *)contextPointer
                                                                error:(NSError *__autoreleasing *)error
{
    NSManagedObjectContext *context;
    
    if (_concurrentPersistanceDelegate) {
        
        // setup new context
        
        context = [self newConcurrentContext];
        
        if (contextPointer) {
            
            *contextPointer = context;
        }
    }
    
    else {
        
        context = _context;
        
        if (contextPointer) {
            
            *contextPointer = context;
        }
    }
    
    // get the key of the resourceID attribute
    
    NSString *resourceIDKey = [NSClassFromString(entityDescription.managedObjectClassName) resourceIDKey];
    
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:entityDescription.name];
    
    fetchRequest.fetchLimit = 1;
    
    fetchRequest.predicate = [NSComparisonPredicate predicateWithLeftExpression:[NSExpression expressionForKeyPath:resourceIDKey]
                                                                rightExpression:[NSExpression expressionForConstantValue:resourceID]
                                                                       modifier:NSDirectPredicateModifier
                                                                           type:NSEqualToPredicateOperatorType
                                                                        options:NSNormalizedPredicateOption];
    
    if (shouldPrefetch) {
        
        fetchRequest.returnsObjectsAsFaults = NO;
    }
    else {
        
        fetchRequest.includesPropertyValues = NO;
    }
    
    __block NSArray *result;
    
    [context performBlockAndWait:^{
        
        result = [context executeFetchRequest:fetchRequest
                                        error:error];
        
    }];
    
    if (!result) {
        
        return nil;
    }
    
    NSManagedObject<NOResourceProtocol> *resource = result.firstObject;
    
    return resource;
}

-(NSArray *)fetchResources:(NSEntityDescription *)entity
           withResourceIDs:(NSArray *)resourceIDs
            shouldPrefetch:(BOOL)shouldPrefetch
                   context:(NSManagedObjectContext *__autoreleasing *)contextPointer
                     error:(NSError *__autoreleasing *)error
{
    NSManagedObjectContext *context;
    
    if (_concurrentPersistanceDelegate) {
        
        // setup new context
        
        context = [self newConcurrentContext];
        
        if (contextPointer) {
            
            *contextPointer = context;
        }
        
    }
    
    else {
        
        context = _context;
        
        if (contextPointer) {
            
            *contextPointer = context;
        }
    }
    
    // get the key of the resourceID attribute
    
    NSString *resourceIDKey = [NSClassFromString(entity.managedObjectClassName) resourceIDKey];
    
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:entity.name];
    
    fetchRequest.fetchLimit = resourceIDs.count;
    
    fetchRequest.predicate = [NSComparisonPredicate predicateWithLeftExpression:[NSExpression expressionForKeyPath:resourceIDKey]
                                                                rightExpression:[NSExpression expressionForConstantValue:resourceIDs]
                                                                       modifier:NSDirectPredicateModifier
                                                                           type:NSInPredicateOperatorType
                                                                        options:NSNormalizedPredicateOption];
    
    if (shouldPrefetch) {
        
        fetchRequest.returnsObjectsAsFaults = NO;
    }
    else {
        
        fetchRequest.includesPropertyValues = NO;
    }
    
    __block NSArray *result;
    
    [context performBlockAndWait:^{
        
        result = [context executeFetchRequest:fetchRequest
                                         error:error];
        
    }];
    
    return result;
}

-(NSManagedObject<NOResourceProtocol> *)newResourceWithEntityDescription:(NSEntityDescription *)entityDescription
                                                                 context:(NSManagedObjectContext *__autoreleasing *)contextPointer
                                                                   error:(NSError *__autoreleasing *)error;
{
    if (_concurrentPersistanceDelegate) {
        
        return [self concurrentlyCreateNewResourceWithEntityDescription:entityDescription
                                                                context:contextPointer
                                                                  error:error];
    }
    
    if (contextPointer) {
        
        *contextPointer = _context;
    }
    
    // use the operationQueue for this resource
    
    NSOperationQueue *operationQueue = _createResourcesQueues[entityDescription.name];
    
    NSNumber *lastID = _lastResourceIDs[entityDescription.name];
    
    __block NSManagedObject<NOResourceProtocol> *newResource;
    
    // get resourceID attribute
    
    NSString *resourceIDKey = [NSClassFromString(entityDescription.managedObjectClassName) resourceIDKey];
    
    NSBlockOperation *blockOperation = [NSBlockOperation blockOperationWithBlock:^{
        
        [_context performBlockAndWait:^{
            
            // create new resource
            newResource = [NSEntityDescription insertNewObjectForEntityForName:entityDescription.name
                                                        inManagedObjectContext:_context];
            
            // set new resourceID
            NSNumber *resourceID;
            
            if (!lastID) {
                resourceID = @0;
            }
            else {
                resourceID = [NSNumber numberWithInteger:lastID.integerValue + 1];
            }
            
            [newResource setValue:resourceID
                           forKey:resourceIDKey];
            
            // set as last ID
            _lastResourceIDs[entityDescription.name] = resourceID;
            
        }];
    }];
    
    [operationQueue addOperations:@[blockOperation]
                waitUntilFinished:YES];
    
    return newResource;
}

#pragma mark - Save

-(BOOL)save:(NSError **)error
{
    if (_concurrentPersistanceDelegate) {
        
        [NSException raise:NSInternalInconsistencyException
                    format:@"Cannot call %@ on NOStore configured for concurrent persistance.", NSStringFromSelector(_cmd)];
        
        return NO;
    }
    
    
    BOOL savedLastIDs;
    
    NSDictionary *lastIDsBackup;
    
    // this will be nil for in-memory stores
    
    if (self.lastIDsURL) {
        
        // attempt to make backup
        
        lastIDsBackup = [NSDictionary dictionaryWithContentsOfURL:self.lastIDsURL];
        
        savedLastIDs = [self.lastResourceIDs writeToURL:self.lastIDsURL
                                             atomically:YES];
        
        if (!savedLastIDs) {
            
            if (error) {
                
                NSString *localizedDescription = NSLocalizedString(@"Could not backup previous lastIDs archived dictionary",
                                                                   @"NOStore Save Backup Error Description");
                
                *error = [NSError errorWithDomain:NetworkObjectsErrorDomain
                                             code:NOStoreBackupLastIDsSaveError
                                         userInfo:@{NSLocalizedDescriptionKey: localizedDescription}];
            }
            
            return NO;
        }
    }
    
    // save context
    __block NSError *saveContextError;
    
    [_context performBlockAndWait:^{
        
        [_context save:&saveContextError];
        
    }];
    
    // restore lastIDs file becuase the Core Data save failed
    if (saveContextError && savedLastIDs && lastIDsBackup) {
        
        // restore saved lastIDs
        BOOL restoreLastIDs = [lastIDsBackup writeToURL:self.lastIDsURL
                                             atomically:YES];
        
        if (!restoreLastIDs) {
            
            if (error) {
                
                NSString *localizedDescription = NSLocalizedString(@"Could not restore lastIDs file to value before failed context save operation.", @"NOStore Restore Backup Error Description");
                
                *error = [NSError errorWithDomain:NetworkObjectsErrorDomain
                                             code:NOStoreRestoreLastIDsSaveError
                                         userInfo:@{NSLocalizedDescriptionKey: localizedDescription,
                                                    NSUnderlyingErrorKey: saveContextError}];
            }
            
            return NO;
            
        }
        
        if (error) {
            
            *error = saveContextError;
        }
        
        return NO;
    }
    
    if (saveContextError) {
        
        if (error) {
            
            *error = saveContextError;
        }
        
        return NO;
    }
    
    return YES;
}

@end

#pragma mark - Categories

@implementation NOStore (Concurrency)

-(NSManagedObject<NOResourceProtocol> *)concurrentlyCreateNewResourceWithEntityDescription:(NSEntityDescription *)entityDescription
                                                                                   context:(NSManagedObjectContext **)contextPointer
                                                                                     error:(NSError *__autoreleasing *)error
{
    NSManagedObjectContext *context = [self newConcurrentContext];
    
    if (contextPointer) {
        
        *contextPointer = context;
    }
    
    __block NSManagedObject<NOResourceProtocol> *resource;
    
    [context performBlockAndWait:^{
        
        resource = [NSEntityDescription insertNewObjectForEntityForName:entityDescription.name
                                                                                      inManagedObjectContext:context];
        
        // set resource ID
        
        NSString *resourceIDKey = [NSClassFromString(entityDescription.managedObjectClassName) resourceIDKey];
       
        [resource setValue:[_concurrentPersistanceDelegate store:self newResourceIDForResource:entityDescription.name]
                    forKey:resourceIDKey];
        
        if (![context save:error]) {
            
            resource = nil;
        }
        
    }];
    
    return resource;
}

@end
