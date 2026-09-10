import AppKit
import MetalKit

@MainActor final class SurfaceProbe:MTKView {
    var suppressDrawable=false
    var staleDrawable:CAMetalDrawable?
    var supplied:CAMetalDrawable?
    var requests=0
    override var currentDrawable:CAMetalDrawable? {
        requests+=1
        let result=suppressDrawable ? nil:(staleDrawable ?? super.currentDrawable)
        supplied=result
        return result
    }
}

@main struct SurfaceLifecycleValidation {
    @MainActor static func main() async throws {
        let app=NSApplication.shared
        app.setActivationPolicy(.accessory)
        let device=MTLCreateSystemDefaultDevice()!
        let library=try device.makeLibrary(URL:URL(fileURLWithPath:CommandLine.arguments[1]))
        let renderer=try LabBoardRenderer(device:device,library:library)
        renderer.install(game:LabBoardGame(state:LabBoardPuzzle.deepCurrent.initial))
        renderer.quality = .high
        let original=renderer.particleSamples()
        let window=NSWindow(contentRect:NSRect(x:80,y:80,width:900,height:350),styleMask:[.titled],backing:.buffered,defer:false)
        window.title="Vials surface regression check"
        func makeSurface()->SurfaceProbe {
            let view=SurfaceProbe(frame:NSRect(x:0,y:0,width:900,height:350),device:device)
            view.colorPixelFormat = .bgra8Unorm_srgb;view.autoResizeDrawable=false;view.isPaused=true
            // Resize invalidation is exercised through the actual delegate callback.
            view.delegate=renderer
            return view
        }
        func require(_ value:Bool,_ message:String) { if !value { fatalError(message) } }
        let first=makeSurface();window.contentView=first;window.orderFront(nil)
        try await Task.sleep(for:.milliseconds(150))
        first.suppressDrawable=true;first.draw()
        CATransaction.flush()
        try await Task.sleep(for:.milliseconds(100))
        let nilRequests=first.requests
        first.suppressDrawable=false;first.releaseDrawables();first.draw()
        require(first.requests>nilRequests && first.supplied != nil,"Missing drawable incorrectly cached as a rendered idle frame")
        CATransaction.flush()
        try await Task.sleep(for:.milliseconds(100))
        first.releaseDrawables();first.draw()
        _=renderer.particleSamples()
        let idleRequests=first.requests;first.draw()
        require(first.requests==idleRequests,"Idle surface keeps acquiring drawables")
        let second=makeSurface();window.contentView=second
        try await Task.sleep(for:.milliseconds(100))
        second.draw()
        require(second.supplied != nil,"Replacement surface skipped its initial frame")
        _=renderer.particleSamples()
        let old=second.supplied!
        window.setContentSize(NSSize(width:620,height:600));second.frame=NSRect(x:0,y:0,width:620,height:600)
        second.staleDrawable=old;second.draw()
        let staleRequests=second.requests
        CATransaction.flush()
        try await Task.sleep(for:.milliseconds(100))
        second.staleDrawable=nil;second.releaseDrawables();second.draw()
        require(second.requests>staleRequests,"Stale-size drawable cached as a completed resize")
        require(second.supplied?.texture.width==930 && second.supplied?.texture.height==900,"Drawable did not catch up with portrait bounds")
        require(renderer.particleSamples().map(\.position)==original.map(\.position),"Idle view replacement changed fluid positions")
        window.orderOut(nil)
        print("PASS: retry missing drawable, idle suppression, replacement surface, stale-size retry, portrait resize, preserved fluid positions")
    }
}
