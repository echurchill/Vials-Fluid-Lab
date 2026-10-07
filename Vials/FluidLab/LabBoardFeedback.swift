import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

/// AVAudioSession and AVAudioPlayer can synchronously wait while starting or
/// reconfiguring audio. Keep every player operation on one serial queue so
/// feedback never stalls the UI and the pour/start/stop order stays stable.
private final class LabBoardAudio: @unchecked Sendable {
    private let queue=DispatchQueue(label:"com.vials.fluidlab.feedback.audio",qos:.userInitiated)
    private var streamPlayer:AVAudioPlayer?
    private var splashPlayer:AVAudioPlayer?
    private var startPlayer:AVAudioPlayer?
    private var tailPlayer:AVAudioPlayer?
    private var pipettePlayer:AVAudioPlayer?
    private var successPlayer:AVAudioPlayer?
    private var configured=false
    private var pourGeneration=0
    private func configureIfNeeded() {
        #if os(iOS)
        if !configured {
            try? AVAudioSession.sharedInstance().setCategory(.ambient,options:[.mixWithOthers])
            configured=true
        }
        #endif
    }
    private func makeLoop(_ data:Data)->AVAudioPlayer? {
        guard let player=try? AVAudioPlayer(data:data) else {return nil}
        player.numberOfLoops = -1;player.enableRate=true;_ = player.prepareToPlay();return player
    }
    private func preparePlayers() {
        if streamPlayer == nil {streamPlayer=makeLoop(LabBoardFeedback.waterSound())}
        if splashPlayer == nil {splashPlayer=makeLoop(LabBoardFeedback.receivingSplashSound())}
        if startPlayer == nil {startPlayer=try? AVAudioPlayer(data:LabBoardFeedback.pourStartSound());_ = startPlayer?.prepareToPlay()}
        if tailPlayer == nil {tailPlayer=try? AVAudioPlayer(data:LabBoardFeedback.pourTailSound());_ = tailPlayer?.prepareToPlay()}
        if pipettePlayer == nil {pipettePlayer=try? AVAudioPlayer(data:LabBoardFeedback.pipetteSound());_ = pipettePlayer?.prepareToPlay()}
    }
    func prepare() {queue.async { [self] in configureIfNeeded();preparePlayers() }}
    func setPouring(_ value:Bool,intensity:Float=1,pan:Float=0,body:Float=0.5,startEvent:Bool=true,playTail:Bool=true) {
        queue.async { [self] in
            configureIfNeeded();preparePlayers()
            if startEvent || !value {pourGeneration+=1}
            let generation=pourGeneration
            if value {
                let strength=min(1.45,max(0.65,intensity)),rate=min(1.07,max(0.92,1.02-body*0.08))
                streamPlayer?.pan=min(0.22,max(-0.22,pan));streamPlayer?.rate=rate
                splashPlayer?.pan=min(0.28,max(-0.28,pan));splashPlayer?.rate=rate
                if startEvent {
                    startPlayer?.pan=min(0.20,max(-0.20,pan));startPlayer?.volume=0.18*strength
                    startPlayer?.currentTime=0
                    startPlayer?.play()
                }
                if streamPlayer?.isPlaying != true {
                    streamPlayer?.currentTime=0;streamPlayer?.volume=0;streamPlayer?.play()
                }
                streamPlayer?.setVolume(0.27*strength,fadeDuration:startEvent ? 0.16:0.08)
                if startEvent {
                    splashPlayer?.setVolume(0,fadeDuration:0)
                    queue.asyncAfter(deadline:.now()+0.14) { [weak self] in
                        guard let self,self.pourGeneration==generation else {return}
                        if self.splashPlayer?.isPlaying != true {
                            self.splashPlayer?.currentTime=0;self.splashPlayer?.play()
                        }
                        self.splashPlayer?.setVolume(0.13*strength,fadeDuration:0.22)
                    }
                } else if splashPlayer?.isPlaying == true {
                    splashPlayer?.setVolume(0.13*strength,fadeDuration:0.08)
                }
            } else {
                streamPlayer?.setVolume(0,fadeDuration:0.14);splashPlayer?.setVolume(0,fadeDuration:0.18)
                if playTail {
                    tailPlayer?.pan=min(0.20,max(-0.20,pan));tailPlayer?.volume=0.13;tailPlayer?.currentTime=0;tailPlayer?.play()
                }
                queue.asyncAfter(deadline:.now()+0.20) { [weak self] in
                    guard let self,self.pourGeneration==generation else {return}
                    self.streamPlayer?.pause();self.splashPlayer?.pause()
                }
            }
        }
    }
    func stop() {
        queue.async { [self] in
            pourGeneration+=1;streamPlayer?.stop();splashPlayer?.stop();startPlayer?.stop();tailPlayer?.stop();pipettePlayer?.stop()
        }
    }
    func stopAll() {
        queue.async { [self] in
            pourGeneration+=1;streamPlayer?.stop();splashPlayer?.stop();startPlayer?.stop();tailPlayer?.stop();pipettePlayer?.stop();successPlayer?.stop()
        }
    }
    func playPipette() {
        queue.async { [self] in
            configureIfNeeded();preparePlayers();pipettePlayer?.volume=0.22;pipettePlayer?.currentTime=0;pipettePlayer?.play()
        }
    }
    func playSuccess() {
        queue.async { [self] in
            successPlayer=try? AVAudioPlayer(data:LabBoardFeedback.successSound())
            successPlayer?.volume=0.24
            successPlayer?.play()
        }
    }
}

