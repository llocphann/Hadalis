#!/usr/bin/env python3
"""Local-only inference contract and read-only vault context on owned fixtures."""
from datetime import datetime
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import threading
import unittest
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('wull_mind',ROOT/'scripts/wull/local_mind.py')
mind=importlib.util.module_from_spec(spec);spec.loader.exec_module(mind)

class Handler(BaseHTTPRequestHandler):
    calls=[];remote=False;bad=False;redirect=False;invalid_expression=False
    def log_message(self,*args):pass
    def respond(self,value,status=200):
        self.send_response(status);self.send_header('Content-Type','application/json');self.end_headers()
        self.wfile.write(json.dumps(value).encode())
    def do_GET(self):
        self.calls.append((self.path,None))
        if self.redirect:
            self.send_response(302);self.send_header('Location','http://example.com/');self.end_headers();return
        self.respond({'models':[{'name':'tiny:local','size':123},{'name':'large-cloud','remote_host':'cloud.example','size':0}]})
    def do_POST(self):
        request=json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        self.calls.append((self.path,request))
        if self.path=='/api/show':
            self.respond({'model_info':{'general.architecture':'fixture'},'remote_host':'cloud.example' if self.remote else ''})
        else:self.respond({'done':True,'message':{'content':'garbage' if self.bad else json.dumps({'text':'Splish! I am right here with you.','expression':['invalid'] if self.invalid_expression else 'happy'})},'eval_count':15})

class Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server=ThreadingHTTPServer(('127.0.0.1',0),Handler)
        cls.thread=threading.Thread(target=cls.server.serve_forever,daemon=True);cls.thread.start()
        cls.base=f'http://127.0.0.1:{cls.server.server_port}'
    @classmethod
    def tearDownClass(cls):cls.server.shutdown();cls.server.server_close();cls.thread.join(timeout=2)
    def setUp(self):Handler.calls=[];Handler.remote=False;Handler.bad=False;Handler.redirect=False;Handler.invalid_expression=False
    def test_loopback(self):
        for bad in ['https://127.0.0.1','http://evil.example','http://localhost@evil.example','http://127.0.0.1/proxy',
                    'http://127.0.0.1?target=x','file:///tmp/model','http://127.0.0.1:0','http://192.168.0.1:11434']:
            with self.subTest(bad=bad),self.assertRaises(mind.MindError):mind.endpoint(bad)
        self.assertEqual(mind.endpoint('http://localhost:11434'),'http://127.0.0.1:11434')
        self.assertEqual(mind.endpoint('http://[::1]:11434'),'http://[::1]:11434')
    def test_probe(self):
        result=mind.probe({'endpoint':self.base})
        self.assertTrue(result['ready']);self.assertEqual([x['name'] for x in result['models']],['tiny:local'])
        self.assertFalse(result['models'][0]['thinking']);self.assertTrue(mind.thinking_capable('Qwen3.5:4b'))
        self.assertEqual(Handler.calls,[('/api/tags',None)])
    def test_redirect(self):
        Handler.redirect=True
        with self.assertRaises(mind.MindError) as ctx:mind.probe({'endpoint':self.base})
        self.assertEqual(ctx.exception.code,'redirect_blocked');self.assertEqual(len(Handler.calls),1)
    def test_bounded_chat(self):
        result=mind.chat({'endpoint':self.base,'model':'tiny:local','prompt':'Hello Wull!',
                          'history':[{'role':'system','content':'malicious'},{'role':'user','content':'x'*2000}]*10})
        self.assertEqual(result['source'],'local');self.assertEqual(result['expression'],'happy')
        self.assertEqual([x[0] for x in Handler.calls],['/api/show','/api/chat'])
        data=Handler.calls[-1][1]
        self.assertFalse(data['stream']);self.assertEqual(data['keep_alive'],0);self.assertFalse(data['think'])
        self.assertEqual(data['options']['num_ctx'],2048);self.assertEqual(data['options']['num_predict'],160)
        self.assertEqual(len([m for m in data['messages'] if m['role']=='system']),1)
        self.assertLessEqual(len(data['messages']),8)
        self.assertTrue(all(len(m['content'])<=500 for m in data['messages'][1:-1]))
        self.assertNotIn('tools',data)
    def test_thinking_effort_is_capability_gated_and_bounded(self):
        result=mind.chat({'endpoint':self.base,'model':'tiny:local','prompt':'Hello','thinkingEffort':'high'})
        self.assertEqual(result['thinkingEffort'],'off');self.assertFalse(Handler.calls[-1][1]['think'])
        Handler.calls=[]
        result=mind.chat({'endpoint':self.base,'model':'qwen3.5:4b','prompt':'Hello','thinkingEffort':'medium'})
        data=Handler.calls[-1][1]
        self.assertEqual(result['thinkingEffort'],'medium');self.assertTrue(data['think'])
        self.assertEqual(data['options']['num_predict'],512)
        with self.assertRaises(mind.MindError) as ctx:
            mind.chat({'endpoint':self.base,'model':'qwen3.5:4b','prompt':'Hello','thinkingEffort':'extreme'})
        self.assertEqual(ctx.exception.code,'invalid_thinking_effort')

    def test_persistent_quick_chat_history_is_paged_and_clearable(self):
        with tempfile.TemporaryDirectory(prefix='wull-history-') as temporary, patch.dict(
                os.environ, {'INIR_WULL_HISTORY_DB':str(Path(temporary)/'chat.sqlite3')}):
            self.assertTrue(mind.clear_chat_history()['cleared'])
            first=mind.chat({'endpoint':self.base,'model':'tiny:local','prompt':'First','persistHistory':True})
            self.assertTrue(first['historySaved'])
            self.assertGreater(first['assistantMessageId'],first['userMessageId'])
            rows=mind.chat_history({'limit':20})['messages']
            self.assertEqual([(x['role'],x['content']) for x in rows],
                [('user','First'),('assistant','Splish! I am right here with you.')])
            mind.chat({'endpoint':self.base,'model':'tiny:local','prompt':'Second','persistHistory':True})
            payload=Handler.calls[-1][1]
            self.assertIn('First',json.dumps(payload))
            newest=mind.chat_history({'limit':2})
            self.assertEqual(len(newest['messages']),2)
            older=mind.chat_history({'limit':2,'beforeId':newest['messages'][0]['id']})
            self.assertEqual(len(older['messages']),2)
            self.assertTrue(mind.clear_chat_history()['cleared'])
            self.assertEqual(mind.chat_history({'limit':20})['messages'],[])
            self.assertEqual((Path(temporary)/'chat.sqlite3').stat().st_mode&0o777,0o600)

    def test_remote_alias_rejected_before_prompt(self):
        Handler.remote=True
        with self.assertRaises(mind.MindError) as ctx:mind.chat({'endpoint':self.base,'model':'custom-alias','prompt':'private message'})
        self.assertEqual(ctx.exception.code,'remote_model_blocked')
        self.assertEqual([x[0] for x in Handler.calls],['/api/show'])
        self.assertNotIn('private message',json.dumps(Handler.calls))
    def test_malformed_reply(self):
        Handler.bad=True
        with self.assertRaises(mind.MindError) as ctx:mind.chat({'endpoint':self.base,'model':'tiny:local','prompt':'hello'})
        self.assertEqual(ctx.exception.code,'invalid_response')
    def test_invalid_expression_preserves_text(self):
        Handler.invalid_expression=True
        result=mind.chat({'endpoint':self.base,'model':'tiny:local','prompt':'hello'})
        self.assertEqual(result['expression'],'idle');self.assertTrue(result['text'].startswith('Splish!'))
    def test_readonly_vault_context(self):
        with tempfile.TemporaryDirectory(prefix='wull-vault-fixture-') as t:
            primary=Path(t)/'Obsidian-Vault';reference=Path(t)/'Abyssal-Vault'
            for vault in [primary,reference]:
                (vault/'00_Capture/01_Journal/2026/October').mkdir(parents=True)
                (vault/'90_System/97_Daily_Schedule').mkdir(parents=True)
                (vault/'90_System/97_Daily_Schedule/07_Sunday.md').write_text('## **Daily Schedule**\n| Time | Sunday |\n| 15:00 - 16:00 | Study |\n| 17:00 | Dinner |\n## Calisthenics\n| 16:00 | Not schedule |\n')
            note=primary/'00_Capture/01_Journal/2026/October/04-10-2026-Sunday.md'
            note.write_text('---\nmood: calm\nenergy:\nreflection: PRIVATE CONTENT\n---\n## Day Planner\n### Work\n- [ ] 15:00 - 15:30 Appointment\n- [x] 16:00 Done appointment\n## Private\nNEVER SENT\n')
            before={str(p):p.read_bytes() for p in Path(t).rglob('*.md')}
            result=mind.context({'vault':str(primary),'referenceVault':str(reference)},datetime(2026,10,4,14,45))
            self.assertEqual(result['mood'],'calm');self.assertEqual(result['energy'],'')
            self.assertEqual([x['title'] for x in result['schedule']],['Appointment','Dinner'])
            self.assertEqual(len(result['vaults']),2)
            self.assertNotIn('PRIVATE',json.dumps(result));self.assertNotIn('NEVER SENT',json.dumps(result))
            self.assertEqual(before,{str(p):p.read_bytes() for p in Path(t).rglob('*.md')})
            Handler.calls=[]
            mind.chat({'endpoint':self.base,'model':'tiny:local','prompt':'How is my day?',
                       'shareObsidian':True,'vault':str(primary),'referenceVault':str(reference)})
            request=json.dumps(Handler.calls[-1][1])
            self.assertNotIn('PRIVATE CONTENT',request);self.assertNotIn('NEVER SENT',request)
            with self.assertRaises(mind.MindError):mind.context({'vault':str(primary),'dailyFolder':'../../escape'})
    def test_empty_context_and_invalid_action(self):
        self.assertEqual(mind.context({})['schedule'],[])
        with self.assertRaises(mind.MindError):mind.dispatch({'action':'write_note'})

    def test_explicit_checkin_preserves_journal(self):
        with tempfile.TemporaryDirectory() as t:
            note=Path(t)/'journal/2026/10/04.md';note.parent.mkdir(parents=True)
            raw=b'\xef\xbb\xbf---\r\nmood:\r\nenergy:\r\nprivate: KEEP\r\n---\r\nBody unchanged.\r\n'
            note.write_bytes(raw);note.chmod(0o640)
            options={'vault':t,'dailyFolder':'journal','dailyFormat':'YYYY/MM/DD','date':'2026-10-04','field':'mood','value':'good'}
            saved=mind.check_in(options,datetime(2026,10,4));self.assertTrue(saved['saved'])
            self.assertEqual(note.read_bytes(),raw.replace(b'mood:',b'mood: good'))
            self.assertEqual(note.stat().st_mode&0o777,0o640)
            options.update(field='energy',value='high');mind.check_in(options,datetime(2026,10,4))
            self.assertEqual(note.read_bytes(),raw.replace(b'mood:',b'mood: good').replace(b'energy:',b'energy: high'))
            before=note.read_bytes()
            for patch in [{'date':'2026-10-03'},{'field':'reflection'},{'value':'invented'},{'dailyFolder':'../escape'}]:
                with self.assertRaises((mind.MindError,mind.core.TodoError)):mind.check_in(dict(options,**patch),datetime(2026,10,4))
                self.assertEqual(note.read_bytes(),before)

    def test_timed_agenda_and_exercise_schedule(self):
        rows=mind.schedule_rows(['- [ ] 14:30 Write outline','- [x] 15:00 Finished','- 16:00 Meet',
            '| **05:30 - 06:45** | **Calisthenics** |','| 6:45 | Cardio |'],'fixture')
        self.assertEqual([r['start'] for r in rows],[870,960,330,405])
        self.assertEqual([r['kind'] for r in rows][-2:],['calisthenics','cardio'])

if __name__=='__main__':unittest.main()
