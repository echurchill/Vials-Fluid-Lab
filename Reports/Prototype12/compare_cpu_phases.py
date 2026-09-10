"""Compare sampled CPU work per second within the same named pour phases."""
import pathlib,json,sys,xml.etree.ElementTree as E
output={}
for name,folder in [('before',pathlib.Path(sys.argv[1])),('after',pathlib.Path(sys.argv[2]))]:
 def rows(schema):
  r=E.parse(folder/(schema+'.xml')).getroot();ids={x.attrib['id']:x for x in r.iter() if 'id' in x.attrib}
  return [[ids.get(x.attrib.get('ref'),x) for x in row] for row in r.findall('.//row')]
 phases=sorted((float(x[0].text)/1e9,x[5].attrib.get('fmt','')) for x in rows('PointsOfInterestEvents') if x[1].attrib.get('fmt','').startswith('Vials Fluid Lab (') and x[3].text=='dev.vials.fluidlab' and x[4].text=='Pour phase')
 samples=[x for x in rows('time-profile') if x[2].attrib.get('fmt','').startswith('Vials Fluid Lab (')]
 start=min(float(x[0].text)/1e9 for x in samples);end=max(float(x[0].text)/1e9 for x in samples)
 durations={};weights={}
 for (t,p),(t1,_) in zip(phases,phases[1:]+[(end,'')]):durations[p]=durations.get(p,0)+max(0,min(end,t1)-max(start,t))
 for x in samples:
  t=float(x[0].text)/1e9;p=next((p for a,p in reversed(phases) if a<=t),'unknown');w=float(x[5].text)/1e6
  q=weights.setdefault(p,{'allThreadsMs':0,'mainThreadMs':0});q['allThreadsMs']+=w
  if 'Main Thread' in x[1].attrib.get('fmt',''):q['mainThreadMs']+=w
 output[name]={'cpuWindowSeconds':end-start,'phases':{p:{'seconds':d,**weights.get(p,{}),'allThreadSampleMsPerSecond':weights.get(p,{}).get('allThreadsMs',0)/d,'mainThreadSampleMsPerSecond':weights.get(p,{}).get('mainThreadMs',0)/d} for p,d in durations.items() if d>0}}
path=pathlib.Path(sys.argv[3]);path.write_text(json.dumps(output,indent=2)+'\n')
for name,x in output.items():print(name,json.dumps(x['phases'].get('Pouring'),indent=2))
