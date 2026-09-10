import xml.etree.ElementTree as E,collections,json,re,pathlib,sys
base=pathlib.Path(sys.argv[1])
process_name=sys.argv[3] if len(sys.argv)>3 else 'VialsProfileChecks'
platform=sys.argv[4] if len(sys.argv)>4 else 'Mac'
def rows(name):
 r=E.parse(base/(name+'.xml')).getroot();ids={e.attrib['id']:e for e in r.iter() if 'id' in e.attrib}
 return [[ids[e.attrib['ref']] if 'ref' in e.attrib else e for e in row] for row in r.findall('.//row')]
def summary(values):
 v=sorted(values)
 return {'samples':len(v),'median':v[len(v)//2],'p95':v[min(len(v)-1,int(len(v)*.95))],'maximum':v[-1]} if v else {'samples':0}
def union(intervals):
 total=0;end=-1
 for a,b in sorted(intervals):
  total+=max(0,b-max(a,end));end=max(end,b)
 return total
frames=collections.defaultdict(list)
unassigned=0
for x in rows('metal-gpu-intervals'):
 if x[10].attrib.get('fmt','').startswith(process_name+' (') and x[7].text=='Active':
  if x[3].text is None:
   unassigned+=1;continue
  a=float(x[0].text)/1e6;b=a+float(x[1].text)/1e6;frames[x[3].text].append((a,b))
displayed={}
for x in rows('displayed-surfaces-interval'):
 label=x[9].attrib.get('fmt','');m=re.search(re.escape(process_name)+r' \(\d+\):Frame (\d+)',label)
 if m:
  key=(x[3].text,m[1]);t=float(x[0].text)/1e9
  displayed[key]=min(displayed.get(key,t),t)
times=sorted(displayed.values());intervals=[(b-a)*1000 for a,b in zip(times,times[1:])]
report={'scope':platform+' Game Performance retained window; app-attributed GPU interval unions and first display appearance of each app frame. Excludes other processes. GPU figures exclude compositor work. Partial boundary frames are retained; GPU intervals without a frame ID are excluded from per-frame summaries. Display frame changes are only those with app attribution; consult the flow-trace summary for missing attribution.','gpuIntervalsWithoutFrameID':unassigned,'gpuFrameActiveUnionMs':summary([union(v) for v in frames.values()]),'displayedUniqueFrames':len(times),'firstDisplayTimeSeconds':times[0],'lastDisplayTimeSeconds':times[-1],'displayIntervalMs':summary(intervals),'observedDisplayChangesPerSecond':(len(times)-1)/(times[-1]-times[0]),'potentialHangsOver100ms':len(rows('potential-hangs'))}
pathlib.Path(sys.argv[2]).write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
