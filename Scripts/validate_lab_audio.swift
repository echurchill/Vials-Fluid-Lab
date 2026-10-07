import AVFoundation
import Foundation

@main struct LabAudioValidation {
    @MainActor static func main() throws {
        let output=URL(fileURLWithPath:CommandLine.arguments.dropFirst().first ?? "build/audio-validation",isDirectory:true)
        try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
        let sounds:[(String,Data,Double)]=[
            ("pour-stream",LabBoardFeedback.waterSound(),2.00),
            ("receiving-splash",LabBoardFeedback.receivingSplashSound(),2.00),
            ("pour-start",LabBoardFeedback.pourStartSound(),0.30),
            ("pour-tail",LabBoardFeedback.pourTailSound(),0.48),
            ("pipette",LabBoardFeedback.pipetteSound(),1.72),
            ("success",LabBoardFeedback.successSound(),0.62)
        ]
        var decoded:[String:[Double]]=[:]
        for (name,data,duration) in sounds {
            let player=try AVAudioPlayer(data:data)
            precondition(abs(player.duration-duration)<0.012,"\(name) duration changed: \(player.duration)")
            precondition(player.prepareToPlay(),"\(name) could not prepare")
            let samples=pcm(data),peak=samples.map(abs).max() ?? 0
            let rms=sqrt(samples.reduce(0) {$0+$1*$1}/Double(max(1,samples.count)))
            precondition(peak>0.10 && peak<0.90,"\(name) peak is unsafe or silent: \(peak)")
            precondition(rms>0.004,"\(name) is effectively silent")
            decoded[name]=samples
            try data.write(to:output.appendingPathComponent(name+".wav"),options:.atomic)
            print("PASS \(name): \(String(format:"%.2f",player.duration))s, peak \(String(format:"%.3f",peak)), rms \(String(format:"%.3f",rms))")
        }
        for name in ["pour-stream","receiving-splash"] {
            let samples=decoded[name]!,seam=abs(samples.last!-samples.first!)
            let ordinary=zip(samples.dropFirst(),samples).reduce(0) {$0+abs($1.0-$1.1)}/Double(samples.count-1)
            precondition(seam<ordinary*4,"\(name) has an audible loop discontinuity")
        }
        let rate=44100,total=Int(2.62*Double(rate))
        var preview=[Double](repeating:0,count:total)
        func layer(_ name:String,at seconds:Double,gain:Double,repeatingLoop:Bool=false,duration:Double?=nil) {
            let source=decoded[name]!,start=Int(seconds*Double(rate)),count=duration.map {Int($0*Double(rate))} ?? source.count
            for i in 0..<count where start+i<preview.count {
                let sample=repeatingLoop ? source[i%source.count]:source[min(i,source.count-1)]
                preview[start+i]+=sample*gain
            }
        }
        layer("pour-start",at:0,gain:0.75)
        layer("pour-stream",at:0.12,gain:0.82,repeatingLoop:true,duration:1.92)
        layer("receiving-splash",at:0.27,gain:0.42,repeatingLoop:true,duration:1.77)
        layer("pour-tail",at:2.02,gain:0.78)
        try wave(preview,rate:rate).write(to:output.appendingPathComponent("layered-pour-preview.wav"),options:.atomic)
        print("PASS layered pour preview: start, stream, receiving splash, and tail")
    }

    private static func pcm(_ data:Data)->[Double] {
        precondition(data.count>44 && String(decoding:data.prefix(4),as:UTF8.self)=="RIFF")
        return data.dropFirst(44).withUnsafeBytes { bytes in
            Array(bytes.bindMemory(to:Int16.self)).map {Double(Int16(littleEndian:$0))/32768}
        }
    }
    private static func wave(_ values:[Double],rate:Int)->Data {
        var samples=Data(capacity:values.count*2)
        for value in values {
            var sample=Int16(max(-1,min(1,value))*30000).littleEndian
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
