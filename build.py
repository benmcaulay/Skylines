#!/usr/bin/env python3
"""Rebuild index.html from app.template.html + the reference data."""
import csv, json, os, sys
HERE=os.path.dirname(os.path.abspath(__file__))
DATA=os.path.join(HERE,'data')
CSV_IN=sys.argv[1] if len(sys.argv)>1 else os.path.join(DATA,'seed.csv')
seed=[]
with open(CSV_IN, encoding='utf-8-sig') as f:
    for r in csv.DictReader(f):
        if not r.get('From'): continue
        seed.append({"date":r['Date'],"from":r['From'],"to":r['To'],"airline":r['Airline'],
                     "num":r.get('Flight_Number',''),"miles":int(r['Distance']),
                     "dur":r['Duration'],"cls":r.get('Class',''),"note":r.get('Note','')})
seed.sort(key=lambda x:x['date'])
tpl=open(os.path.join(HERE,'app.template.html'), encoding='utf-8').read()
out=(tpl.replace('/*__WORLD__*/',open(os.path.join(DATA,'world.json')).read())
        .replace('/*__REF__*/',open(os.path.join(DATA,'ref.json'), encoding='utf-8').read())
        .replace('/*__SEED__*/',json.dumps(seed,separators=(',',':'),ensure_ascii=False)))
open(os.path.join(HERE,'index.html'),'w',encoding='utf-8').write(out)
print('built index.html —',len(seed),'seed flights,',len(out),'bytes')
