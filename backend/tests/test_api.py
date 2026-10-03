import concurrent.futures
import hashlib
import os
import tempfile
import unittest
import uuid
from datetime import datetime, timedelta, timezone
from unittest.mock import patch

_tmp = tempfile.TemporaryDirectory()
test_postgres = os.environ.get('RUNOVER_TEST_POSTGRES_URL')
if test_postgres and test_postgres != 'postgresql+psycopg://postgres@127.0.0.1:55432/runover_test':
    raise RuntimeError('Use only the dedicated local runover_test PostgreSQL database.')
os.environ['DATABASE_URL'] = test_postgres or 'sqlite:///' + _tmp.name + '/test.db'
os.environ['SECRET_KEY'] = 'local-test-signing-key-for-runover-tests'
from fastapi.testclient import TestClient
from app.main import app
from app.core.database import Base, engine, initialize_database, SessionLocal
from app.models import PasswordResetToken, Run, ScoreEvent, User
from app.schemas import RunRequest
from app.services.mail import send_reset_email


class ApiTests(unittest.TestCase):
    def setUp(self):
        Base.metadata.drop_all(engine)
        initialize_database()
        self.client = TestClient(app)
        self.client.__enter__()
        self.sent = []
        self.mail_patch = patch(
            'app.routers.auth.send_password_reset_email',
            side_effect=lambda email, username, code: self.sent.append((email, username, code)),
        )
        self.mail_patch.start()
        self.alice = self.register('alice')
        self.bob = self.register('bobby')

    def tearDown(self):
        self.mail_patch.stop()
        self.client.__exit__(None, None, None)

    def register(self, name):
        response = self.client.post('/auth/register', json={'full_name':'Test Runner','username':name,'email':name+'@example.com','password':'Password123','accept_terms':True})
        self.assertEqual(response.status_code,201,response.text)
        return {'Authorization':'Bearer '+response.json()['access_token']}

    def payload(self, coords=None, **kwargs):
        coords = coords or [(10,10),(10,10.001),(10.001,10.001),(10.001,10),(10,10)]
        start = datetime.now(timezone.utc) - timedelta(minutes=20)
        run_id = str(uuid.uuid4())
        return {
            'id': run_id,
            'request_id': run_id,
            'track': [
                {'lat': a, 'lng': b, 'timestamp': (start + timedelta(seconds=i * 60)).isoformat()}
                for i, (a, b) in enumerate(coords)
            ],
            **kwargs,
        }

    def save(self, payload, user=None):
        return self.client.post('/runs',json=payload,headers=user or self.alice)

    def test_password_recovery_private_single_use_revokes_sessions(self):
        known = self.client.post('/auth/forgot-password',json={'email':'alice@example.com'})
        unknown = self.client.post('/auth/forgot-password',json={'email':'missing@example.com'})
        self.assertEqual(known.json(),unknown.json())
        self.assertNotIn('reset_token',known.json())
        code = self.sent[0][2]
        with SessionLocal() as db:
            stored = db.query(PasswordResetToken).one()
            self.assertEqual(stored.token_hash, hashlib.sha256(code.encode()).hexdigest())
            self.assertNotEqual(stored.token_hash, code)
        payload = {
            'email': 'alice@example.com',
            'reset_code': code,
            'new_password': 'Updated123',
        }
        self.assertEqual(self.client.post('/auth/reset-password',json=payload).status_code,200)
        self.assertEqual(self.client.post('/auth/reset-password',json=payload).status_code,400)
        self.assertEqual(self.client.get('/users/me',headers=self.alice).status_code,401)
        self.assertEqual(self.client.post('/auth/login',json={'email':'alice@example.com','password':'Updated123'}).status_code,200)

    def test_login_email_throttle_is_scoped_to_client_after_ip_limit(self):
        calls = []

        def record_throttle(_db, key, limit, minutes=15):
            calls.append((key, limit))
            return len(calls) == 1

        with patch('app.routers.auth.client_key', return_value='203.0.113.7'), patch(
            'app.routers.auth.throttle', side_effect=record_throttle,
        ):
            response = self.client.post('/auth/login', json={
                'email': 'alice@example.com',
                'password': 'Password123',
            })

        self.assertEqual(response.status_code, 429)
        self.assertEqual(calls, [
            ('login-ip:203.0.113.7', 60),
            ('login:alice@example.com:203.0.113.7', 15),
        ])

        calls.clear()
        with patch('app.routers.auth.client_key', return_value='203.0.113.7'), patch(
            'app.routers.auth.throttle', side_effect=lambda *_args: calls.append(True) or False,
        ):
            response = self.client.post('/auth/login', json={
                'email': 'alice@example.com',
                'password': 'Password123',
            })
        self.assertEqual(response.status_code, 429)
        self.assertEqual(len(calls), 1)

    def test_run_response_models_preserve_summary_and_detail_fields(self):
        payload = self.payload()
        saved = self.save(payload)
        self.assertEqual(saved.status_code, 200, saved.text)
        run_id = saved.json()['id']
        listed = self.client.get('/runs',headers=self.alice)
        self.assertEqual(listed.status_code, 200, listed.text)
        summary = listed.json()[0]
        self.assertNotIn('track', summary)
        self.assertIn('claim', summary)
        self.assertIn('claim_error', summary)
        detail = self.client.get(f'/runs/{run_id}',headers=self.alice).json()
        self.assertEqual(len(detail['track']), len(payload['track']))
        self.assertEqual(self.client.get('/runs/progress',headers=self.alice).status_code, 200)

    def test_expired_token_and_rate_limit(self):
        for _ in range(5):
            self.assertEqual(self.client.post('/auth/forgot-password',json={'email':'alice@example.com'}).status_code,200)
        self.assertEqual(len(self.sent),1)
        with SessionLocal() as db:
            db.query(PasswordResetToken).update({
                'expires_at': datetime.now(timezone.utc) - timedelta(seconds=1),
            })
            db.commit()
        response = self.client.post('/auth/reset-password',json={
            'email': 'alice@example.com',
            'reset_code': self.sent[0][2],
            'new_password': 'Updated123',
        })
        self.assertEqual(response.status_code,400)

    def test_profile_password_and_photo(self):
        self.assertEqual(self.client.patch('/users/me',headers=self.alice,json={'password':'12345678'}).status_code,422)
        self.client.patch('/users/me',headers=self.alice,json={'photo_url':'https://example.com/photo'})
        self.assertIsNone(self.client.patch('/users/me',headers=self.alice,json={'photo_url':None}).json()['photo_url'])
        self.assertEqual(self.client.patch('/users/me',headers=self.alice,json={'password':'Updated123'}).status_code,200)
        self.assertEqual(self.client.get('/users/me',headers=self.alice).status_code,401)

    def test_claim_is_idempotent_and_private(self):
        payload = self.payload(conquer=True)
        a,b = self.save(payload),self.save(payload)
        self.assertEqual(a.status_code,200,a.text)
        self.assertEqual(a.json(),b.json())
        self.assertIsNotNone(a.json()['claim'])
        with SessionLocal() as db:
            self.assertEqual(db.query(Run).count(),1)
            self.assertEqual(db.query(ScoreEvent).filter(ScoreEvent.reason=='conquista').count(),1)
        self.assertEqual(self.client.get('/runs/'+payload['id'],headers=self.bob).status_code,404)
        self.assertEqual(self.client.get('/runs',headers=self.bob).json(),[])
        self.assertEqual(self.save({**payload,'name':'different'}).status_code,409)
        self.assertEqual(self.save({**payload,'id':str(uuid.uuid4())},self.bob).status_code,409)
        changed_segments={**payload,'id':str(uuid.uuid4()),'track':[{**p,'segment':1} for p in payload['track']]}
        self.assertEqual(self.save(changed_segments,self.bob).status_code,409)
        self.assertEqual(self.client.post('/territories/claim',headers=self.bob,json=payload).status_code,410)

    def test_open_run_saved_without_conquest(self):
        p = self.payload(coords=[(10,10),(10,10.001),(10,10.002)],conquer=True)
        response=self.save(p)
        self.assertEqual(response.status_code,200,response.text)
        self.assertIsNone(response.json()['claim'])
        self.assertTrue(response.json()['claim_error'])
        profile=self.client.get('/users/me',headers=self.alice).json()
        self.assertEqual(profile['play_seconds'],120)
        self.assertEqual(profile['total_score'],0)

    def test_geometry_errors_do_not_500(self):
        self.assertEqual(self.save(self.payload(coords=[(11,11)]*4,conquer=True)).status_code,400)
        coords=[(12,12),(12,12.001),(12.001,12.001),(12.001,12),(12,12),(12,11.999),(11.999,11.999),(11.999,12),(12,12)]
        response=self.save(self.payload(coords=coords,conquer=True))
        self.assertEqual(response.status_code,200,response.text)
        self.assertIsNone(response.json()['claim'])
        self.assertTrue(response.json()['claim_error'])

    def test_invalid_track_data(self):
        for key,value in [('lat',91),('lng',181),('timestamp','2026-01-01T00:00:00')]:
            p=self.payload();p['track'][0][key]=value
            self.assertEqual(self.save(p).status_code,422)
        p=self.payload();p['track'][1]['timestamp']=p['track'][0]['timestamp']
        self.assertEqual(self.save(p).status_code,400)
        p=self.payload();p['track'][0]['timestamp']=(datetime.now(timezone.utc)-timedelta(days=8)).isoformat()
        self.assertEqual(self.save(p).status_code,400)
        p=self.payload();start=datetime.now(timezone.utc)-timedelta(minutes=1)
        for i,point in enumerate(p['track']):point['timestamp']=(start+timedelta(seconds=i)).isoformat()
        self.assertEqual(self.save(p).status_code,400)

    def test_pause_excludes_gap_and_cannot_conquer(self):
        p=self.payload(conquer=True)
        for point in p['track'][2:]:point['segment']=1
        response=self.save(p)
        self.assertEqual(response.status_code,200,response.text)
        self.assertEqual(response.json()['duration_seconds'],180)
        self.assertIsNone(response.json()['claim'])
        self.assertTrue(response.json()['claim_error'])

    def test_team_progress_and_authorization(self):
        team=self.client.post('/teams',headers=self.alice,json={'name':'Runners'}).json()
        p=self.payload(conquer=True,team_id=team['id'])
        self.assertEqual(self.save(p,self.bob).status_code,403)
        response=self.save(p)
        self.assertEqual(response.status_code,200,response.text)
        self.assertEqual(response.json()['claim']['territory']['owner_type'],'team')
        self.assertGreater(response.json()['claim']['new_total_score'],0)
        progress=self.client.get('/runs/progress',headers=self.alice).json()
        self.assertEqual(progress['runs_count'],1)
        self.assertTrue(progress['badges'][0]['earned'])
        self.assertTrue(progress['badges'][1]['earned'])
        self.assertGreater(progress['team']['distance_km'],0)
        self.assertIsNone(self.client.get('/runs/progress',headers=self.bob).json()['team'])

    def test_concurrent_same_request_scores_once(self):
        p=self.payload(conquer=True)
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            responses=list(pool.map(lambda _:self.save(p),range(2)))
        self.assertEqual([r.status_code for r in responses],[200,200])
        self.assertEqual(responses[0].json(),responses[1].json())
        with SessionLocal() as db:
            self.assertEqual(db.query(Run).count(),1)
            self.assertEqual(db.query(ScoreEvent).filter(ScoreEvent.reason=='conquista').count(),1)

    def test_same_owner_claim_keeps_activity_without_new_score(self):
        first=self.payload(conquer=True)
        response=self.save(first)
        self.assertEqual(response.status_code,200,response.text)
        second=self.payload(conquer=True)
        for p in second['track']:
            p['timestamp']=(datetime.fromisoformat(p['timestamp'])+timedelta(minutes=10)).isoformat()
        response=self.save(second)
        self.assertEqual(response.status_code,200,response.text)
        self.assertIsNone(response.json()['claim'])
        with SessionLocal() as db:
            self.assertEqual(db.query(Run).count(),2)
            self.assertEqual(db.query(ScoreEvent).filter(ScoreEvent.reason=='conquista').count(),1)

    def test_additive_initialization_preserves_existing_user(self):
        initialize_database()
        self.assertEqual(self.client.get('/users/me',headers=self.alice).status_code,200)


class MailDeliveryTests(unittest.TestCase):
    def test_disabled_mail_backend_raises_without_logging_secrets(self):
        with patch('app.services.mail.settings.mail_backend', 'disabled'):
            with self.assertLogs('app.services.mail', level='WARNING') as logs:
                with self.assertRaisesRegex(RuntimeError, 'not configured'):
                    send_reset_email('private@example.com', 'secret-token')
        self.assertNotIn('private@example.com', '\n'.join(logs.output))
        self.assertNotIn('secret-token', '\n'.join(logs.output))

    def test_mail_delivery_exception_is_reraised_without_logging_details(self):
        with patch('app.services.mail.settings.mail_backend', 'smtp'), patch(
            'app.services.mail.smtplib.SMTP', side_effect=OSError('provider secret')
        ):
            with self.assertLogs('app.services.mail', level='ERROR') as logs:
                with self.assertRaisesRegex(OSError, 'provider secret'):
                    send_reset_email('private@example.com', 'secret-token')
        logged = '\n'.join(logs.output)
        self.assertNotIn('private@example.com', logged)
        self.assertNotIn('secret-token', logged)
        self.assertNotIn('provider secret', logged)


if __name__ == '__main__':
    unittest.main()
