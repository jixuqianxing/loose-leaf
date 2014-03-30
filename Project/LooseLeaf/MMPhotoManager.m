//
//  MMPhotoManager.m
//  LooseLeaf
//
//  Created by Adam Wulf on 3/30/14.
//  Copyright (c) 2014 Milestone Made, LLC. All rights reserved.
//

#import "MMPhotoManager.h"

@implementation MMPhotoManager{
    BOOL hasEverInitailized;
    ALAssetsLibrary* assetsLibrary;
    
    NSArray* faces;
    NSArray* events;
    NSArray* albums;
    MMPhotoAlbum* cameraRoll;
}

@synthesize delegate;

static MMPhotoManager* _instance = nil;

-(id) init{
    if(_instance) return _instance;
    if((self = [super init])){
        _instance = self;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(albumAdded:) name:ALAssetLibraryInsertedAssetGroupsKey object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(albumUpdated:) name:ALAssetLibraryUpdatedAssetGroupsKey object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(albumDeleted:) name:ALAssetLibraryDeletedAssetGroupsKey object:nil];
    }
    return _instance;
}

+(MMPhotoManager*) sharedInstace{
    if(!_instance){
        _instance = [[MMPhotoManager alloc]init];
    }
    return _instance;
}

#pragma mark - Properties

-(ALAssetsLibrary*) assetsLibrary{
    if(!assetsLibrary){
        assetsLibrary = [[ALAssetsLibrary alloc] init];
    }
    return assetsLibrary;
}

-(NSUInteger) countOfAlbums{
    return [albums count] + [events count] + [faces count];
}

-(NSArray*) albums{
    return [NSArray arrayWithArray:albums];
}

-(NSArray*) events{
    return [NSArray arrayWithArray:events];
}

-(NSArray*) faces{
    return [NSArray arrayWithArray:faces];
}

-(MMPhotoAlbum*) cameraRoll{
    return cameraRoll;
}

#pragma mark - Notifications

NSArray*(^arrayByRemovingObjectWithURL)(NSArray* arr, NSURL* url) = ^NSArray*(NSArray* arr, NSURL* url){
    NSMutableArray* retArr = [NSMutableArray array];
    for(id obj in arr){
        if(![url isEqual:obj]){
            [retArr addObject:obj];
        }
    }
    return [NSArray arrayWithArray:retArr];
};

-(void) albumAdded:(NSURL*)urlOfUpdatedAlbum{
    [[self assetsLibrary] groupForURL:urlOfUpdatedAlbum
                          resultBlock:^(ALAssetsGroup *group) {
                              MMPhotoAlbum* addedAlbum = [[MMPhotoAlbum alloc] initWithAssetGroup:group];
                              if(addedAlbum.type == ALAssetsGroupAlbum){
                                  albums = [self sortArrayByAlbumName:[albums arrayByAddingObject:addedAlbum]];
                              }else if(addedAlbum.type == ALAssetsGroupEvent){
                                  events = [self sortArrayByAlbumName:[events arrayByAddingObject:addedAlbum]];
                              }else if(addedAlbum.type == ALAssetsGroupFaces){
                                  faces = [self sortArrayByAlbumName:[faces arrayByAddingObject:addedAlbum]];
                              }else if(addedAlbum.type == ALAssetsGroupSavedPhotos){
                                  cameraRoll = addedAlbum;
                              }
                          }
                         failureBlock:^(NSError *error) {
                             [self processError:error];
                         }];
}

-(void) albumUpdated:(NSURL*)urlOfUpdatedAlbum{
    [[self assetsLibrary] groupForURL:urlOfUpdatedAlbum
                          resultBlock:^(ALAssetsGroup *group) {
                              MMPhotoAlbum* addedAlbum = [[MMPhotoAlbum alloc] initWithAssetGroup:group];
                              if(addedAlbum.type == ALAssetsGroupAlbum){
                                  albums = [self sortArrayByAlbumName:[arrayByRemovingObjectWithURL(albums, urlOfUpdatedAlbum) arrayByAddingObject:addedAlbum]];
                              }else if(addedAlbum.type == ALAssetsGroupEvent){
                                  events = [self sortArrayByAlbumName:[arrayByRemovingObjectWithURL(events, urlOfUpdatedAlbum) arrayByAddingObject:addedAlbum]];
                              }else if(addedAlbum.type == ALAssetsGroupFaces){
                                  faces = [self sortArrayByAlbumName:[arrayByRemovingObjectWithURL(faces, urlOfUpdatedAlbum) arrayByAddingObject:addedAlbum]];
                              }else if(addedAlbum.type == ALAssetsGroupSavedPhotos){
                                  cameraRoll = addedAlbum;
                              }
                          }
                         failureBlock:^(NSError *error) {
                             [self processError:error];
                         }];
}

