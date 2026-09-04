"""Camada compartilhada: config, credenciais e acesso à API REST do Jenkins."""

import json
import netrc
import os
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from base64 import b64encode

DEFAULTS = {
    "JENKINS_URL": "",
    "JBUILD_JOBS_FILE": os.path.expanduser("~/.jenkins-jobs.json"),
    "JBUILD_DEFAULT_BRANCH": "sandbox",
    "JBUILD_LOG_LINES": "60",
    "JBUILD_STRIP_PREFIXES": "",
    "JBUILD_POLL_SECONDS": "3",
}


def die(msg, code=1):
    print(f"jbuild: {msg}", file=sys.stderr)
    sys.exit(code)


def load_config():
    cfg = dict(DEFAULTS)
    rc = os.environ.get("JBUILD_CONFIG", os.path.expanduser("~/.jbuildrc"))
    if os.path.isfile(rc):
        keys = " ".join(DEFAULTS)
        script = (
            f'. "{rc}" || exit 1\n'
            f'for k in {keys}; do printf "%s=%s\\0" "$k" "${{!k}}"; done'
        )
        dump = subprocess.run(
            ["bash", "-c", script], capture_output=True, text=True,
        )
        if dump.returncode == 0:
            for entry in dump.stdout.split("\0"):
                key, sep, value = entry.partition("=")
                if sep and value and key in DEFAULTS:
                    cfg[key] = value
    for key in DEFAULTS:
        if os.environ.get(key):
            cfg[key] = os.environ[key]
    if not cfg["JENKINS_URL"]:
        die(f'defina JENKINS_URL em {rc} (ex.: JENKINS_URL="https://jenkins.exemplo.com")')
    cfg["JENKINS_URL"] = cfg["JENKINS_URL"].rstrip("/")
    cfg["JBUILD_JOBS_FILE"] = os.path.expanduser(cfg["JBUILD_JOBS_FILE"])
    return cfg


class Jenkins:
    def __init__(self, base):
        self.base = base
        self.host = urllib.parse.urlparse(base).hostname
        self._auth = self._netrc_auth()
        self._crumb = None

    def _netrc_auth(self):
        try:
            entry = netrc.netrc().authenticators(self.host)
        except (FileNotFoundError, netrc.NetrcParseError):
            return None
        if not entry:
            return None
        login, _, password = entry
        raw = f"{login}:{password}".encode()
        return "Basic " + b64encode(raw).decode()

    def _open(self, url, data=None, method=None, headers=None):
        req = urllib.request.Request(url, data=data, method=method)
        if self._auth:
            req.add_header("Authorization", self._auth)
        for key, value in (headers or {}).items():
            req.add_header(key, value)
        try:
            return urllib.request.urlopen(req, timeout=30)
        except urllib.error.HTTPError as exc:
            if exc.code in (401, 403):
                die(f"autenticação recusada ({exc.code}) — confira o ~/.netrc para {self.host}")
            raise

    def url(self, *parts):
        return "/".join([self.base] + [p.strip("/") for p in parts if p])

    def job_url(self, path, branch=None):
        segments = "/".join(f"job/{urllib.parse.quote(p)}" for p in path.split("/"))
        url = f"{self.base}/{segments}"
        if branch:
            url += f"/job/{urllib.parse.quote(branch, safe='')}"
        return url

    def get_json(self, url):
        with self._open(url) as resp:
            return json.load(resp)

    def get_text(self, url):
        with self._open(url) as resp:
            return resp.read().decode("utf-8", "replace")

    def crumb(self):
        if self._crumb is None:
            try:
                data = self.get_json(f"{self.base}/crumbIssuer/api/json")
                self._crumb = {data["crumbRequestField"]: data["crumb"]}
            except Exception:
                self._crumb = {}
        return self._crumb

    def post(self, url):
        resp = self._open(url, data=b"", method="POST", headers=self.crumb())
        return resp.status, resp.headers.get("Location")


def load_jobs(path):
    if not os.path.isfile(path):
        die("cache de jobs não encontrado — rode jenkins-jobs-update")
    with open(path) as fh:
        head = fh.read(1)
        fh.seek(0)
        if head == "{":
            return json.load(fh)["jobs"]
        jobs = {}
        for line in fh:
            name, _, job_path = line.strip().partition(":")
            if name and job_path:
                jobs[name] = {"path": job_path, "branches": {}}
        return jobs


def resolve(jobs, name):
    if name in jobs:
        return jobs[name]
    matches = [k for k in jobs if k.startswith(name)]
    if len(matches) == 1:
        return jobs[matches[0]]
    if len(matches) > 1:
        die(f"apelido ambíguo '{name}': {', '.join(sorted(matches))}")
    die(f"job desconhecido: {name}  (jbuild sem argumentos lista os jobs)")
