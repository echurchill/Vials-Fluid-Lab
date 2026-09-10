"""Correlate app-attributed frame gaps with phase markers and missing attribution."""
import collections,json,pathlib,re,sys,xml.etree.ElementTree as E
base=pathlib.Path(sys.argv[1]);process_name=sys.argv[3] if len(sys.argv)>3 else 'Vials Fluid Lab'
def rows(name):
 root=E.parse(base/(name+'.xml')).getroot();ids={x.attrib['id']:x for x in root.iter() if 'id' in x.attrib}
 return [[ids.get(x.attrib.get('ref'),x) for x in row] for row in root.findall('.//row')]
def summary(values):
 values=sorted(values)
 return {'samples':len(values),'median':values[len(values)//2],'p95':values[min(len(values)-1,int(len(values)*.95))],'maximum':values[-1]} if values else {'samples':0}
phases=[]
for x in rows('PointsOfInterestEvents'):
 if x[1].attrib.get('fmt','').startswith(process_name+' (') and x[3].text=='dev.vials.fluidlab' and x[4].text=='Pour phase':
  phases.append((float(x[0].text)/1e9,x[5].attrib.get('fmt','')))
phases.sort()
def phase(t):return next((p for a,p in reversed(phases) if a<=t),'unknown')
intervals=collections.defaultdict(list)
for x in rows('OSSignpostIntervals'):
 if x[7].attrib.get('fmt','').startswith(process_name+' (') and x[5].text=='dev.vials.fluidlab':intervals[x[3].text].append(float(x[1].text)/1e6)
frames={};unattributed=[]
for x in rows('displayed-surfaces-interval'):
 t=float(x[0].text)/1e9;m=re.search(re.escape(process_name)+r' \(\d+\):Frame (\d+)',x[9].attrib.get('fmt',''))
 if m:
  key=(x[3].text,m[1]);frames[key]=min(frames.get(key,t),t)
 else:unattributed.append(t)
times=sorted(frames.values());gaps=[];counts=collections.Counter();active_intervals=[]
idle={'Move complete','Sorted beautifully','Choose a vial'}
for a,b in zip(times,times[1:]):
 missing=sum(a<t<b for t in unattributed)
 transitions=[(t,p) for t,p in phases if a<t<=b]
 is_idle=phase(a) in idle or any(p in idle for _,p in transitions)
 ms=(b-a)*1000
 if ms>33.34:
  kind='missing display attribution' if missing else ('between moves/transition' if is_idle else 'during active pour')
  counts[kind]+=1;gaps.append({'startSeconds':a,'endSeconds':b,'durationMs':ms,'phaseAtStart':phase(a),'phaseAtEnd':phase(b),'unattributedSurfaceUpdatesInsideGap':missing,'category':kind})
 if not missing and not is_idle and phase(a)!='unknown':active_intervals.append(ms)
report={'scope':'App-attributed display frame changes correlated with opt-in phase markers. An intervening unattributed surface update makes a gap ambiguous, not a confirmed missed presentation. Turn-boundary markers may lead actual pixels slightly. These are not Instruments animation-hitch ratios. Checkpoint samples use the disposable app and do not include normal UserDefaults persistence.','phaseEvents':[{'seconds':t,'phase':p} for t,p in phases],'instrumentedWorkMs':{k:summary(v) for k,v in intervals.items()},'attributedDisplayFrames':len(times),'unattributedSurfaceUpdates':len(unattributed),'displayIntervalsOver33_34msByCategory':dict(counts),'activeIntervalsWithoutMissingAttributionMs':summary(active_intervals),'gapsOver33_34ms':sorted(gaps,key=lambda x:-x['durationMs'])}
pathlib.Path(sys.argv[2]).write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k not in ['phaseEvents','gapsOver33_34ms','scope']},indent=2))
print('Largest gaps:',json.dumps(report['gapsOver33_34ms'][:5],indent=2))