-(void) albumDeleted:(NSURL*)urlOfUpdatedAlbum{
    albums = arrayByRemovingObjectWithURL(albums, urlOfUpdatedAlbum);
    events = arrayByRemovingObjectWithURL(events, urlOfUpdatedAlbum);
    faces = arrayByRemovingObjectWithURL(faces, urlOfUpdatedAlbum);
}


#pragma mark - Initialization

-(NSArray*) sortArrayByAlbumName:(NSArray*)arrayToSort{
    NSComparisonResult (^sortByName)(id obj1, id obj2) = ^NSComparisonResult(id obj1, id obj2){
        return [[obj1 name] compare:[obj2 name] options:NSCaseInsensitiveSearch | NSNumericSearch];
    };
    return [arrayToSort sortedArrayUsingComparator:sortByName];
}

/**
 * initialize the repository of photo albums
 */
-(void) initializeAlbumCache:(NSError**)err{
    if(hasEverInitailized){
        // if i've initialized once, then i'm done
        // just notify that we've got all our stuff
        // loaded
        [self.delegate doneLoadingPhotoAlbums];
        return;
    }
    
    NSMutableArray* updatedAlbumsList = [NSMutableArray array];
    NSMutableArray* updatedEventsList = [NSMutableArray array];
    NSMutableArray* updatedFacesList = [NSMutableArray array];
    __block MMPhotoAlbum* savedPhotos = nil;
    
    [[self assetsLibrary] enumerateGroupsWithTypes:ALAssetsGroupAlbum | ALAssetsGroupEvent | ALAssetsGroupFaces | ALAssetsGroupSavedPhotos
                                 usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
                                     [group setAssetsFilter:[ALAssetsFilter allPhotos]];
                                     if(!group){
                                         // there is no group if we're all done iterating.
                                         // sort our results and create an array of all our albums
                                         // from albums -> events -> faces order
                                         albums = [self sortArrayByAlbumName:updatedAlbumsList];
                                         events = [self sortArrayByAlbumName:updatedEventsList];
                                         faces = [self sortArrayByAlbumName:updatedFacesList];
                                         cameraRoll = savedPhotos;
                                         hasEverInitailized = YES;
                                         [self.delegate doneLoadingPhotoAlbums];
                                     }else if ([group numberOfAssets] > 0){
                                         if(group.type == ALAssetsGroupAlbum){
                                             [updatedAlbumsList addObject:[[MMPhotoAlbum alloc] initWithAssetGroup:group]];
                                         }else if(group.type == ALAssetsGroupEvent){
                                             [updatedEventsList addObject:[[MMPhotoAlbum alloc] initWithAssetGroup:group]];
                                         }else if(group.type == ALAssetsGroupFaces){
                                             [updatedFacesList addObject:[[MMPhotoAlbum alloc] initWithAssetGroup:group]];
                                         }else if(group.type == ALAssetsGroupSavedPhotos){
                                             savedPhotos = [[MMPhotoAlbum alloc] initWithAssetGroup:group];
                                         }
                                     }
                                 }
                               failureBlock:^(NSError *error) {
                                   *err = [self processError:error];
                               }];
}


-(NSError*) processError:(NSError*)error{
    NSString *errorMessage = nil;
    switch ([error code]) {
        case ALAssetsLibraryAccessUserDeniedError:
        case ALAssetsLibraryAccessGloballyDeniedError:
            errorMessage = @"The user has declined access to it.";
            break;
        default:
            errorMessage = @"Reason unknown.";
            break;
    }
    hasEverInitailized = NO;
    faces = nil;
    events = nil;
    albums = nil;
    cameraRoll = nil;

    return [NSError errorWithDomain:@"com.milestonemade.looseleaf" code:kPermissionDeniedError userInfo:nil];

}



@end