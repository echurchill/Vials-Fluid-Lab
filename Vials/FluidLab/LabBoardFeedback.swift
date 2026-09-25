import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

/// Optional local feedback; a quiet procedural water loop follows the visible stream.
@MainActor final class LabBoardFeedback {
    var soundEnabled=false {
        didSet {
            if !soundEnabled { player?.stop() }
            else if pouring { pouring=false;setPouring(true) }
        }
    }
    var hapticsEnabled=false
    private var player:AVAudioPlayer?
    private var successPlayer:AVAudioPlayer?
    private var pouring=false
    func setPouring(_ value:Bool) {
        guard value != pouring else { return }
        pouring=value
        guard soundEnabled else { return }
        if value {
            if player == nil {
                #if os(iOS)
                try? AVAudioSession.sharedInstance().setCategory(.ambient,options:[.mixWithOthers])
                #endif
                player=try? AVAudioPlayer(data:Self.waterSound())
                player?.numberOfLoops = -1;player?.volume=0.16
            }
            player?.play()
        } else { player?.pause() }
    }
    func stop() { pouring=false;player?.stop() }
    func selection() {
        #if os(iOS)
        if hapticsEnabled { UISelectionFeedbackGenerator().selectionChanged() }
        #endif
    }
    func completed(solved:Bool) {
        stop()
        if solved && soundEnabled {
            successPlayer=try? AVAudioPlayer(data:Self.successSound())
            successPlayer?.volume=0.24
            successPlayer?.play()
        }
        #if os(iOS)
        if hapticsEnabled {
            if solved { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            else { UIImpactFeedbackGenerator(style:.soft).impactOccurred(intensity:0.3) }
        }
        #endif
    }
    static func waterSound() -> Data {
        let rate=22050,count=rate*2
        var samples=Data(),seed:UInt32=1937,filtered=0.0
        for i in 0..<count {
            seed=1664525 &* seed &+ 1013904223
            let noise=Double(seed)/Double(UInt32.max)*2-1,t=Double(i)/Double(rate)
            filtered=filtered*0.78+noise*0.22
            let ripple=0.65+0.35*sin(t * .pi*14)
            let bubble=sin(t * .pi*2*420+5*sin(t * .pi*6))*0.06
            let edge=min(1,min(Double(i)/440,Double(count-1-i)/440))
            var sample=Int16(max(-1,min(1,(filtered*ripple*0.65+bubble)*edge))*24000).littleEndian
            withUnsafeBytes(of:&sample) { samples.append(contentsOf:$0) }
        }
        var data=Data()
        func ascii(_ s:String) { data.append(contentsOf:s.utf8) }
        func u32(_ v:UInt32) { var x=v.littleEndian;withUnsafeBytes(of:&x) { data.append(contentsOf:$0) } }
        func u16(_ v:UInt16) { var x=v.littleEndian;withUnsafeBytes(of:&x) { data.append(contentsOf:$0) } }
        ascii("RIFF");u32(UInt32(samples.count+36));ascii("WAVEfmt ");u32(16);u16(1);u16(1)
        u32(UInt32(rate));u32(UInt32(rate*2));u16(2);u16(16);ascii("data");u32(UInt32(samples.count));data.append(samples)
        return data
    }
    static func successSound() -> Data {
        let rate=22050,count=Int(Double(rate)*0.62)
        var samples=Data()
        for i in 0..<count {
            let t=Double(i)/Double(rate),attack=min(1,t/0.018),release=max(0,1-t/0.62)
            let first=sin(t*Double.pi*2*523.25)*exp(-t*5.2)
            let second=t>0.13 ? sin((t-0.13)*Double.pi*2*659.25)*exp(-(t-0.13)*5.8):0
            let third=t>0.27 ? sin((t-0.27)*Double.pi*2*783.99)*exp(-(t-0.27)*6.4):0
            var sample=Int16(max(-1,min(1,(first+second+third)*0.28*attack*release))*30000).littleEndian
            withUnsafeBytes(of:&sample) {samples.append(contentsOf:$0)}
        }
        var data=Data()
        func ascii(_ s:String) {data.append(contentsOf:s.utf8)}
        func u32(_ v:UInt32) {var x=v.littleEndian;withUnsafeBytes(of:&x) {data.append(contentsOf:$0)}}
        func u16(_ v:UInt16) {var x=v.littleEndian;withUnsafeBytes(of:&x) {data.append(contentsOf:$0)}}
        ascii("RIFF");u32(UInt32(samples.count+36));ascii("WAVEfmt ");u32(16);u16(1);u16(1)
        u32(UInt32(rate));u32(UInt32(rate*2));u16(2);u16(16);ascii("data");u32(UInt32(samples.count));data.append(samples)
        return data
    }
}
