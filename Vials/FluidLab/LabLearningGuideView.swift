import SwiftUI

struct LabLearningGuideView:View {
    let topic:LabLearningTopic
    let position:Int
    let total:Int
    let route:String?
    let advance:()->Void
    let close:()->Void
    var body:some View {
        VStack(alignment:.leading,spacing:14) {
            HStack {
                Text("QUICK GUIDE"+(total>1 ? " · \(position) OF \(total)":""))
                    .font(.system(size:10,weight:.semibold,design:.monospaced)).foregroundStyle(.secondary)
                Spacer()
                Button(action:close) {Image(systemName:"xmark.circle.fill")}
                    .buttonStyle(.plain).accessibilityLabel("Close learning guide")
            }
            Text(topic.title).font(.title3.bold())
            if let route {Text(route).font(.system(.callout,design:.monospaced)).foregroundStyle(.purple)}
            Text(topic.explanation).fixedSize(horizontal:false,vertical:true)
            Text(topic.reminder).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            Text("Replay this explanation with the ? button above the board.").font(.caption).foregroundStyle(.secondary)
            Button(position<total ? "Next tip":"Got it",action:advance).buttonStyle(.borderedProminent)
                .accessibilityIdentifier("learning.advance")
        }.padding(20).frame(width:300)
    }
}
