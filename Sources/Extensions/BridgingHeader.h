#import <objc/NSObject.h>

BOOL SLSGetAppearanceThemeLegacy();
void SLSSetAppearanceThemeLegacy(BOOL);

typedef void (^NSGlobalPreferenceTransitionBlock)(void);

@interface NSGlobalPreferenceTransition : NSObject

+ (id)transition;
- (void)postChangeNotification:(unsigned long long)arg1  
completionHandler:(NSGlobalPreferenceTransitionBlock)arg2;

@end
