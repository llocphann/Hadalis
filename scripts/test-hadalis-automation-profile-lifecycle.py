#!/usr/bin/env python3
"""Identity survives project edits, Stop/Restart and confirmed local removal."""
import json
import stat
from unittest.mock import patch
from automation_test_helpers import environment, profile, Transport, daemon, control, store


def main():
    with environment():
        a,b=profile('A'),profile('B');t=Transport()
        with patch.object(daemon,'native_command',side_effect=t):
            daemon.tick(100);old=t.pending(a)['conversation_id']
            control.set_profile(a,'project_name','"Another project"')
            control.set_profile(a,'enabled','false')
            t.reply(a);daemon.tick(102)
            assert store.read_snapshot()[1]['profiles'][a]['pending'] is None
            assert store.read_snapshot()[1]['profiles'][a]['session']['conversation_id']==old
            assert t.count('submit')==2
            assert store.read_snapshot()[1]['profiles'][b]['desired']=='run'
            control.set_profile(a,'enabled','true');control.profile_action('start',a);daemon.tick(104)
            assert t.pending(a)['project_id']=='project-Another project'
            assert t.pending(a)['conversation_id']!=old
            # A safe Restart resolves the old response before creating a new chat.
            current=t.pending(a)['user_message_id']
            control.profile_action('restart',a);daemon.tick(105)
            assert t.pending(a)['user_message_id']==current and t.count('submit')==3
            t.reply(a,'HADALIS_LOOP:DONE');daemon.tick(107)
            assert store.read_snapshot()[1]['profiles'][a]['request']=='restart'
            daemon.tick(109);assert t.count('submit')==4
            assert t.pending(a)['user_message_id']!=current
        baseline=t.pending(a).copy()
        try:control.remove_profile(a)
        except ValueError:pass
        else:raise AssertionError('uncertain removal needs confirmation')
        with patch.object(daemon,'native_command') as native:
            control.remove_profile(a,confirmed_unresolved=True)
            native.assert_not_called()
        assert a not in store.read_snapshot()[1]['profiles']
        archive=next((store.state_dir()/'removed-profiles').glob('*.json'))
        saved=json.loads(archive.read_text())
        assert saved['runtime']['pending']==baseline
        assert stat.S_IMODE(archive.stat().st_mode)==0o600
        assert store.read_snapshot()[1]['profiles'][b]['pending']
    with environment():
        a,b=profile('A'),profile('B');t=Transport()
        with patch.object(daemon,'native_command',side_effect=t):
            daemon.tick(100);t.reply(a);t.reply(b);daemon.tick(102)
            def external(op,**kw):
                if kw.get('conversation_id')==store.read_snapshot()[1]['profiles'][a]['session']['conversation_id']:
                    if op=='cursor': return {'current_node':'human-edited-turn'}
                    if op=='branch': return {'relation':'LATER_USER_TURN'}
                return t(op,**kw)
            with patch.object(daemon,'native_command',side_effect=external):daemon.tick(104)
            state=store.read_snapshot()[1]
            assert state['profiles'][a]['status']=='session_changed'
            assert state['profiles'][b]['pending']

    # An internal, non-user node after the exact assistant final is safe to
    # continue only if two fresh branch observations agree on that parent.
    with environment():
        import uuid
        a,b=profile('Descendant'),profile('Independent');t=Transport()
        with patch.object(daemon,'native_command',side_effect=t):
            daemon.tick(100);t.reply(a);t.reply(b);daemon.tick(102)
            chat=store.read_snapshot()[1]['profiles'][a]['session']['conversation_id']
            descendant=str(uuid.uuid5(uuid.NAMESPACE_URL,'safe-managed-descendant'))
            def benign(op,**kw):
                if kw.get('conversation_id')==chat:
                    if op=='cursor':return {'current_node':descendant,'model':'auto'}
                    if op=='branch':return {'relation':'NON_USER_DESCENDANT','current_node':descendant}
                return t(op,**kw)
            with patch.object(daemon,'native_command',side_effect=benign):
                daemon.tick(104)
            state=store.read_snapshot()[1]
            assert state['profiles'][a]['desired']=='run'
            assert state['profiles'][a]['pending']['parent_message_id']==descendant
            assert state['profiles'][b]['pending']
            assert sum(e['kind']=='managed_branch_descendant_verified' and
                e['profile_id']==a for e in state['events'])==1
            assert t.count('submit')==4
    # A changed branch between first verification and dispatch-intent
    # revalidation must never cause a submission, even if both profiles run.
    with environment():
        import uuid
        a,b=profile('Raced'),profile('Independent');t=Transport()
        with patch.object(daemon,'native_command',side_effect=t):
            daemon.tick(100);t.reply(a);t.reply(b);daemon.tick(102)
            chat=store.read_snapshot()[1]['profiles'][a]['session']['conversation_id']
            descendant=str(uuid.uuid5(uuid.NAMESPACE_URL,'raced-managed-descendant'))
            observed=[0]
            def raced(op,**kw):
                if kw.get('conversation_id')==chat:
                    if op=='cursor':return {'current_node':descendant,'model':'auto'}
                    if op=='branch':
                        observed[0]+=1
                        return {'relation':'NON_USER_DESCENDANT','current_node':descendant} if observed[0]==1 else {'relation':'LATER_USER_TURN'}
                return t(op,**kw)
            with patch.object(daemon,'native_command',side_effect=raced):
                daemon.tick(104)
            state=store.read_snapshot()[1]
            assert observed[0]==2
            assert state['profiles'][a]['status']=='session_changed'
            assert state['profiles'][a]['desired']=='paused'
            assert state['profiles'][a]['pending'] is None
            assert state['profiles'][b]['pending']
            assert t.count('submit')==3
    print('PASS: staged project identity, pending Stop/Restart, private removal archive, independent human-edit guard')

if __name__=='__main__':main()
