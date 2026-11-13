#import <AppKit/AppKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

#include <stdio.h>
#include <stdlib.h>

static void suppress_activation(NSApplication *app, SEL action) {
    // Godot's activation method would bring this process to the foreground.
}

static BOOL use_accessory_policy(NSApplication *app, SEL action, NSApplicationActivationPolicy requested) {
    // Intercept the initial Regular policy before it can register a Dock icon.
    struct objc_super superclass = {app, [NSApplication class]};
    return ((BOOL (*)(struct objc_super *, SEL, NSApplicationActivationPolicy))objc_msgSendSuper)(
            &superclass, action, NSApplicationActivationPolicyAccessory);
}

static void order_background_window(NSWindow *window, SEL action, id sender) {
    // Keep an ordered OpenGL drawable, but never show pixels or take input.
    if (NSApp.activationPolicy != NSApplicationActivationPolicyAccessory) {
        fputs("Godot benchmark did not start as a background app.\n", stderr);
        _Exit(78);
    }
    window.alphaValue = 0.0;
    window.ignoresMouseEvents = YES;
    [window orderFrontRegardless];
}

static void keep_background_draw_eligible(id delegate, SEL action, NSNotification *notification) {
    // Godot 4.7.1's callback overwrites the initially true WindowData.is_visible
    // with the compositor occlusion flag. This benchmark still needs to render.
}

static BOOL replace_method(Class cls, SEL selector, IMP replacement) {
    if (cls == Nil) return NO;
    Method method = class_getInstanceMethod(cls, selector);
    if (method == NULL) return NO;
    class_replaceMethod(cls, selector, replacement, method_getTypeEncoding(method));
    return YES;
}

__attribute__((constructor))
static void configure_background_window(void) {
    Class application = objc_getClass("GodotApplication");
    BOOL policy = replace_method(application, @selector(setActivationPolicy:), (IMP)use_accessory_policy);
    BOOL activation = replace_method(application,
            sel_registerName("activateApplication"), (IMP)suppress_activation);
    BOOL window = replace_method(objc_getClass("GodotWindow"),
            @selector(makeKeyAndOrderFront:), (IMP)order_background_window);
    BOOL occlusion = replace_method(objc_getClass("GodotWindowDelegate"),
            @selector(windowDidChangeOcclusionState:), (IMP)keep_background_draw_eligible);
    if (!policy || !activation || !window || !occlusion) {
        fputs("Godot background window setup failed.\n", stderr);
        _Exit(78);
    }
    if (getenv("TAVERN_DUEL_BACKGROUND_PREFLIGHT") != NULL) {
        puts("TAVERN_DUEL_BACKGROUND_READY");
    }
}
