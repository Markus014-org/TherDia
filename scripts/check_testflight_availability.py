#!/usr/bin/env python3
"""Publish a public, credential-free manifest of *internally testable* TherDia builds.

Only GitHub Actions may call the App Store Connect API with the private ES256 key.
The iPhone fetches the resulting tiny JSON; no Apple credentials ship in TherDia.

An upload alone is NOT sufficient. We require:
 - processed and unexpired build,
 - Apple's internalBuildState IN_BETA_TESTING or READY_FOR_BETA_TESTING,
 - at least one internal TestFlight group with access to this build.

The check is conservative: on API failure the workflow fails and preserves the
last known manifest instead of claiming that a build is available.
"""
import json
import os
import sys
import time
import urllib.parse
import urllib.request
import urllib.error


class ASC:
    def __init__(self, token):
        self.token = token

    def get(self, endpoint, **params):
        url = "https://api.appstoreconnect.apple.com" + endpoint
        if params:
            url += "?" + urllib.parse.urlencode(params)
        request = urllib.request.Request(url, headers={
            "Authorization": "Bearer " + self.token,
            "Accept": "application/json",
        })
        try:
            with urllib.request.urlopen(request, timeout=25) as response:
                return json.load(response)
        except urllib.error.HTTPError as exc:
            raise RuntimeError(
                f"Apple App Store Connect API HTTP {exc.code}: {endpoint}"
            ) from None

    def list(self, endpoint, **params):
        response = self.get(endpoint, **params)
        items = list(response.get("data", []))
        link = response.get("links", {}).get("next")
        # Following only Apple-provided pagination URLs, with a safe limit.
        for _ in range(20):
            if not link:
                return items
            parsed = urllib.parse.urlsplit(link)
            if parsed.hostname != "api.appstoreconnect.apple.com" or parsed.scheme != "https":
                raise RuntimeError("Unexpected Apple API pagination URL")
            response = self.get(parsed.path + ("?" + parsed.query if parsed.query else ""))
            items.extend(response.get("data", []))
            link = response.get("links", {}).get("next")
        raise RuntimeError("App Store Connect returned too many pages")


def jwt_token():
    # Delayed import keeps selection logic testable without Apple credentials.
    import jwt
    private_key = os.environ["FASTLANE_KEY"].replace("\\n", "\n")
    now = int(time.time())
    return jwt.encode({
        "iss": os.environ["FASTLANE_ISSUER_ID"],
        "iat": now,
        "exp": now + 600,
        "aud": "appstoreconnect-v1",
    }, private_key, algorithm="ES256",
        headers={"kid": os.environ["FASTLANE_KEY_ID"], "typ": "JWT"})


def internal_group_builds(api, app_id):
    groups = api.list("/v1/betaGroups",
                      **{"filter[app]": app_id,
                         "fields[betaGroups]": "isInternalGroup,hasAccessToAllBuilds",
                         "limit": "200"})
    all_access = False
    explicit = set()
    for group in groups:
        attrs = group.get("attributes", {})
        if not attrs.get("isInternalGroup"):
            continue
        if attrs.get("hasAccessToAllBuilds"):
            all_access = True
        else:
            builds = api.list(f"/v1/betaGroups/{group['id']}/builds",
                              **{"fields[builds]": "version", "limit": "200"})
            explicit.update(b["id"] for b in builds)
    return all_access, explicit


def newest_testable_build(api, app_id):
    all_access, assigned = internal_group_builds(api, app_id)
    if not all_access and not assigned:
        return None

    # Apple's /v1/apps/{id}/builds relationship endpoint rejects `sort`
    # with 400. The top-level /v1/builds collection supports sorting with
    # filter[app], so we can reliably inspect the 40 most recent uploads.
    builds = api.get("/v1/builds",
                     **{"filter[app]": app_id, "sort": "-uploadedDate", "limit": "40",
                        "fields[builds]": "version,processingState,expired,uploadedDate"}).get("data", [])
    candidates = []
    for build in builds:
        attrs = build.get("attributes", {})
        if attrs.get("expired") or attrs.get("processingState") != "VALID":
            continue
        if not all_access and build["id"] not in assigned:
            continue
        details = api.get("/v1/buildBetaDetails",
                          **{"filter[build]": build["id"],
                             "fields[buildBetaDetails]": "internalBuildState",
                             "limit": "1"}).get("data", [])
        if not details or details[0].get("attributes", {}).get("internalBuildState") not in (
            "READY_FOR_BETA_TESTING", "IN_BETA_TESTING"
        ):
            continue
        prerelease = api.get(f"/v1/builds/{build['id']}/preReleaseVersion",
                             **{"fields[preReleaseVersions]": "version,platform"}).get("data")
        if not prerelease:
            continue
        release_attrs = prerelease.get("attributes", {})
        if release_attrs.get("platform") != "IOS":
            continue
        version = release_attrs.get("version", "")
        number = attrs.get("version", "")
        if not version or not number or not str(number).isdigit():
            continue
        candidates.append((version, str(number)))

    if not candidates:
        return None

    def sort_key(pair):
        return (
            tuple((int(x) if x.isdigit() else 0)
                  for x in (pair[0].split(".") + ["0", "0", "0"])[:4]),
            int(pair[1]),
        )

    return max(candidates, key=sort_key)


def make_manifest(api, bundle_id):
    apps = api.list("/v1/apps", **{"filter[bundleId]": bundle_id, "limit": "2"})
    app = next((a for a in apps if a.get("attributes", {}).get("bundleId") == bundle_id), None)
    if not app:
        raise RuntimeError("TherDia was not found in App Store Connect")
    chosen = newest_testable_build(api, app["id"])
    return {
        "schemaVersion": 1,
        "bundleId": bundle_id,
        "availableVersion": chosen[0] if chosen else None,
        "availableBuild": chosen[1] if chosen else None,
    }


if __name__ == "__main__":
    bundle = os.environ.get("APP_IDENTIFIER", "de.therdia.app")
    manifest = make_manifest(ASC(jwt_token()), bundle)
    json.dump(manifest, sys.stdout, ensure_ascii=False, sort_keys=True, indent=2)
    sys.stdout.write("\n")
