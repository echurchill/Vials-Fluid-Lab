import xml.etree.ElementTree as E,collections,json,pathlib,sys
process_name=sys.argv[3] if len(sys.argv)>3 else 'VialsProfileChecks'
platform=sys.argv[4] if len(sys.argv)>4 else 'Mac'
root=E.parse(sys.argv[1]).getroot()
ids={e.attrib['id']:e for e in root.iter() if 'id' in e.attrib}
def resolve(e):return ids[e.attrib['ref']] if 'ref' in e.attrib else e
categories=collections.Counter();functions=collections.Counter();threads=collections.Counter();total=0;times=[];main_solver=0
for row in root.findall('.//row'):
 fields=[resolve(e) for e in row]
 if len(fields)!=7 or not fields[2].attrib.get('fmt','').startswith(process_name+' ('):continue
 time,thread,process,core,state,weight,stack=fields
 w=float(weight.text)/1e6;total+=w;times.append(float(time.text)/1e9)
 frames=[resolve(f).attrib.get('name','') for f in stack.findall('frame')]
 joined=' '.join(frames)
 ismain='Main Thread' in thread.attrib.get('fmt','');threads['main' if ismain else 'background']+=w
 if 'Lab2DWorker' in joined or 'LabFluid2D.solve' in joined or 'LabFluid2D.advance' in joined:
  category='physics simulation/worker';main_solver+=w if ismain else 0
 elif 'LabFluid2D.install' in joined:
  category='physics preparation';main_solver+=w if ismain else 0
 elif 'drawGlass' in joined:category='glass drawing'
 elif 'LabFluid2DView' in joined:category='other 2D drawing'
 elif 'FluidBoardView' in joined:category='board controls and layout'
 elif 'SwiftUI' in joined or any('Graph' in f for f in frames):category='other UI framework work'
 else:category='other framework/runtime work'
 categories[category]+=w
 for f in set(frames):
  if any(k in f for k in ['LabFluid2D','Lab2DWorker','FluidBoardSession','FluidBoardView']):functions[f]+=w
report={'scope':platform+' running CPU samples from the isolated 2D app; categories are heuristic, disjoint stack classifications, not GPU times or energy measurements','sampleWeightMs':total,'firstSampleSeconds':min(times),'lastSampleSeconds':max(times),'threadsMs':dict(threads),'mainThreadPhysicsSampleWeightMs':main_solver,'categories':[{'name':k,'weightMs':v,'sharePercent':v/total*100} for k,v in categories.most_common()],'inclusiveAppFunctions':[{'name':k,'weightMs':v,'sharePercent':v/total*100} for k,v in functions.most_common(18)]}
pathlib.Path(sys.argv[2]).write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