/// Optional local feedback; a quiet procedural water loop follows the visible stream.
@MainActor final class LabBoardFeedback {
    var soundEnabled=false {
        didSet {
            if !soundEnabled {audio.stopAll()}
            else {
                audio.prepare()
                if pouring {audio.setPouring(true,intensity:pourIntensity,startEvent:true)}
            }
        }
    }
    var hapticsEnabled=false
    private let audio=LabBoardAudio()
    private var pouring=false
    private var pourIntensity:Float=1
    func setPouring(_ value:Bool,intensity:Float=1,pan:Float=0,body:Float=0.5,playTail:Bool=true) {
        let wasPouring=pouring
        let changed=value != pouring || (value && abs(intensity-pourIntensity)>0.08)
        guard changed else { return }
        pouring=value
        pourIntensity=intensity
        guard soundEnabled else { return }
        audio.setPouring(value,intensity:intensity,pan:pan,body:body,startEvent:value && !wasPouring,playTail:playTail)
    }
    func stop() {pouring=false;audio.stop()}
    func pipette() {if soundEnabled {audio.playPipette()}}
    func selection() {
        #if os(iOS)
        if hapticsEnabled { UISelectionFeedbackGenerator().selectionChanged() }
        #endif
    }
    func completed(solved:Bool) {
        stop()
        if solved && soundEnabled {
            audio.playSuccess()
        }
        #if os(iOS)
        if hapticsEnabled {
            if solved { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            else { UIImpactFeedbackGenerator(style:.soft).impactOccurred(intensity:0.3) }
        }
        #endif
    }
    /// A seamless, low/mid-band stream bed. Unlike the old sample this does
    /// not gate to silence at the loop boundary or impose a rapid tremolo and
    /// fixed whistle, which were perceived as scratching rather than water.
    nonisolated static func waterSound() -> Data {
        let rate=44100,count=rate*2,tau=Double.pi*2
        var raw=[Double](repeating:0,count:count),seed:UInt32=1937
        for i in 0..<count {
            seed=1664525 &* seed &+ 1013904223
            raw[i]=Double(seed)/Double(UInt32.max)*2-1
        }
        let body=circularSmooth(raw,radius:28),detail=circularSmooth(raw,radius:5)
        var values=[Double](repeating:0,count:count)
        for i in 0..<count {
            let noise=raw[i],t=Double(i)/Double(rate)
            let movement=0.91+0.055*sin(t*tau*0.5)+0.035*sin(t*tau*1.5+1.1)
            let roundedNoise=body[i]*0.78+detail[i]*0.20+(noise-detail[i])*0.018
            let glugPhase=t*tau*92+0.55*sin(t*tau*2)
            let glug=sin(glugPhase)*0.018*(0.5+0.5*sin(t*tau+0.4))
            values[i]=(roundedNoise*movement+glug)*0.72
        }
        return wave(values,rate:rate)
    }
    nonisolated static func receivingSplashSound()->Data {
        let rate=44100,count=rate*2,tau=Double.pi*2
        var raw=[Double](repeating:0,count:count),seed:UInt32=811
        for i in 0..<count {
            seed=1664525 &* seed &+ 1013904223
            raw[i]=Double(seed)/Double(UInt32.max)*2-1
        }
        let soft=circularSmooth(raw,radius:10)
        var values=[Double](repeating:0,count:count)
        for i in 0..<count {
            let t=Double(i)/Double(rate)
            let pulse1=pow(max(0,sin(t*tau*2)),10),pulse2=pow(max(0,sin(t*tau*3.5+1.8)),16)
            let hollowPhase=t*tau*118+0.7*sin(t*tau*1.5)
            let hollow=sin(hollowPhase)*pulse1*0.13
            values[i]=(soft[i]*(0.22+0.42*pulse1+0.26*pulse2)+hollow)*0.72
        }
        return wave(values,rate:rate)
    }
    nonisolated static func pourStartSound()->Data {
        let rate=44100,count=Int(Double(rate)*0.30),tau=Double.pi*2
        var values=[Double](repeating:0,count:count),seed:UInt32=2718,soft=0.0
        for i in values.indices {
            seed=1664525 &* seed &+ 1013904223
            let noise=Double(seed)/Double(UInt32.max)*2-1,t=Double(i)/Double(rate)
            soft=soft*0.90+noise*0.10
            let envelope=min(1,t/0.025)*exp(-t*8.5)
            let glug=sin(t*tau*104+0.4*sin(t*tau*9))*0.22
            values[i]=(soft*0.72+glug)*envelope
        }
        return wave(values,rate:rate)
    }
    nonisolated static func pourTailSound()->Data {
        let rate=44100,count=Int(Double(rate)*0.48),tau=Double.pi*2
        var values=[Double](repeating:0,count:count),seed:UInt32=577
        for i in values.indices {
            seed=1664525 &* seed &+ 1013904223
            let noise=Double(seed)/Double(UInt32.max)*2-1,t=Double(i)/Double(rate)
            func drop(_ center:Double,_ width:Double)->Double {exp(-pow((t-center)/width,2))}
            let droplets=drop(0.07,0.035)+0.72*drop(0.24,0.026)+0.45*drop(0.39,0.020)
            values[i]=(sin(t*tau*146)*0.34+noise*0.16)*droplets
        }
        return wave(values,rate:rate)
    }
    nonisolated static func pipetteSound()->Data {
        let rate=44100,count=Int(Double(rate)*1.72),tau=Double.pi*2
        var values=[Double](repeating:0,count:count),seed:UInt32=31415,air=0.0
        for i in values.indices {
            seed=1664525 &* seed &+ 1013904223
            let noise=Double(seed)/Double(UInt32.max)*2-1,t=Double(i)/Double(rate)
            air=air*0.95+noise*0.05
            func breath(_ start:Double,_ end:Double)->Double {
                guard t>=start,t<=end else {return 0}
                let f=(t-start)/(end-start);return sin(.pi*f)*sin(.pi*f)
            }
            let draw=breath(0.05,0.50),release=breath(0.72,1.48)
            let liquid=air*(draw*0.54+release*0.40)
            let bulbs=sin(t*tau*178)*(draw*0.045+release*0.035)
            let tail=max(0,t-1.47)
            let click=sin(tail*tau*690)*exp(-tail*24)*(t>1.47 ? 0.055:0)
            values[i]=liquid+bulbs+click
        }
        return wave(values,rate:rate)
    }
    nonisolated static func successSound() -> Data {
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
    private nonisolated static func circularSmooth(_ input:[Double],radius:Int)->[Double] {
        guard !input.isEmpty,radius>0 else {return input}
        var result=[Double](repeating:0,count:input.count),sum=0.0
        for offset in -radius...radius {
            let index=(offset%input.count+input.count)%input.count;sum+=input[index]
        }
        let width=Double(radius*2+1)
        for i in input.indices {
            result[i]=sum/width
            let leaving=(i-radius)%input.count,entering=(i+radius+1)%input.count
            sum-=input[(leaving+input.count)%input.count]
            sum+=input[entering]
        }
        return result
    }
    private nonisolated static func wave(_ values:[Double],rate:Int)->Data {
        let peak=max(0.001,values.reduce(0) {max($0,abs($1))}),gain=min(1,0.88/peak)
        var samples=Data(capacity:values.count*2)
        for value in values {
            var sample=Int16(max(-1,min(1,value*gain))*30000).littleEndian
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
