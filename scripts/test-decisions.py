#!/usr/bin/env python3
import concurrent.futures
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]
SCRIPT=ROOT/'plugins/skills/authoring/grill/scripts/decision.py'
class Decisions(unittest.TestCase):
 def test_append_list_render_and_corruption(self):
  with tempfile.TemporaryDirectory() as tmp:
   config=json.dumps({'log_dir':tmp})
   def run(command,*args):return subprocess.run(['python3',str(SCRIPT),command,'--config',config,*args],text=True,capture_output=True)
   with concurrent.futures.ThreadPoolExecutor(8) as pool:
    results=list(pool.map(lambda i:run('add','--topic','fixture','--what','決定'+str(i),'--why','根拠'+str(i)),range(20)))
   self.assertTrue(all(r.returncode==0 for r in results))
   result=run('list','--topic','fixture');rows=[json.loads(line) for line in result.stdout.splitlines()];self.assertEqual(len(rows),20);self.assertEqual(len({x['what'] for x in rows}),20)
   rendered=run('render','--topic','fixture');self.assertEqual(rendered.returncode,0);self.assertIn('対象 20 件',rendered.stdout)
   self.assertEqual(run('add','--topic','../escape','--what','x','--why','y').returncode,2)
   self.assertEqual(run('add','--topic','fixture','--what','x','--why','').returncode,2)
   with open(Path(tmp)/'fixture.jsonl','a') as f:f.write('{broken}\n')
   self.assertEqual(run('list','--topic','fixture').returncode,2)
   broken=(Path(tmp)/'fixture.jsonl').read_bytes()
   self.assertEqual(run('add','--topic','fixture','--what','x','--why','y').returncode,2)
   self.assertEqual((Path(tmp)/'fixture.jsonl').read_bytes(),broken)
   (Path(tmp)/'fixture.jsonl').write_text('null\n')
   invalid=run('render','--topic','fixture');self.assertEqual(invalid.returncode,2);self.assertIn('error',json.loads(invalid.stdout));self.assertNotIn('Traceback',invalid.stderr)
if __name__=='__main__':unittest.main()
