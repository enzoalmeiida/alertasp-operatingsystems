#!/usr/bin/env python3
"""Inicia somente seu próprio processo e DB temporário; não acessa produção."""
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

bundle, sdk = map(Path, sys.argv[1:])
launcher = bundle.resolve() / 'bin/start'
sdk = sdk.resolve()
client = urllib.request.build_opener(urllib.request.ProxyHandler({}))
with tempfile.TemporaryDirectory(prefix='alertasp-smoke-') as temp:
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        port = sock.getsockname()[1]
    base = f'http://127.0.0.1:{port}'
    environment = dict(os.environ, DOTNET_ROOT=str(sdk), HOST='127.0.0.1', PORT=str(port),
                       ASPNETCORE_ENVIRONMENT='Production',
                       ConnectionStrings__Alertasp=f'Data Source={temp}/reports.db')
    process = None
    passed = 0

    def request(path, method='GET', body=None):
        data = None if body is None else json.dumps(body).encode()
        req = urllib.request.Request(base + path, data=data, method=method,
                                     headers={'Content-Type': 'application/json'})
        try:
            response = client.open(req, timeout=5)
        except urllib.error.HTTPError as error:
            response = error
        with response:
            raw = response.read()
            return response.status, json.loads(raw) if raw else None

    def check(condition, name):
        global passed
        if not condition:
            raise AssertionError(name)
        passed += 1
        print('PASS', name, flush=True)

    def start(log):
        proc = subprocess.Popen([str(launcher)], cwd=bundle, env=environment,
                                stdout=log, stderr=subprocess.STDOUT)
        try:
            for _ in range(100):
                if proc.poll() is not None:
                    raise RuntimeError(f'API encerrou durante startup: {proc.returncode}')
                try:
                    status, body = request('/health')
                    if status == 200 and body['status'] == 'ok':
                        return proc
                except (OSError, urllib.error.URLError):
                    pass
                time.sleep(.1)
            raise TimeoutError('API sem saúde após 10s')
        except BaseException:
            stop(proc)
            raise

    def stop(proc):
        if proc and proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=5)

    with open(Path(temp) / 'api.log', 'w+') as log:
        try:
            process = start(log)
            check(request('/health')[0] == 200, 'health-http')
            status, created = request('/api/reports', 'POST', {
                'roadName': 'Via sintetica OS', 'district': 'Teste OS',
                'latitude': -23.55, 'longitude': -46.63,
                'observedAt': '2026-01-15T12:00:00Z', 'source': 'SyntheticDemo'})
            check(status == 201 and created['status'] == 'Reported', 'create-synthetic-report')
            report_id = created['id']
            status, rows = request('/api/reports?district=Teste%20OS&status=Reported')
            check(status == 200 and any(r['id'] == report_id for r in rows), 'filter-report')
            status, changed = request(f'/api/reports/{report_id}/status', 'PATCH', {'status': 'Confirmed'})
            check(status == 200 and changed['status'] == 'Confirmed', 'update-report')
            check(request('/api/reports/00000000-0000-0000-0000-000000000000')[0] == 404, 'missing-report-404')
            check(request('/api/reports', 'POST', {'latitude': 91})[0] == 400, 'invalid-report-400')
            old_pid = process.pid
            stop(process)
            process = start(log)
            status, persisted = request(f'/api/reports/{report_id}')
            check(process.pid != old_pid and status == 200 and persisted['status'] == 'Confirmed',
                  'sqlite-survives-process-restart')
            print(f'Resultado: {passed} verificações HTTP passaram; reinício manual, não systemd.')
        except BaseException:
            log.flush()
            log.seek(0)
            print(log.read(), file=sys.stderr)
            raise
        finally:
            stop(process)
