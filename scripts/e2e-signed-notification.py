#!/usr/bin/env python3
"""End-to-end check of the per-signer "X signed" notification (docuseal-mnb).

Runs on the host of the dataroom-sign container. It:
  1. creates a throwaway two-party template (Signer, Founder) through the API,
  2. creates a submission with send_email: false (no email to any signer),
  3. completes only the Signer party through the public signing form (PUT /s/<slug>),
  4. finds the notification in Resend (queried from inside the container with the
     SMTP key, which never leaves the container) and waits for its last_event,
  5. archives the throwaway submission and template.

Usage: scripts/e2e-signed-notification.py [--signer-email EMAIL] [--founder-email EMAIL]
The notification recipient is whatever the account's
`submitter_signed_notification_emails` config holds; this script does not change it.
"""
from __future__ import annotations

import argparse
import base64
import json
import pathlib
import re
import subprocess
import time
import urllib.parse
import urllib.request
import uuid

BASE = "https://sign.dataroom.fast"
CONTAINER = "dataroom-sign"
REPO = pathlib.Path(__file__).resolve().parent.parent
KEY_FILE = pathlib.Path.home() / "keys/dataroom/SIGN_ADMIN.md"
UA = "Mozilla/5.0 docuseal-mnb-e2e"


def api(method: str, path: str, token: str, body: dict | None = None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(f"{BASE}/api{path}", data=data, method=method, headers={
        "X-Auth-Token": token, "Content-Type": "application/json", "User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.loads(resp.read() or b"null")


def resend_emails() -> list[dict]:
    """List recent Resend emails using the container's SMTP (Resend) key."""
    ruby = (
        "require 'net/http'; k = EncryptedConfig.find_by(key: 'action_mailer_smtp').value['password']; "
        "r = Net::HTTP.get_response(URI('https://api.resend.com/emails?limit=50'), "
        "{'Authorization' => \"Bearer #{k}\"}); puts 'RESEND_JSON ' + r.body"
    )
    out = subprocess.run(["docker", "exec", "-w", "/app", CONTAINER, "bin/rails", "runner", ruby],
                         capture_output=True, text=True, check=True).stdout
    line = next(l for l in out.splitlines() if l.startswith("RESEND_JSON "))
    return json.loads(line[len("RESEND_JSON "):]).get("data", [])


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--signer-email", default="micah+signtest@superradiant.ai")
    ap.add_argument("--founder-email", default="micah@superradiant.ai")
    ap.add_argument("--timeout", type=int, default=240)
    args = ap.parse_args()

    token = re.search(r"API token \(X-Auth-Token\):\s*(\S+)", KEY_FILE.read_text()).group(1)
    stamp = time.strftime("%Y%m%d-%H%M%S")
    name = f"E2E signed-notification test {stamp} (docuseal-mnb)"
    pdf = base64.b64encode((REPO / "spec/fixtures/sample-document.pdf").read_bytes()).decode()

    # This fork's POST /templates/pdf ignores `fields`, so add parties and fields with a PUT.
    template = api("POST", "/templates/pdf", token, {
        "name": name, "documents": [{"name": "e2e-signed-notification", "file": pdf}]})
    print(f"template {template['id']} created: {name}")
    attachment_uuid = template["schema"][0]["attachment_uuid"]
    signer_role_uuid, founder_role_uuid, field_uuid = (str(uuid.uuid4()) for _ in range(3))

    def text_field(field_id: str, role_uuid: str, label: str, y: float) -> dict:
        return {"uuid": field_id, "submitter_uuid": role_uuid, "name": label, "type": "text",
                "required": True,
                "areas": [{"x": 0.1, "y": y, "w": 0.3, "h": 0.04, "page": 0,
                           "attachment_uuid": attachment_uuid}]}

    api("PUT", f"/templates/{template['id']}", token, {
        "submitters": [{"name": "Signer", "uuid": signer_role_uuid},
                       {"name": "Founder", "uuid": founder_role_uuid}],
        "fields": [text_field(field_uuid, signer_role_uuid, "Signer acknowledgement", 0.1),
                   text_field(str(uuid.uuid4()), founder_role_uuid, "Founder acknowledgement", 0.2)],
    })

    submitters = api("POST", "/submissions", token, {
        "template_id": template["id"], "send_email": False,
        "submitters": [{"role": "Signer", "email": args.signer_email, "name": "Signature Test"},
                       {"role": "Founder", "email": args.founder_email, "name": "Founder Countersign"}],
    })
    submission_id = submitters[0]["submission_id"]
    signer = next(s for s in submitters if s["role"] == "Signer")
    print(f"submission {submission_id} created (send_email: false); signer submitter {signer['id']}")

    started = time.time()
    form = urllib.parse.urlencode({f"values[{field_uuid}]": "signed by e2e", "completed": "true"}).encode()
    req = urllib.request.Request(f"{BASE}/s/{signer['slug']}", data=form, method="PUT", headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as resp:
        print(f"signer completed via PUT /s/<slug>: HTTP {resp.status}")

    found = None
    try:
        while time.time() - started < args.timeout:
            for email in resend_emails():
                if name in (email.get("subject") or ""):
                    found = email
            if found and found.get("last_event") not in (None, "queued", "sent"):
                break
            time.sleep(10)
    finally:
        api("DELETE", f"/submissions/{submission_id}", token)
        api("DELETE", f"/templates/{template['id']}", token)
        print(f"archived submission {submission_id} and template {template['id']}")

    if not found:
        raise SystemExit(f"FAIL: no Resend email with subject containing {name!r} within {args.timeout}s")
    print("resend:", json.dumps({k: found.get(k) for k in ("id", "from", "to", "subject", "created_at", "last_event")}))
    if found.get("last_event") != "delivered":
        raise SystemExit(f"FAIL: last_event is {found.get('last_event')!r}, not 'delivered'")
    print("PASS")


if __name__ == "__main__":
    main()
