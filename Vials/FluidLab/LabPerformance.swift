import Foundation
import os
#if canImport(UIKit)
import UIKit
#endif

struct LabTrialConfiguration {
    let presentation:LabBoardPresentation
    let pace:LabBoardPace
    let seconds:Double
    let puzzle:LabBoardPuzzle
    let quality:LabRenderQuality
    static var current:Self? {
        let args=ProcessInfo.processInfo.arguments
        guard args.contains("--lab-trial") else { return nil }
        func option(_ name:String,_ fallback:String) -> String { guard let i=args.firstIndex(of:name),i+1<args.count else { return fallback };return args[i+1] }
        return Self(presentation:LabBoardPresentation(rawValue:option("--presentation","fluid")) ?? .fluid,
            pace:LabBoardPace(rawValue:option("--pace","quick")) ?? .quick,
            seconds:min(900,max(10,Double(option("--seconds","180")) ?? 180)),puzzle:LabBoardPuzzle(rawValue:option("--puzzle","greenArrival")) ?? .greenArrival,quality:LabRenderQuality(rawValue:option("--quality","automatic")) ?? .automatic)
    }
}

/// Local measurements only. Battery values are observations, not power estimates.
@MainActor final class LabPerformanceRecorder {
    // Opt-in markers correlate controller transitions with actual display traces.
    private static let tracing=ProcessInfo.processInfo.arguments.contains("--trace-pours")
    private static let traceLog=OSLog(subsystem:"dev.vials.fluidlab",category:.pointsOfInterest)
    private lazy var traceID=OSSignpostID(log:Self.traceLog)
    func traceBegin(_ name:StaticString) {
        guard Self.tracing else { return }
        os_signpost(.begin,log:Self.traceLog,name:name,signpostID:traceID)
    }
    func traceEnd(_ name:StaticString) {
        guard Self.tracing else { return }
        os_signpost(.end,log:Self.traceLog,name:name,signpostID:traceID)
    }
    func tracePhase(_ phase:String) {
        guard Self.tracing else { return }
        os_signpost(.event,log:Self.traceLog,name:"Pour phase",signpostID:traceID,"%{public}@",phase)
    }
    var context:[String:Any]=[:]
    private(set) var active=false
    private var started:Double=0
    private var first:[String:Any]=[:]
    private var frames:[[Double]]=[] // interval ms, host update/encode wall ms, GPU ms (-1 for Classic)
    private var moves:[[String:Any]]=[]
    private var environments:[[String:Any]]=[]
    private var moveStart:Double?
    private var moveMode="",movePace=""
    private var mode="",pace=""
    func begin(presentation:LabBoardPresentation,pace:LabBoardPace) {
        self.mode=presentation.rawValue;self.pace=pace.rawValue
        #if canImport(UIKit)
        UIDevice.current.isBatteryMonitoringEnabled=true
        #endif
        active=true;started=ProcessInfo.processInfo.systemUptime;frames=[];moves=[];moveStart=nil
        first=environment();environments=[first]
    }
    func recordFrame(interval:Double,cpuMS:Double,gpuMS:Double?) {
        guard active,interval.isFinite,interval>0,frames.count<100_000 else { return }
        frames.append([interval*1000,cpuMS,gpuMS ?? -1])
    }
    func beginMove(presentation:LabBoardPresentation,pace:LabBoardPace) {
        guard active else { return }
        moveStart=ProcessInfo.processInfo.systemUptime;moveMode=presentation.rawValue;movePace=pace.rawValue
    }
    func endMove(committed:Bool,correctionPercent:Double) {
        guard active,let moveStart else { return }
        moves.append(["seconds":ProcessInfo.processInfo.systemUptime-moveStart,"presentation":moveMode,"pace":movePace,"committed":committed,"cleanupPercent":correctionPercent])
        self.moveStart=nil
        if environments.count<1000 { environments.append(environment()) }
    }
    func environment() -> [String:Any] {
        let process=ProcessInfo.processInfo
        let thermal:String
        switch process.thermalState { case .nominal:thermal="nominal";case .fair:thermal="fair";case .serious:thermal="serious";case .critical:thermal="critical";@unknown default:thermal="unknown" }
        var value:[String:Any]=["elapsedSeconds":active ? process.systemUptime-started:0,"thermalState":thermal,"lowPowerMode":process.isLowPowerModeEnabled]
        #if canImport(UIKit)
        let device=UIDevice.current
        value["deviceModel"]=device.model
        value["batteryLevel"]=device.batteryLevel>=0 ? Double(device.batteryLevel):NSNull()
        switch device.batteryState { case .unplugged:value["batteryState"]="unplugged";case .charging:value["batteryState"]="charging";case .full:value["batteryState"]="full";default:value["batteryState"]="unknown" }
        #else
        value["deviceModel"]="Mac";value["batteryLevel"]=NSNull();value["batteryState"]="unavailable"
        #endif
        return value
    }
    func finish(filename:String? = nil,reason:String="completed") throws -> URL {
        let elapsed=ProcessInfo.processInfo.systemUptime-started,last=environment()
        active=false
        func summary(_ values:[Double]) -> [String:Any] {
            let sorted=values.sorted()
            guard !sorted.isEmpty else { return ["samples":0] }
            return ["samples":sorted.count,"median":sorted[sorted.count/2],"p95":sorted[min(sorted.count-1,Int(Double(sorted.count)*0.95))],"maximum":sorted.last!]
        }
        let report:[String:Any]=[
            "schema":2,"configuration":context,"keptAwakeForTrial":ProcessInfo.processInfo.arguments.contains("--keep-awake"),"date":ISO8601DateFormatter().string(from:Date()),"presentation":mode,"pace":pace,"elapsedSeconds":elapsed,"reason":reason,
            "os":ProcessInfo.processInfo.operatingSystemVersionString,"start":first,"end":last,"environmentSamples":environments,"moves":moves,
            "animationFrameIntervalMs":summary(frames.map{$0[0]}),"updateOrEncodeWallMs":summary(frames.map{$0[1]}),"fluidGPUFrameMs":summary(frames.map{$0[2]}.filter{$0>=0}),
            "intervalsOver25ms":frames.filter{$0[0]>25}.count,
            "notes":"Intervals are controller/draw callbacks during active play, not compositor presents. Long active-frame stalls are retained. Classic and 2D record animation updates; 3D records MTKView draw intervals. Host wall measurements include controller updates or Metal encoding and GPU waits; they are not CPU utilization or total SwiftUI rendering cost. GPU time is available only for Fluid. Battery observations while charging/full cannot measure drain; short unplugged samples are coarse and do not establish battery life."
        ]
        let args=ProcessInfo.processInfo.arguments
        let directory:URL
        if LabTrialConfiguration.current != nil,let i=args.firstIndex(of:"--report-directory"),i+1<args.count {
            directory=URL(fileURLWithPath:args[i+1],isDirectory:true)
        } else { directory=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("FluidLabReports",isDirectory:true) }
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        let name=filename ?? "comparison-\(Int(Date().timeIntervalSince1970))"
        let url=directory.appendingPathComponent(name+".json")
        try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:url,options:.atomic)
        return url
    }
}
